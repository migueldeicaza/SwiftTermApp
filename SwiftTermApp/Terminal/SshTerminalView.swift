//
//  SshTerminalView.swift
//
//  The SSH Terminal View, connects the TerminalView with SSH
//
//  Created by Miguel de Icaza on 4/22/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import UIKit
import SwiftTerm
import AudioToolbox
import SwiftUI

enum MyError : Error {
    case noValidKey(String)
    case general
}

///
/// Extends the AppTerminalView with elements for the connection
///
public class SshTerminalView: AppTerminalView, TerminalViewDelegate, SessionDelegate {
    /// The current directory as reported by the remote host.
    public var currentDirectory: String? = nil
    
    var completeConnectSetup: () -> () = { }
    var session: SocketSession!
    var sessionChannel: Channel?

    // Session restoration:
    //
    // -2 -> Force new terminal
    // -1 -> Try to pick an existing session
    //
    // Positive values might get used in the future, if I decide to implement a different
    // session restoration process where the app detects that a previous launch had
    // open sessions - so on first connection to the host, we would match serials with
    // available sessions, and use that.
    var serial: Int = -1
    
    // TODO, this should be based on the user locale, not forced here
    var lang = "en_US.UTF-8"
    
    // This is used to track when the session started, and if it is taking too long,
    // we start to output diagnostics on the connection
    var started: Date

    nonisolated func channelReader (channel: Channel, data: Data?, error: Data?) {
        if let d = data {
            let sliced = Array(d) [0...]

            #if false
            // Process in one go, but results in ugly and slow rendering
            DispatchQueue.main.sync {
                self.feed(byteArray: sliced)
            }
            #else
            let blocksize = 1024
            var next = 0
            let last = sliced.endIndex
            
            while next < last {
                
                let end = min (next+blocksize, last)
                let chunk = sliced [next..<end]
            
                DispatchQueue.main.sync {
                    self.feed(byteArray: chunk)
                }
                next = end
            }
            #endif
        }
        if channel.receivedEOFunsafe {
            DispatchQueue.main.async {
                self.connectionClosed (receivedEOF: true)
            }
        }
    }
    
    // UTF-8, allow setting cursor color, xterm mouse sequences, RGB colors using SGR, setting terminal title, fill rects, margin support
    var tmuxFeatureFlags = "-T UTF-8,256,ccolor,mouse,RGB,title,rectfill,margins "
    let tmuxLegacyFeatureFlags = "-u -2"
    let tmuxSessionPrefix = "SwiftTermApp-"
    
    func setupChannel (session: Session) async -> Bool {
        // TODO: should this be different based on the locale?
        sessionChannel = await session.openSessionChannel(lang: lang, readCallback: channelReader)

        guard let channel = sessionChannel else {
            logConnection ("Failed to open a session channel")
            DispatchQueue.main.async {
                self.connectionError(error: "Failed to to open the channel")
            }
            return false
        }
        session.activate(channel: channel)

        // Pass the environment variables
        for (envKey, envVar) in host.environmentVariables {
            await channel.setEnvironment(name: envKey, value: envVar)
        }

        let terminal = getTerminal()
        let status = await channel.requestPseudoTerminal(name: "xterm-256color", cols: terminal.cols, rows: terminal.rows)
        if status != 0 {
            logConnection ("SSH: Failed to request pseudo-terminal on the remote host \(libSsh2ErrorToString(error: status))")

            DispatchQueue.main.async {
                self.connectionError(error: "Failed to request pseudo-terminal on the remote host\n\nDetail: \(libSsh2ErrorToString(error: status))")
            }
            return false
        }
        if host.reconnectType == "tmux" {
            if await tmuxConnection (channel) {
                return true
            }
        }
        logConnection ("SSH: starting up shell")
        let status2 = await channel.processStartup(request: "shell", message: nil)
        if status2 != 0 {
            logConnection ("SSH: failed to launch shell process: \(libSsh2ErrorToString(error: status2))")
            DispatchQueue.main.async {
                self.connectionError(error: "Failed to launch the shell process:\n\nDetail: \(libSsh2ErrorToString(error: status2))")
            }
            return false
        }
        logConnection ("Shell started up, activating")
        
        // Now, make sure we process any data that might have been queued while we were setting up before the channel activation.
        let _ = await channel.ping()
        return true
    }

    func launchNewTmux (_ channel: Channel, usedIds: [Int]) async -> Bool {
        serial = session.allocateConnectionId(avoidIds: usedIds)
        let status = await channel.processStartup(request: "exec", message: "tmux \(tmuxFeatureFlags) new-session -s 'SwiftTermApp-\(serial)'")
        if status != 0 {
            DispatchQueue.main.async {
                self.connectionError(error: "Failed to launch a new tmux session:\n\nDetail: \(libSsh2ErrorToString(error: status))")
            }
        }
        return status == 0
    }
    
    func attachTmux (_ channel: Channel, serial: Int) async -> Bool {
        let tmuxAttachCommand = "tmux \(self.tmuxFeatureFlags) attach-session -t SwiftTermApp-\(serial)"
        let status = await channel.processStartup(request: "exec", message: tmuxAttachCommand)
        if status == 0 {
            self.serial = serial
            return true
        } else {
            DispatchQueue.main.async {
                let _: GenericConnectionIssue? = self.displayError("Could not attach to the tmux session:\n\(status)")
            }
            return false
        }
    }

    func tmuxConnection (_ channel: Channel) async -> Bool {
        logConnection ("tmux: determining version")
        let oldTmux = await session.runSimple(command: "tmux -V", lang: lang) { (out, err) -> Bool in
            guard let str = out else {
                return true
            }
            if str.starts(with: "tmux 2.") || str.starts(with: "1.") {
                return true
            }
            // Only versions 3.2 and higher support -T, so rule out 3.0 and 3.1 manually (they contain letter suffixes and dashes for release candidates)
            if str.starts(with: "tmux 3.0") || str.starts(with: "3.1") {
                return true
            }
            // It is a new one
            return false
        }
        if oldTmux {
            tmuxFeatureFlags = tmuxLegacyFeatureFlags
        }
        logConnection ("tmux: getting sessions")
        let activeSessions = await session.runSimple(command: "tmux list-sessions -F '#{session_name},#{session_attached}'", lang: lang) { (out, err) -> [(id: Int, sessionCount: Int)] in
            var res: [(Int,Int)] = []
            guard let str = out else {
                return res
            }

            for line in (str).split (separator: "\n") {
                let recs = line.split(separator: ",")
                guard recs.count == 2 else {
                    continue
                }
                let sessionName = String (recs [0])
                if sessionName.starts(with: self.tmuxSessionPrefix) {
                    if let id = Int (String (sessionName.dropFirst(self.tmuxSessionPrefix.utf8.count))), let n = Int (String (recs [1])) {
                        res.append((id, n))
                    }
                }
            }
            return res
        }
        
        // This is the workflow this will attempt, the simplest approach that seems to balance
        // things out:
        // 1. If forced by "New Connection", just do that -> in the future, we should probably
        //    show an option in the UI to pick an open seesion, if one exists
        // 2. Otherwise, based on the list of sessions that exist on the server, try to attach
        //    to one that has no users first, then those that have sessions.
        // 3. If that fails, we create a new session
        if serial == -2 {
            logConnection ("tmux: launching tmux")
            if await !launchNewTmux(channel, usedIds: activeSessions.map { $0.id }) {
                return false
            }
        } else if serial == -1 {
            // try to pick a session without a controlling terminal first
            var foundSession = false
            for pair in activeSessions.sorted(by: { $0.sessionCount < $1.sessionCount }) {
                logConnection ("tmux: attaching to tmux serial \(pair.id)")
                if await attachTmux(channel, serial: pair.id) {
                    foundSession = true
                    break
                }
            }
            if !foundSession {
                logConnection ("tmux: launching new tmux instance")
                if await !launchNewTmux(channel, usedIds: activeSessions.map { $0.id }) {
                    return false
                }
            }
        } else {
            if activeSessions.contains (where: { $0.id == serial }) {
                logConnection ("tmux: attempting to attach to tmux session \(serial)")
                if await !attachTmux (channel, serial: serial) {
                    logConnection ("tmux: failed to attach to tmux session")
                    return false
                }
            } else {
                DispatchQueue.main.async {
                    self.closeTerminal()
                    let _: GenericConnectionIssue? = self.displayError("The tmux session no longer exists on the server")
                }
                return false
            }
        }
        // Code to test the reconnection, it forces a reconnection from the app in 5 seconds
        #if false
        DispatchQueue.main.asyncAfter (deadline: .now() + 5) {
            Task {
                await self.attemptReconnect()
            }
        }
        #endif
        return true
    }
    
    func directoryListing () async {
        var dir = "/"
        await session.runSimple(command: "pwd", lang: lang) { out, err in
            dir = out ?? "/"
        }
        dir = dir.replacingOccurrences(of: "\n", with: "")
        let sftp = await session.openSftp()
        if let dir = await sftp?.openDir(path: dir, flags: 0) {
            while let res = await dir.readDir() {
                print ("Got: \(res.attrs)")
                let s = String (bytes: res.name, encoding: .utf8) ?? "<Not Renderable>"
                print ("Got: \(s)")
            }
        }
    }

    // Logs a connection to the history
    func historyRecordConnection (_ date: Date) {
        let moc = globalHistoryController.container.viewContext
        
        let history = HistoryRecord(context: moc)
        history.id = UUID()
        history.hostId = host.id
        history.date = date
        history.hostname = host.hostname
        history.username = host.username
        history.hostkind = host.hostKind
        history.port = Int32 (host.port)
        
        history.event = HistoryOperation.connected(at: getLocation()).getAsData()
        do {
            try moc.save()
        } catch (let err) {
            print ("Got \(err)")
        }
    }
    
    func setupTerminalChannel (session: Session) async {
        let _ = await setupChannel (session: session)
        
        canOutputToConsole = false
        
        // Save the time we connected, as the guess can take longer, but we will record soon
        let connectionDate = Date ()
        
        // If the user did not set an icon
        if host.hostKind == ""  {
            await self.guessOsIcon ()
            
        }
        historyRecordConnection (connectionDate)
    }

    // Delegate SocketSessionDelegate.loggedIn: invoked when the connection has been authenticated
    func loggedIn (session: Session) async {
        await setupTerminalChannel (session: session)
    }
    
    func loginFailed(session: Session, details: String) {
        closeTerminal()
    }
    
    func closeTerminal () {
        if let channel = sessionChannel {
            session.unregister(channel: channel)
            sessionChannel = nil
        }
        session.drop (terminal: self)
        session = nil
    }
    
    func reconnect (session: Session) async {
       await setupTerminalChannel(session: session)
    }
    
    init (frame: CGRect, host: Host, serial: Int = -1) throws
    {
        self.serial = serial
        self.started = Date()
        try super.init (frame: frame, host: host)
        feed (text: "Welcome to SwiftTerm\r\n\n")
        startConnectionMonitor ()
        terminalDelegate = self
        
        if let existingSession = Connections.lookupActiveSession(host: host) as? SocketSession {
            session = existingSession
            Task.detached {
                await self.loggedIn(session: self.session)
            }
        } else {
            session = SocketSession(host: host, delegate: self)
            Connections.track(session: session)
        }
        session.track(terminal: self)

        if !useDefaultBackground {
            updateBackground(background: host.background)
        }
    }
    
    /// This flag indicates that this terminal view would like to get a callback if the session drops and reconnects
    var wantsSessionReconnect: Bool {
        return host.reconnectType == "tmux"
    }
    
    // SessionDelegate.getResponder method
    func getResponder() -> UIResponder? {
        return self
    }
  
    func displayError<T: View & ConnectionMessage> (_ msg: String) -> T? {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        closeTerminal()
        let parent = getParentViewController()
        
        var window: UIHostingController<T>!
        window = UIHostingController<T>(rootView: T(host: host, message: msg, ok: {
            window.dismiss(animated: true, completion: nil)
        }))
        
        //if #available(iOS (15.0), *) {
        
        // Temporary workaround until beta2 https://developer.apple.com/forums/thread/682203
        if let sheet = window.presentationController as? UISheetPresentationController {
            sheet.detents = [.medium()]
        }
        
        parent.present(window, animated: true, completion: nil)
        
        return nil
    }
    
    /// The connection has been closed, notify the user.
    func connectionClosed (receivedEOF: Bool) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        closeTerminal()
        let parent = getParentViewController()
        var window: UIHostingController<HostConnectionClosed>!
        window = UIHostingController<HostConnectionClosed>(rootView: HostConnectionClosed(host: host, receivedEOF: receivedEOF, ok: {
            window.dismiss(animated: true, completion: nil)
        }))
        
        //if #available(iOS (15.0), *) {
        
            // Temporary workaround until beta2 https://developer.apple.com/forums/thread/682203
            if let sheet = window.presentationController as? UISheetPresentationController {
                sheet.detents = [.medium()]
            }
        
        
        parent.present(window, animated: true, completion: nil)
    }
    
    /// The connection has been closed, notify the user.
    /// TODO: use the `displayError` instead, as we have no custom logic here
    func connectionError (error: String) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        logConnection("Connection: \(error)")
        closeTerminal()
        let parent = getParentViewController()
        var window: UIHostingController<HostConnectionError>!
        window = UIHostingController<HostConnectionError>(rootView: HostConnectionError(host: host, error: error, ok: {
            window.dismiss(animated: true, completion: nil)
        }))
        
        //if #available(iOS (15.0), *) {
        
            // Temporary workaround until beta2 https://developer.apple.com/forums/thread/682203
            if let sheet = window.presentationController as? UISheetPresentationController {
                sheet.detents = [.medium()]
            }
        
        
        parent.present(window, animated: true, completion: nil)
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // TerminalViewDelegate conformance
    public func scrolled(source: TerminalView, position: Double) {
        //
    }
    
    public func setTerminalTitle(source: TerminalView, title: String) {
        //
    }
    
    public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        if let c = sessionChannel {
            Task {
                await c.setTerminalSize(cols: newCols, rows: newRows, pixelWidth: 1, pixelHeight: 1)
            }
        }
    }
    
    public func bell (source: TerminalView)
    {
        switch settings.beepConfig {
        case .beep:
            // List of sounds: https://github.com/TUNER88/iOSSystemSoundsLibrary
            AudioServicesPlaySystemSound(SystemSoundID(1104))
        case .silent:
            break
        case .vibrate:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }
    
    public func send(source: TerminalView, data bytes: ArraySlice<UInt8>) {
        guard let channel = sessionChannel else {
            return
        }
        Task {
            await channel.send (Data (bytes)) { code in
                //print ("sendResult: \(code)")
            }
        }
    }
    
    public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        currentDirectory = directory
    }
    
    public func requestOpenLink (source: TerminalView, link: String, params: [String:String])
    {
        if let fixedup = link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            if let url = NSURLComponents(string: fixedup) {
                if let nested = url.url {
                    UIApplication.shared.open (nested)
                }
            }
        }
    }
    
    // Attempts to guess the kind of OS to update the icon displayed for the host.hostKind
    func guessOsIcon () async {
        let sftp = await session.openSftp()

        // If this is a Linux system
        if let _ = await sftp?.stat(path: "/etc") {
            await session.runSimple (command: "/usr/bin/uname || /bin/uname", lang: lang) { stdout, stderr in
                var os = ""
                let stdout = stdout?.replacingOccurrences(of: "\n", with: "")
                switch stdout {
                case "Linux":
                    os = "linux"
                    if let content = await sftp?.readFileAsString(path: "/etc/os-release", limit: 64*1024) {
                        for line in  content.split(separator: "\n") {
                            if line.starts(with: "ID=") {
                                switch line  {
                                case "ID=raspbian":
                                    os = "raspberry-pi"
                                case "ID=fedora":
                                    os = "fedora"
                                case "ID=rhel":
                                    os = "redhat"
                                case "ID=ubuntu":
                                    os = "ubuntu"
                                case "ID=opensuse", "ID=opensuse-leap", "ID=sles", "ID=sles_sap":
                                    os = "suse"
                                default:
                                    break
                                }
                                break
                            }
                        }
                    }

                case "Darwin":
                    os = "apple"

                default:
                    break
                }
                // Make a copy to make swift happy
                let nos = os
                DispatchQueue.main.async {
                    DataStore.shared.updateKind(for: self.host, to: nos)
                }
            }
        } else {
            DispatchQueue.main.async {
                DataStore.shared.updateKind(for: self.host, to: "windows")
            }
        }
    }
    
    // During the startup, we can output to the console, but once the connection is established,
    // we should not do this, as it will overlap the remote end data, and we need to show an
    // UI instead
    var canOutputToConsole = true
    func logConnection (_ msg: String) {
        session.logConnection(msg)
    }
 
    // Number of seconds before we start logging diagnostics information if the connection does not succeed
    let connectionMonitorDelay = 4.0
    
    // The monitor is only active at startup
    func startConnectionMonitor () {
        DispatchQueue.main.asyncAfter(deadline: .now() + connectionMonitorDelay){
            if self.canOutputToConsole {
                self.flushMessages ()
            }
        }
    }

    func flushMessages () {
        DispatchQueue.main.async {
            guard self.canOutputToConsole else {
                return
            }
            for x in self.session.messageManager.getMessages() {
                self.feed(text: "\(timeStampFormatter.string(from: x.time)): \(x.msg)\r\n")
            }
            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: self.flushMessages)
        }
    }
}

// TODO: This is a hack, it should be local to the function that uses, but I can not seem to convince swift to let mme do that.
var promptedPassword: String = ""
var promptedUser: String = ""

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

    // Delegate SocketSessionDelegate.authenticate: invoked to trigger authentication
    func authenticate (session: Session) async -> String? {
        
        func loginWithKey (_ sshKey: Key) async -> String? {
            switch sshKey.type {
            case .rsa(_), .ecdsa(inEnclave: false):
                var password: String
                
                if SshUtil.openSSHKeyRequiresPassword(key: sshKey.privateKey) && sshKey.passphrase == "" {
                    password = self.passwordPrompt (challenge: "Key requires password")
                } else {
                    password = sshKey.passphrase
                }
                
                return await session.userAuthPublicKeyFromMemory (username: host.username,
                                                       passPhrase: password,
                                                       publicKey: sshKey.publicKey,
                                                       privateKey: sshKey.privateKey)
            case .ecdsa(inEnclave: true):
                if let keyHandle = sshKey.getKeyHandle() {
                    return await session.userAuthWithCallback(username: host.username, publicKey: sshKey.getPublicKeyAsData()) { dataToSign in
                        var error: Unmanaged<CFError>?
                        guard let signed = SecKeyCreateSignature(keyHandle, .ecdsaSignatureMessageX962SHA256, dataToSign as CFData, &error) else {
                            return nil
                        }
                        return signed as NSData as Data
                    }
                } else {
                    return "Could not fetch the enclave key"
                }
            }
        }
        
        let authMethods = await session.userAuthenticationList(username: host.username)
        
        if authMethods == "" {
            return nil
        }
        
        var cumulativeErrors: [String] = []
        
        // First, try to use what the user configured
        if authMethods.contains("publickey") && host.sshKey != nil {
            if let sshKey = DataStore.shared.keys.first(where: { $0.id == host.sshKey! }) {
                if let error = await loginWithKey (sshKey) {
                    cumulativeErrors.append (error)
                } else {
                    return nil
                }
            }
        }
        if authMethods.contains ("password") && host.usePassword {
            if let error = await session.userAuthPassword (username: host.username, password: host.password) {
                cumulativeErrors.append (error)
            }
            return nil
        }
        
        // Ok, none of the presets work, try all the public keys that have a passphrase
        if authMethods.contains ("publickey") {
            let skip = host.sshKey == nil ? nil : DataStore.shared.keys.first(where: { $0.id == host.sshKey! })
            
            for sshKey in DataStore.shared.keys {
                // Skip the key that was original bound to it
                if skip != nil && skip!.id == sshKey.id {
                    continue
                }
                if let error = await loginWithKey (sshKey) {
                    cumulativeErrors.append (error)
                } else {
                    return nil
                }
            }
        }

        if authMethods.contains ("keyboard-interactive") {
                if let error = await session.userAuthKeyboardInteractive(username: host.username, prompt: passwordPrompt) {
                    cumulativeErrors.append(error)
                } else {
                    return nil
                }
        }
        
        return cumulativeErrors.last ?? "No valid autentication options available: \(authMethods)"
    }
    
    // Delegate SocketSessionDelegate.loginFailed, invoked if the authentication fails
    func loginFailed(session: Session, details: String) {
        DispatchQueue.main.async {
            self.connectionError(error: details)
        }
    }
    
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
        if channel.receivedEOF {
            DispatchQueue.main.async {
                self.connectionClosed (receivedEOF: true)
            }
        }
    }
    
    func setupChannel (session: Session) async {
        // TODO: should this be different based on the locale?
        sessionChannel = await session.openSessionChannel(lang: "en_US.UTF-8", readCallback: channelReader)

        guard let channel = sessionChannel else {
            DispatchQueue.main.async {
                self.connectionError(error: "Failed to to open the channel")
            }
            return
        }
        if await !checkHostIntegrity (host: self.host) {
            return
        }
        
        let terminal = getTerminal()
        let status = await channel.requestPseudoTerminal(name: "xterm-256color", cols: terminal.cols, rows: terminal.rows)
        if status != 0 {
            DispatchQueue.main.async {
                self.connectionError(error: "Failed to request pseudo-terminal on the remote host\n\nDetail: \(libSsh2ErrorToString(error: status))")
            }
            return
        }
        let status2 = await channel.processStartup(request: "shell", message: nil)
        if status2 != 0 {
            DispatchQueue.main.async {
                self.connectionError(error: "Failed to launch the shell process:\n\nDetail: \(libSsh2ErrorToString(error: status2))")
            }
            return
        }
        session.activate(channel: channel)
    }
    
    // Delegate SocketSessionDelegate.loggedIn: invoked when the connection has been authenticated
    func loggedIn (session: Session) async {
        await setupChannel (session: session)

        var todo = true
        // If the user did not set an icon
        if host.hostKind == "" || todo {
            await self.guessOsIcon ()
        }
    }

    override init (frame: CGRect, host: Host) throws
    {
        try super.init (frame: frame, host: host)

        session = SocketSession(host: host.hostname, port: UInt16 (host.port & 0xffff), delegate: self)
        
        if !useDefaultBackground {
            updateBackground(background: host.background)
        }
        terminalDelegate = self
    }
  
    func getParentViewController () -> UIViewController? {
       var parentResponder: UIResponder? = self
       while parentResponder != nil {
           parentResponder = parentResponder?.next
           if let viewController = parentResponder as? UIViewController {
               return viewController
           }
       }
       return nil
    }
    
    
    var passwordTextField: UITextField?
    nonisolated func passwordPrompt (challenge: String) -> String {

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            guard let vc = self.getParentViewController() else {
                return
            }

            let alertController = UIAlertController(title: "Authentication challenge", message: challenge, preferredStyle: .alert)
            alertController.addTextField { [unowned self] (textField) in
                textField.placeholder = challenge
                textField.isSecureTextEntry = true
                self.passwordTextField = textField
            }
            alertController.addAction(UIAlertAction(title: "OK", style: .default) { [unowned self] _ in
                if let tf = self.passwordTextField {
                    promptedPassword = tf.text ?? ""
                }
                semaphore.signal()
                
            })
            vc.present(alertController, animated: true, completion: nil)
        }
        
        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return promptedPassword
    }
    
    /// The connection has been closed, notify the user.
    func connectionClosed (receivedEOF: Bool) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        Connections.remove(self)
        if let parent = getParentViewController() {
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
    }
    
    /// The connection has been closed, notify the user.
    func connectionError (error: String) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        Connections.remove(self)
        if let parent = getParentViewController() {
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
    }
        
    var debugLog: [(Date,String)] = []
    func debug(session: Session, alwaysDisplay: Bool, message: Data, language: Data) {
        let msg = String (bytes: message, encoding: .utf8) ?? "<invalid encoding>"
        print ("debug: \(msg)")
        debugLog.append ((Date (),msg))
    }

    func getHostName (host: Host) -> String {
        if host.port != 22 {
            return "\(host.hostname):\(host.port)"
        }
        return host.hostname
    }
    
    // When we connect to a new host that is unknown to us, let the user confirm
    // that the key the host is sharing is the one they are expecting
    //
    // Returns true if the user wishes to proceed
    func confirmHostAuthUnknown (hostKeyType: String, key: [Int8], fingerprint: String, knownHosts: LibsshKnownHost, host: Host) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var ok = true
        
        DispatchQueue.main.async {
            if let parent = self.getParentViewController() {
                var window: UIHostingController<HostAuthUnknown>!
                window = UIHostingController<HostAuthUnknown>(rootView: HostAuthUnknown(alias: self.host.alias, hostString: self.getHostName(host: host), fingerprint: fingerprint, cancelCallback: {
                        ok = false
                        Connections.remove(self)
                        window.dismiss (animated: true) { semaphore.signal ()}
                    }, okCallback: {
                        window.dismiss (animated: true) {
                            semaphore.signal ()
                        }
                    }))
                parent.present(window, animated: true, completion: nil)
            }
        }
        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        if ok {
            if let addError = knownHosts.add(hostname: self.host.hostname, port: Int32 (self.host.port), key: key, keyType: hostKeyType, comment: self.host.alias) {
                print ("Error adding host to knownHosts: \(addError)")
            }
            if let writeError = knownHosts.writeFile(filename: DataStore.shared.knownHostsPath) {
                print ("Error writing knownhosts file \(writeError)")
            }
            DataStore.shared.loadKnownHosts()
        }
        return ok
    }
    /// Checks that we are connecting to the host we thought we were,
    /// this uses and updates the `known_hosts` database to track the
    /// known hosts
    ///
    /// Returns true on success, false on error
    func checkHostIntegrity (host: Host) async -> Bool {
        guard let knownHosts = await session.makeKnownHost() else {
            return false
        }
        
        @MainActor
        func getFingerPrint () async -> String {
            guard let bytes = await session.getFingerprintBytes() else { return "Unknown" }
            let d = Data (bytes)
            return "SHA256:" + d.base64EncodedString()
        }
        
        func closeConnection (description: String) {
            
        }
        
        func showHostKeyMismatch (fingerprint: String) {
            let semaphore = DispatchSemaphore(value: 0)

            DispatchQueue.main.async {
                Connections.remove (self)
                if let parent = self.getParentViewController() {
                    var window: UIHostingController<HostAuthKeyMismatch>!
                    
                    window = UIHostingController<HostAuthKeyMismatch>(rootView: HostAuthKeyMismatch(alias: self.host.alias, hostString: self.getHostName(host: host), fingerprint: fingerprint, callback: {
                        window.dismiss(animated: true, completion: {
                            
                        })
                        
                    }))
                    parent.present(window, animated: true, completion: nil)
                }
            }
            semaphore.wait ()
            
        }
        
        if let _ = await knownHosts.readFile (filename: DataStore.shared.knownHostsPath) {
            return false
        }
        
        if let keyAndType = await session.hostKey() {
            let res = knownHosts.check (hostName: host.hostname, port: Int32 (host.port), key: keyAndType.key)
            let hostKeyType = SshUtil.extractKeyType (keyAndType.key)
            
            switch res.status {
            case .notFound, .failure:
                if confirmHostAuthUnknown(hostKeyType: hostKeyType ?? "", key: keyAndType.key, fingerprint: await getFingerPrint(), knownHosts: knownHosts, host: host) {
                    return true
                }
                await session.disconnect(description: "User did not accept this host")
                return false

            case .keyMismatch:
                showHostKeyMismatch (fingerprint: await getFingerPrint())
                await session.disconnect(description: "Known host key mismatch")
                return false
            case .match:
                // We are good!
                break
            }
        }
        return true
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
            await session.runSimple (command: "/usr/bin/uname || /bin/uname", lang: "en_US.UTF_8") { stdout, stderr in
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
                    os = "mac"

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
    
}

// TODO: This is a hack, it should be local to the function that uses, but I can not seem to convince swift to let mme do that.
var promptedPassword: String = ""

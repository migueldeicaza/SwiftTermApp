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
    
    //var shell: SSHShell?
    var sshQueue: DispatchQueue
    
    var completeConnectSetup: () -> () = { }
    var session: SocketSession!
    var sessionChannel: Channel?

    // Delegate SocketSessionDelegate.authenticate: invoked to trigger authentication
    func authenticate (session: Session) -> String? {
        let authMethods = session.userAuthenticationList(username: host.username)
        for m in authMethods {
            switch m {
            case "none":
                return nil
            case "publickey":
                if let sshKeyId = host.sshKey {
                    if let sshKey = DataStore.shared.keys.first(where: { $0.id == sshKeyId }) {
                        switch sshKey.type {
                        case .rsa(_), .ecdsa(inEnclave: false):
                            var password: String
                            
                            if SshUtil.openSSHKeyRequiresPassword(key: sshKey.privateKey) && sshKey.passphrase == "" {
                                password = self.passwordPrompt (challenge: "Key requires password")
                            } else {
                                password = sshKey.passphrase
                            }
                            
                            return session.userAuthPublicKeyFromMemory (username: host.username,
                                                                   password: password,
                                                                   publicKey: sshKey.publicKey,
                                                                   privateKey: sshKey.privateKey)
                        case .ecdsa(inEnclave: true):
                            if let keyHandle = sshKey.getKeyHandle() {
                                return session.userAuthWithCallback(username: host.username, publicKey: sshKey.getPublicKeyAsData()) { dataToSign in
                                    var error: Unmanaged<CFError>?
                                    guard let signed = SecKeyCreateSignature(keyHandle, .ecdsaSignatureMessageX962SHA256, dataToSign as CFData, &error) else {
                                        return nil
                                    }
                                    return signed as NSData as Data
                                }
                            } else {
                                print ("Did not get a handle to the sshKey")
                                break
                            }
                        }
                    } else {
                        return "The host references an SSH key that is no longer set"
                    }
                }
                break
            case "password":
                if host.usePassword && host.password != "" {
                    // TODO: perhaps empty passwords are ok?
                    if let error = session.userAuthPassword (username: host.username, password: host.password) {
                        return error
                    }
                    return nil
                }
                break
            case "keyboard-interactive":
                if let error = session.userAuthKeyboardInteractive(username: host.username, prompt: passwordPrompt) {
                    return error
                }
                return nil
            default:
                break
            }
        }
        return nil
    }
    
    // Delegate SocketSessionDelegate.loginFailed, invoked if the authentication fails
    func loginFailed(session: Session, details: String) {
        abort ()
    }
    
    func setupReadingWriting () {
        
    }
    
    func channelReader (channel: Channel, data: Data?, error: Data?) {
        if channel.receivedEOF {
            self.connectionClosed (receivedEOF: true)
        }
        
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
    }
    
    func setupChannel (session: Session) {
        sessionChannel = session.openChannel(type: "session", readCallback: channelReader)

        guard let channel = sessionChannel else {
            print ("Failed to open channel")
            // TODO Need to report to the user the failure
            abort ()
        }
        if let error = checkHostIntegrity () {
            print ("Got an error during integrity check: \(error)")
        }
        setupReadingWriting ()
        // TODO: should this be different based on the locale?
        channel.setEnvironment(name: "LANG", value: "en_US.UTF-8")
        let terminal = getTerminal()
        var status: Int32
        status = channel.requestPseudoTerminal(name: "xterm-256color", cols: terminal.cols, rows: terminal.rows)
        if status != 0 {
            print ("Failed to request PTY, code: \(libSsh2ErrorToString(error: status))")
            abort ()
        }
        status = channel.processStartup(request: "shell", message: nil)
        if status != 0 {
            print ("Failed to spawn process: \(libSsh2ErrorToString(error: status))")
            abort ()
        }
        session.activate(channel: channel)
    }
    
    // Delegate SocketSessionDelegate.loggedIn: invoked when the connection has been authenticated
    func loggedIn (session: Session) {
        setupChannel (session: session)
    }
    
    override init (frame: CGRect, host: Host) throws
    {
        sshQueue = DispatchQueue.global(qos: .background)
        
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
    
    var promptedPassword: String = ""
    var passwordTextField: UITextField?
    
    func passwordPrompt (challenge: String) -> String {
        guard let vc = getParentViewController() else {
            return ""
        }

        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Authentication challenge", message: challenge, preferredStyle: .alert)
            alertController.addTextField { [unowned self] (textField) in
                textField.placeholder = challenge
                textField.isSecureTextEntry = true
                self.passwordTextField = textField
            }
            alertController.addAction(UIAlertAction(title: "OK", style: .default) { [unowned self] _ in
                if let tf = self.passwordTextField {
                    self.promptedPassword = tf.text ?? ""
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
    
    /// Checks that we are connecting to the host we thought we were,
    /// this uses and updates the `known_hosts` database to track the
    /// known hosts
    ///
    /// Returns nil on success, otherwise a description of the problem
    func checkHostIntegrity () -> String? {

        guard let knownHosts = session.makeKnownHost() else {
            return "Unable to create Known Hosts"
        }
        
        func getHostName () -> String {
            if host.port != 22 {
                return "\(host.hostname):\(host.port)"
            }
            return host.hostname
        }
        
        func getFingerPrint () -> String {
            guard let bytes = session.fingerprintBytes(.sha256) else { return "Unknown" }
            let d = Data (bytes)
            return "SHA256:" + d.base64EncodedString()
        }
        
        func closeConnection (reason: String) {
            session.disconnect(reason: reason)
            Connections.remove(self)
        }
        
        if let krerr = knownHosts.readFile (filename: DataStore.shared.knownHostsPath) {
            return krerr
        }
        
        if let keyAndType = session.hostKey() {
            let res = knownHosts.check (hostName: host.hostname, port: Int32 (host.port), key: keyAndType.key)
            let hostKeyType = SshUtil.extractKeyType (keyAndType.key)
            
            switch res.status {
            case .notFound, .failure:
                if let parent = getParentViewController() {
                    var window: UIHostingController<HostAuthUnknown>!
                    window = UIHostingController<HostAuthUnknown>(rootView: HostAuthUnknown(alias: host.alias, hostString: getHostName(), fingerprint: getFingerPrint(), cancelCallback: {
                            window.dismiss (animated: true, completion: nil)
                            
                        closeConnection(reason: "User did not accept this host")
                        }, okCallback: {
                            if let addError = knownHosts.add(hostname: self.host.hostname, port: Int32 (self.host.port), key: keyAndType.key, keyType: hostKeyType ?? "", comment: self.host.alias) {
                                print ("Error adding host to knownHosts: \(addError)")
                                return
                            }
                            if let writeError = knownHosts.writeFile(filename: DataStore.shared.knownHostsPath) {
                                print ("Error writing knownhosts file \(writeError)")
                                return
                            }
                            DataStore.shared.loadKnownHosts()
                            window.dismiss (animated: true, completion: nil)
                        }))
                    parent.present(window, animated: true, completion: nil)
                }
                break
            case .keyMismatch:
                if let parent = getParentViewController() {
                    var window: UIHostingController<HostAuthKeyMismatch>!
                    
                    window = UIHostingController<HostAuthKeyMismatch>(rootView: HostAuthKeyMismatch(alias: host.alias, hostString: getHostName(), fingerprint: getFingerPrint(), callback: {
                        window.dismiss(animated: true, completion: {
                            closeConnection(reason: "Known host key mismatch")
                        })
                        
                    }))
                    parent.present(window, animated: true, completion: nil)
                }
                break
            case .match:
                // We are good!
                break
            }
        }
        return nil
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
            c.setTerminalSize(cols: newCols, rows: newRows, pixelWidth: 1, pixelHeight: 1)
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
        channel.send (Data (bytes)) { code in
            //print ("sendResult: \(code)")
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
}


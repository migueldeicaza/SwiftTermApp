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
import SwiftSH

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
    
    var shell: SSHShell?
    var authenticationChallenge: AuthenticationChallenge!
    var sshQueue: DispatchQueue
    
    var completeConnectSetup: () -> () = { }
    var ss: SocketSession!
    var channel: Channel?
    
    // Delegate method invoked by the SocketSession to authenticate
    func authenticate (session: Session) -> String? {
        let authMethods = session.userAuthenticationList(username: host.username)
        for m in authMethods {
            switch m {
            case "none":
                return nil
            case "publickey":
                print ("Do not know how to do publickey yet")
                break
            case "password":
                if host.usePassword && host.password != "" {
                    // TODO: perhaps empty passwords are ok?
                    if let error = ss.userAuthPassword (username: host.username, password: host.password) {
                        return error
                    }
                    return nil
                }
                break
            case "keyboard-interactive":
                print ("Do not know how to do keyboard-interactive yet")
                break
            default:
                break
            }
        }
        return nil
    }
    
    // Delegate method, invoked if the authentication fails
    func loginFailed(session: Session, details: String) {
        abort ()
    }
    
    func setupReadingWriting () {
        
    }
    
    func setupChannel (session: Session) {
        channel = session.openChannel(type: "session")
        guard let channel = channel else {
            // TODO Need to report to the user the failure
            abort ()
            return
        }
        setupReadingWriting ()
        // TODO: should this be different based on the locale?
        channel.setEnvironment(name: "LANG", value: "en_US.UTF-8")
        let terminal = getTerminal()
        var a = channel.requestPseudoTerminal(name: "xterm-256color", cols: terminal.cols, rows: terminal.rows)
        print ("requestPty: \(a)")
        a = channel.processStartup(request: "shell", message: nil)
        print ("processStartup: \(a)")
        channel.setupIO { channel, data, error in
            let receivedEOF = channel.receivedEOF
            let socketClosed = (data == nil && error == nil)
            if receivedEOF || socketClosed {
                print ("here")
                DispatchQueue.main.async {
                    self.connectionClosed (receivedEOF: receivedEOF)
                }
            }
            
            if let d = data {
                let sliced = Array(d) [0...]
 
                // The first code causes problems, because the SSH library
                // accumulates data, rather that sending it as it comes,
                // so it can deliver blocks of 300k to 2megs of data
                // which as far as the user is concerned, nothing happens
                // while the terminal parsers proceses this.
                //
                // The solution was below, and it fed the data in chunks
                // to the UI, but this caused the UI to not update chunks
                // of the screen, for reasons that I do not understand yet.
                #if true
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
    }
    
    func loggedIn (session: Session) {
        setupChannel (session: session)
    }
    
    override init (frame: CGRect, host: Host) throws
    {
        sshQueue = DispatchQueue.global(qos: .background)
        
        try super.init (frame: frame, host: host)
        
        // Default, in case there is an error extracting the key from the secure enclave
        authenticationChallenge = .byKeyboardInteractive(username: host.username, callback: passwordPrompt )
        
        if host.usePassword {
            if host.password == "" {
                authenticationChallenge = .byKeyboardInteractive(username: host.username, callback: passwordPrompt )
            } else {
                authenticationChallenge = .byPassword(username: host.username, password: host.password)
            }
        } else {
            if let sshKeyId = host.sshKey {
                if let sshKey = DataStore.shared.keys.first(where: { $0.id == sshKeyId }) {
                    switch sshKey.type {
                    case .rsa(_), .ecdsa(inEnclave: false):
                        if SshUtil.openSSHKeyRequiresPassword(key: sshKey.privateKey) && sshKey.passphrase == "" {
                            completeConnectSetup = {
                                let password = self.passwordPrompt (challenge: "Key requires password")
                                self.authenticationChallenge = .byPublicKeyFromMemory(username: self.host.username,
                                                                                 password: password,
                                                                                 publicKey: Data (sshKey.publicKey.utf8),
                                                                                 privateKey: Data (sshKey.privateKey.utf8))
                            }
                        } else {
                            authenticationChallenge = .byPublicKeyFromMemory(username: self.host.username,
                                                                         password: sshKey.passphrase,
                                                                         publicKey: Data (sshKey.publicKey.utf8),
                                                                         privateKey: Data (sshKey.privateKey.utf8))
                        }
                    case .ecdsa(inEnclave: true):
                        if let keyHandle = sshKey.getKeyHandle() {
                            authenticationChallenge = .byCallback(username: self.host.username, publicKey: sshKey.getPublicKeyAsData()) { dataToSign in
                                var error: Unmanaged<CFError>?
                                guard let signed = SecKeyCreateSignature(keyHandle, .ecdsaSignatureMessageX962SHA256, dataToSign as CFData, &error) else {
                                    return nil
                                }
                                return signed as NSData as Data
                            }
                        }
                    }
                } else {
                    throw MyError.noValidKey ("The host references an SSH key that is no longer set")
                }
            } else {
                throw MyError.noValidKey ("The host does not have an SSH key associated")
            }
        }

        ss = SocketSession(host: host.hostname, port: UInt16 (host.port & 0xffff), delegate: self)
        
        if !useDefaultBackground {
            updateBackground(background: host.background)
        }
        terminalDelegate = self
//        

//        shell = try? SSHShell(sshLibrary: Libssh2.self,
//                              host: host.hostname,
//                              port: UInt16 (host.port & 0xffff),
//                              environment: [Environment(name: "LANG", variable: "en_US.UTF-8")],
//                              terminal: "xterm-256color")
//        //shell?.log.enabled = true
//        //shell?.log.level = .debug
        shell?.setCallbackQueue(queue: sshQueue)
//        
//        sshQueue.async {
//            self.connect ()
//        }        
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
    
    func connect()
    {
        completeConnectSetup ()
        if let s = shell {
            s.withCallback { [unowned self] (data: Data?, error: Data?) in
                let receivedEOF = s.channel.receivedEOF
                let socketClosed = (data == nil && error == nil)
                if receivedEOF || socketClosed {
                    DispatchQueue.main.async {
                        connectionClosed (receivedEOF: receivedEOF)
                    }
                }
                
                if let d = data {
                    let sliced = Array(d) [0...]
     
                    // The first code causes problems, because the SSH library
                    // accumulates data, rather that sending it as it comes,
                    // so it can deliver blocks of 300k to 2megs of data
                    // which as far as the user is concerned, nothing happens
                    // while the terminal parsers proceses this.
                    //
                    // The solution was below, and it fed the data in chunks
                    // to the UI, but this caused the UI to not update chunks
                    // of the screen, for reasons that I do not understand yet.
                    #if true
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
            .connect()
            .authenticate(self.authenticationChallenge) { opt_error in
                DispatchQueue.main.async {
                    if let error = opt_error {
                        self.feed(text: "[ERROR] \(error)\n\r")
                        self.connectionError (error: "\(error)")
                    } else {
                        s.open { [unowned self] (error) in
                            DispatchQueue.main.async {
                                if let error = error {
                                    self.feed(text: "[ERROR] \(error)\n\r")
                                    connectionError (error: "\(error)")
                                } else {
                                    checkHostIntegrity ()
                                    
                                    let t = self.getTerminal()
                                    s.setTerminalSize(width: UInt (t.cols), height: UInt (t.rows))
                                }
                            }
                        }
                    }
                }
            }
        }
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
    func checkHostIntegrity () {
        let session = self.shell!.session

        let knownHosts = session.makeKnownHost()
        
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
        
        func closeConnection () {
            try? session.disconnect()
            Connections.remove(self)
        }
        
        try? knownHosts.readFile(filename: DataStore.shared.knownHostsPath)
        if let keyAndType = session.hostKey() {
            let res = knownHosts.check (hostName: host.hostname, port: Int32 (host.port), key: keyAndType.key)
            let hostKeyType = SshUtil.extractKeyType (keyAndType.key)
            
            switch res.status {
            case .notFound, .failure:
                if let parent = getParentViewController() {
                    var window: UIHostingController<HostAuthUnknown>!
                    window = UIHostingController<HostAuthUnknown>(rootView: HostAuthUnknown(alias: host.alias, hostString: getHostName(), fingerprint: getFingerPrint(), cancelCallback: {
                            window.dismiss (animated: true, completion: nil)
                            
                            closeConnection()
                        }, okCallback: {
                            try? knownHosts.add(hostname: self.host.hostname, port: Int32 (self.host.port), key: keyAndType.key, keyType: hostKeyType ?? "", comment: self.host.alias)
                            do {
                                try knownHosts.writeFile(filename: DataStore.shared.knownHostsPath)
                                DataStore.shared.loadKnownHosts()
                            } catch {
                                print ("Error writing knownhosts file \(error)")
                            }
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
                            closeConnection()
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
        if let c = channel {
            c.setTerminalSize(cols: Int(newCols), rows: Int(newRows), pixelWidth: 1, pixelHeight: 1)
        }
        if let s = shell {
            //print ("SshTerminalView setting remote terminal to \(newCols)x\(newRows)")
            s.setTerminalSize(width: UInt (newCols), height: UInt (newRows))
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
        guard let channel = channel else {
            return
        }
        channel.send (Data (bytes)) { err in
            print ("Error sending \(err)")
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


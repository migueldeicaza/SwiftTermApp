//
//  Prompts.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 5/7/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

/// Provides synchronous static methods for UI tasks like prompts or messages.
//
/// These must be invoked from a background thread
/// - `password (vc:challenge:)`
/// - `user(vc:)`
/// 
public class Dialogs {
    
    var vc: UIViewController
    init (parentVC: UIViewController) {
        dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))

        vc = parentVC
    }
    
    public static func password (vc: UIViewController, challenge: String) -> String {
        let p = Dialogs (parentVC: vc)
        return p.passwordPrompt (challenge: challenge)
    }
    
    public static func user (vc: UIViewController) -> String {
        let p = Dialogs (parentVC: vc)
        return p.userPrompt ()
    }
    
    /// Interactive prompt to request a password
    /// - Parameters:
    ///  - challenge: the text to display to the user
    /// - Returns: the entered password
    func passwordPrompt (challenge: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: String (localized: "Authentication challenge"), message: challenge, preferredStyle: .alert)
            alertController.addTextField { [unowned self] (textField) in
                textField.placeholder = challenge
                textField.isSecureTextEntry = true
                self.passwordTextField = textField
            }
            alertController.addAction(UIAlertAction(title: String (localized: "OK"), style: .default) { [unowned self] _ in
                if let tf = self.passwordTextField {
                    promptedPassword = tf.text ?? ""
                }
                semaphore.signal()
                
            })
            self.vc.present(alertController, animated: true, completion: nil)
        }
        
        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return promptedPassword
    }
    
    /// Interactive prompt to request a username
    var usernameTextField: UITextField?

    func userPrompt () -> String {
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "Username", message: "Enter your username", preferredStyle: .alert)
            alertController.addTextField { [unowned self] (textField) in
                textField.placeholder = ""
                self.usernameTextField = textField
            }
            alertController.addAction(UIAlertAction(title: "OK", style: .default) { [unowned self] _ in
                if let tf = self.usernameTextField {
                    promptedUser = tf.text ?? ""
                }
                semaphore.signal()
                
            })
            self.vc.present(alertController, animated: true, completion: nil)
        }
        
        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return promptedUser
    }
    var passwordTextField: UITextField?
}

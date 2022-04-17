//
//  HostTracking.swift
//  SwiftTermApp
//
//  Created by Miguel de Icaza on 4/17/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import Foundation

class HostTracking {
    weak var session: Session?
    var channel: Channel!
    
    func readCallback (channel: Channel, stdout: Data?, stderr: Data?) {
        print ("In read callback outBytes=\(stdout?.count) errBytes=\(stderr?.count)")
        stdout?.dump()
        stderr?.dump()
    }
    
    init? (_ session: Session) async {

        channel = nil
        self.session = session
        
        guard let ch = await session.openSessionChannel(lang: "en_US", readCallback: readCallback) else {
            return nil
        }
        channel = ch
        
        let status = await channel.exec ("/bin/sh")
        if status == 0 {
            session.activate(channel: channel)

            Task {
                while true {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await channel.send(Data ("uptime\n".utf8)) { status in
                        print ("sending command  status -> \(status)")
                    }
                }
            }
            self.channel = ch
            return
        }
        await channel.close ()
        return nil
    }
}

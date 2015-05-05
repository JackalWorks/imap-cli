//
//  ImapCLIExecution.swift
//  imap-cli
//
//  Created by Are Digranes on 23.04.15.
//  Copyright (c) 2015 Are Digranes. All rights reserved.
//

import Foundation

class ImapCLIExecution: NSObject {
    
    // MARK: Program initialization
    
    enum Usage: Character {
        case TCP_PORT = "p"
        case ENCRYPTION = "s"
        case SELFSIGNED = "u"
        case COLORIZE = "c"
        case LOGFILE = "l"
    }

    // MARK: Program usage
    let usage = String(
        "Usage: imap-cli <server> [-p <port>] [-s] [-u] [-c] [-l <file>]\n",
        "         server - The IMAP server address\n",
        "         -p     - The server port (Default is \(DEFAULT_IMAP_TCP_PORT))\n",
        "         -s     - Use encryption (TLS/SSL) (Default port changes to \(DEFAULT_IMAP_TCP_TLS_PORT))\n",
        "         -u     - Unsecure encryption (to allow self-signed certificates)\n",
        "         -c     - Colorize output\n",
        "         -l     - Create a transcript log of IMAP communication"
    )

    let options: CLIOptions = CLIOptions(optstring: "p:sucl:")
    
    // Notifications
    let TCP_TOKEN = "com.jackalworks.imap-cli.tcp-token"
    let STD_TOKEN = "com.jackalworks.imap-cli.std-token"
    
    // Run
    var running = true
    
    // Terminal
    var terminal: Terminal? = nil
    
    // Internet Connection
    var connection: TCPConnection? = nil
    
    override init() {
        
        // Check the options and usage
        if options.UserEnteredUnknownOption {
            println(usage)
            exit(0)
        }
        
        // TODO: Enable logging
        var log: LogFile? = nil
        if options.valueOfOption(Usage.LOGFILE.rawValue) == true {
            if let path: String = options.valueOfOption(Usage.LOGFILE.rawValue) {
                log = LogFile(path: path)
            }
        }

        super.init()
    }
    
    func start() {
        
        // Attach to Standard streams
        let std = StdControl(notificationName: STD_TOKEN)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reader:", name: STD_TOKEN, object: std)
        std.start()
        
        // Create our terminal
        self.terminal = Terminal(control: std)

        // Connect to server
        var hostname = ""
        var port = DEFAULT_IMAP_TCP_PORT
        if options.valueOfOption(Usage.ENCRYPTION.rawValue) == true { port = DEFAULT_IMAP_TCP_TLS_PORT }
        if let value: Int = options.valueOfOption(Usage.TCP_PORT.rawValue) { port = value }
        
        if let value: String = options.valueOfArgument(1) {
            hostname = value
        } else {
            #if RELEASE
            println(usage)
            running = false
            #endif
        }
        
        #if DEBUG
            println("ImapCLIExecution: Debugging...")
            hostname = "10.0.1.108"
            port = 993
        #endif
        
        if hostname != "" {
            println("Connecting to \(hostname) on port \(port)...")
            #if RELEASE
                connection = TCPConnection(hostname: hostname, port: port, encrypt: options.valueOfOption(Usage.ENCRYPTION.rawValue), unsecure: options.valueOfOption(Usage.SELFSIGNED.rawValue), notificationName: TCP_TOKEN)
            #endif
            
            #if DEBUG
                connection = TCPConnection(hostname: hostname, port: port, encrypt: true, unsecure: true, notificationName: TCP_TOKEN)
            #endif
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "reader:", name: TCP_TOKEN, object: connection)
            
            if let c = connection {
                c.connect()
            } else {
                running = false
            }

        }
        
        // The running loop
        while running && NSRunLoop.mainRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 100)) {}
        
        terminal = nil
        
    }    
    
    // Notification receiver
    func reader(notification: NSNotification) {
        #if DEBUG
        //println("ImapCLIExecution: Notification: \(notification.name)")
        if let obj: AnyObject = notification.object {
            //println("ImapCLIExecution: From: \(obj)")
        }
        if let usr = notification.userInfo {
            for key in usr.keys {
                //println("ImapCLIExecution: Subject: \(key)")
                if let message = usr[key] as? NSData {
                    if let str = NSString(data: message, encoding: NSUTF8StringEncoding) {
                        //println("ImapCLIExecution: Message: \(str)")
                    } else {
                        //println("ImapCLIExecution: Message: \(message)")
                    }
                }
            }
        }
        #endif
        
        // Aqcuire the data and messagetype
        // From stdin:
        if notification.name == STD_TOKEN {
            if let userInfo = notification.userInfo {
                for key in userInfo.keys {
                    if let data = userInfo[key] as? NSData, term = terminal {
                        if term.process(data) {
                            // TEMP ON
                            if let c = connection {
                                c.writeData(term.get + [13,10])
                            }
                            // TEMP OFF

                            term.ready()
                        }
                    }
                }
            }
        }
        // From server:
        if notification.name == TCP_TOKEN {
            if let userInfo = notification.userInfo {
                for key in userInfo.keys {
                    if let data = userInfo[key] as? NSData, term = terminal {
                        term.output(data)
                    }
                }
            }
            if let c = connection {
                if c.connected {
                    if let term = terminal {
                        term.ready()
                    }
                } else {
                    running = false
                }
            }
        }
    }
    

}
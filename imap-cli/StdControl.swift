//
//  StdControl.swift
//  imap-cli
//
//  Created by Are Digranes on 23.04.15.
//  Copyright (c) 2015 Are Digranes. All rights reserved.
//

// Class for interfacing with stdin, stdout, stderr

import Foundation

class StdControl {
    
    // Properties
    private let queue = dispatch_queue_create("com.jackalworks.imap-cli.StdControl", DISPATCH_QUEUE_SERIAL)
    private let ch_stdin: dispatch_queue_t
    private let ch_stdout: dispatch_queue_t
    private let ch_stderr: dispatch_queue_t
    
    private let MINWATER = 1
    private let MAXWATER = Int.max
    
    private var readData: [UInt8] = []
    
    // Notifications
    private let center = NSNotificationCenter.defaultCenter()
    private let notificationName: String
    let userInfo = "stdinData"
    
    // Methods
    init(notificationName: String) {

        // Add the notifier
        self.notificationName = notificationName
        
        // STDIN
        self.ch_stdin = dispatch_io_create(DISPATCH_IO_STREAM, STDIN_FILENO, queue) { (Int32 error) -> Void in
            
            #if DEBUG
            if error > 0 {
                println("StdControl: IN Create error \(error) \(String(CString: strerror(error), encoding: NSUTF8StringEncoding))")
            }
            println("StdControl: IN ended")
            #endif
            
        }
        dispatch_io_set_low_water(ch_stdin, MINWATER)
        dispatch_io_set_high_water(ch_stdin, MAXWATER)

        self.ch_stdout = dispatch_io_create(DISPATCH_IO_STREAM, STDOUT_FILENO, queue) { (Int32 error) -> Void in
            
            #if DEBUG
            if error > 0 {
                println("StdControl: OUT Create error \(error) \(String(CString: strerror(error), encoding: NSUTF8StringEncoding))")
            }
            println("StdControl: OUT ended")
            #endif
            
        }
        dispatch_io_set_low_water(ch_stdout, MINWATER)
        dispatch_io_set_high_water(ch_stdout, MAXWATER)

        self.ch_stderr = dispatch_io_create(DISPATCH_IO_STREAM, STDERR_FILENO, queue) { (Int32 error) -> Void in
            
            #if DEBUG
            if error > 0 {
                println("StdControl: ERR Create error \(error) \(String(CString: strerror(error), encoding: NSUTF8StringEncoding))")
            }
            println("StdControl: ERR ended")
            #endif
            
        }
        dispatch_io_set_low_water(ch_stderr, MINWATER)
        dispatch_io_set_high_water(ch_stderr, MAXWATER)

    }
    
    func start() {
        
        dispatch_io_read(ch_stdin, 0, MAXWATER, queue) { (Bool done, dispatch_data_t data, Int32 error) -> Void in
            
            if let d = data as? NSData {
                
                #if DEBUG
                if let s = NSString(data: d, encoding: NSUTF8StringEncoding) {
                    //println("StdControl: \(s)")
                } else {
                    println("StdControl: Received data not combatible with UTF-8, length \(d.length)")
                }
                #endif
                
                // Put data into buffer
                var bytes = [UInt8](count: d.length, repeatedValue: 0)
                d.getBytes(&bytes, length: d.length)
                self.readData += bytes
                
                // Notify
                dispatch_async(dispatch_get_main_queue(), {
                    self.center.postNotificationName(self.notificationName, object: self, userInfo: [self.userInfo: d])
                })
                
            }
            
            #if DEBUG
            if error > 0 {
                println("StdControl: IN Read error \(error) \(String(CString: strerror(error), encoding: NSUTF8StringEncoding))")
            }
            
            if done {
                //println("StdControl: Reading done")
            } else {
                //println("StdControl: Reading ongoing")
            }
            #endif

        }
        
    }
    
    func write(buffer: [UInt8], toError: Bool = false) -> Bool {
        
        let dispatch_data = dispatch_data_create(buffer, buffer.count, queue, nil)
        let channel = (toError ? ch_stderr : ch_stdout)
        
        dispatch_io_write(channel, 0, dispatch_data, queue) { (Bool done, dispatch_data_t data, Int32 error) -> Void in
            
            #if DEBUG
                if error > 0 {
                    if toError {
                        println("StdControl: ERR Write error \(error) \(String(CString: strerror(error), encoding: NSUTF8StringEncoding))")
                        
                    } else {
                        println("StdControl: OUT Write error \(error) \(String(CString: strerror(error), encoding: NSUTF8StringEncoding))")
                    }
                }
                
                if done {
                    //println("StdControl: Writing done")
                } else {
                    //println("StdControl: Writing ongoing")
                }

                if let d = data as? NSData {
                    if let s = NSString(data: d, encoding: NSUTF8StringEncoding) {
                        println("StdControl: Data while writing \(s)")
                    } else {
                        println("StdControl: Received data while writing not combatible with UTF-8, length \(d.length)")
                    }
                }
                
            #endif
            
        }
        
        return true
        
    }
    
}

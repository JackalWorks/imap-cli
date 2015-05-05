//
//  TCPConnection.swift
//  imap-cli
//
//  Created by Are Digranes on 20.04.15.
//  Copyright (c) 2015 Are Digranes. All rights reserved.
//

// Class for the connection and streams

import Foundation

let TCP_UNSAFE_ENCRYPTION = [kCFStreamSSLValidatesCertificateChain as String: kCFBooleanFalse, kCFStreamSSLPeerName as String: kCFNull]

class TCPConnection: NSObject, NSStreamDelegate {
    
    // Fundamentals
    private let queue = dispatch_queue_create("com.jackalworks.imap-cli.TCPConnection", DISPATCH_QUEUE_SERIAL)
    private var timer: NSTimer? = nil
    private let runloop = NSRunLoop.mainRunLoop()

    // Basic initialization
    private let hostname: String    // Server hostname
    private let port: Int           // Connection port
    private let encrypt: Bool       // Use TLS/SSL encryption
    private let unsecure: Bool      // Allow possibly compromised or self-signed certificates

    private let center = NSNotificationCenter.defaultCenter()
    private let notificationName: String
    let userInfo = "TCPData"

    init(hostname: String, port: Int, encrypt: Bool, unsecure: Bool, notificationName: String) {
        self.hostname = hostname
        self.port = port
        self.encrypt = encrypt
        self.unsecure = unsecure
        self.notificationName = notificationName
        super.init()
    }
    
    // Connection properties and methods
    private var inputStream: NSInputStream?   // The read-stream of the socket
    private var outputStream: NSOutputStream? // The write-stream
    
    func connect() {
        
        #if DEBUG
            // Create a timer
        timer = NSTimer(timeInterval: 1.0, target: self, selector: "heartBeat:", userInfo: nil, repeats: true)
        if let t = timer { runloop.addTimer(t, forMode: NSDefaultRunLoopMode) }
        #endif
        
        // Acquire our streams
        NSStream.getStreamsToHostWithName(hostname, port: port, inputStream: &inputStream, outputStream: &outputStream)

        // Setup and open the input stream
        if let input = inputStream {
            input.delegate = self
            input.scheduleInRunLoop(runloop, forMode: NSDefaultRunLoopMode)
            if encrypt {
                input.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
                if unsecure {
                    CFReadStreamSetProperty(input, kCFStreamPropertySSLSettings, TCP_UNSAFE_ENCRYPTION)
                }
            }
            dispatch_async(queue) {
                input.open()
            }
        }

        // Setup and open the output stream
        if let output = outputStream {
            output.delegate = self
            output.scheduleInRunLoop(runloop, forMode: NSDefaultRunLoopMode)
            if encrypt {
                output.setProperty(NSStreamSocketSecurityLevelNegotiatedSSL, forKey: NSStreamSocketSecurityLevelKey)
                if unsecure {
                    CFWriteStreamSetProperty(output, kCFStreamPropertySSLSettings, TCP_UNSAFE_ENCRYPTION)
                }
            }
            dispatch_async(queue) {
                output.open()
            }
        }

    }
    
    func disconnect() {
        
        // Shut down input stream
        if let input = inputStream {
            input.close()
            input.removeFromRunLoop(runloop, forMode: NSDefaultRunLoopMode) // Not necessary?
            input.delegate = nil
            inputStream = nil
        }
        
        // Shut down output stream
        if let output = outputStream {
            output.close()
            output.removeFromRunLoop(runloop, forMode: NSDefaultRunLoopMode) // Not necessary?
            output.delegate = nil
            outputStream = nil
        }
        
    }
    
    // Method called by the delegate
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        //println("TCPConnections: Stream callback: \(aStream.description)")
        
        switch eventCode {
            
        case NSStreamEvent.None:
            #if DEBUG
            println("TCPConnections: Event: None")
            #endif
            
        case NSStreamEvent.OpenCompleted:
            #if DEBUG
            //println("TCPConnections: Event: Open Completed")
            #endif
            
        case NSStreamEvent.HasBytesAvailable:
            #if DEBUG
            //println("TCPConnections: Event: Has Bytes Available")
            #endif
            if aStream === inputStream {
                readFromStream(aStream as! NSInputStream)
            }
            
        case NSStreamEvent.HasSpaceAvailable:
            #if DEBUG
            //println("TCPConnections: Event: Has Space Available")
            #endif
            
        case NSStreamEvent.ErrorOccurred:
            #if DEBUG
            println("TCPConnections: Event: Error Occured")
            #endif
            
        case NSStreamEvent.EndEncountered:
            #if DEBUG
            //println("TCPConnections: Event: End Encountered")
            #endif
            
        default:
            #if DEBUG
            println("TCPConnections: Event: Not possible")
            #endif
            
        }
    }
    
    // Reader method
    private func readFromStream(stream: NSInputStream) {

        // Buffers
        let readBufferSize = 16384
        let maxBuffers = 1024
        let initZero: UInt8 = 0
        
        dispatch_async(queue) {
            
            // The main buffer
            var mainBuffer: [UInt8] = []

            for _ in 0..<maxBuffers {
                
                // Check if we have bytes to read
                if stream.hasBytesAvailable == false { break }
                
                // Create a buffer
                var buffer = [UInt8](count: readBufferSize, repeatedValue: initZero)
                
                // Read from the stream
                let length = stream.read(&buffer, maxLength: readBufferSize)
                
                // Check if read
                if length > 0 {
                    // Copy buffer to main buffer
                    for i in 0..<length { mainBuffer.append(buffer[i]) }
                } else {
                    dispatch_sync(dispatch_get_main_queue()) {
                        #if DEBUG
                        //println("TCPConnections: Error or end of stream")
                        #endif
                        self.disconnect()
                    }
                }
                
                // Notify
                let d = NSData(bytes: mainBuffer, length: mainBuffer.count)
                dispatch_async(dispatch_get_main_queue(), {
                    self.center.postNotificationName(self.notificationName, object: self, userInfo: [self.userInfo: d])
                })
                
            }
            
            // TODO: For now we will kill the connection if we receive too much data
            if stream.hasBytesAvailable == true {
                #if DEBUG
                println("TCPConnections: Overflowed with data, bailing out")
                #endif
                dispatch_sync(dispatch_get_main_queue()) {
                    self.disconnect()
                    return
                }
            }

        }
        
    }
    
    // Method to write data
    func writeData(buffer: [UInt8]) -> Bool {
        var ret = false
        #if DEBUG
        //println("TCPConnections: Writing \(buffer)")
        #endif
        
        if let output = outputStream {
            if output.hasSpaceAvailable && (buffer.count > 0) {
                dispatch_sync(queue) {
                    let length = output.write(buffer, maxLength: buffer.count)
                    if length < 0 {
                        #if DEBUG
                        println("TCPConnections: Write error")
                        #endif
                        dispatch_sync(dispatch_get_main_queue()) {
                            self.disconnect()
                        }
                    } else {
                        ret = true
                    }
                }
            } else {
            #if DEBUG
                println("TCPConnections: Write not possible")
            #endif
            }
        }
        
        return ret
    }
    
    // Computed helper properties
    var connected: Bool {       // Returns true if streams are opened or active
        if let input = inputStream, output = outputStream {
            return (input.streamStatus == NSStreamStatus.Open || input.streamStatus == NSStreamStatus.Reading) && (output.streamStatus == NSStreamStatus.Open || output.streamStatus == NSStreamStatus.Writing)
        } else {
            return false
        }
    }
    
    #if DEBUG
    func heartBeat(timer: NSTimer) {
        dispatch_async(queue) {
            if self.connected {
                //println("TCPConnections: Connected")
            } else {
                //println("TCPConnections: Disconnected")
            }
        }
    }
    #endif
    
}
//
//  LogFile.swift
//  imap-cli
//
//  Created by Are Digranes on 18.04.15.
//  Copyright (c) 2015 Are Digranes. All rights reserved.
//

import Foundation

class LogFile {
    
    var handle: NSFileHandle? = nil
    
    init(path: String) {
        if NSFileManager.defaultManager().createFileAtPath(path, contents: nil, attributes: nil) {
            if let h = NSFileHandle(forWritingAtPath: path) {
                handle = h
                println("LogFile: Logfile open")
            } else {
                println("LogFile: Logfile not open")
            }
            
        }
    }
    
    deinit {
        if handle != nil {
            handle!.closeFile()
        }
    }

    func write(string: String) {
        if handle != nil {
            if let str = string.dataUsingEncoding(NSUTF8StringEncoding) {
                handle!.writeData(str)
            }
        }
    }
    
}
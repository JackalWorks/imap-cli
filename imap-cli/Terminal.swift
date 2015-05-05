//
//  Terminal.swift
//  imap-cli
//
//  Created by Are Digranes on 24.04.15.
//  Copyright (c) 2015 Are Digranes. All rights reserved.
//

// Terminal functions and control

import Foundation

class Terminal {
    
    // Hook to our stdout
    private let control: StdControl
    
    // Terminal attributes for recall
    private var recall: tcflag_t
    
    
    init(control: StdControl) {
        self.control = control

        // Take control of terminal
        // we are in a world of c
        // WARNING attributes to be used only here
        var attributes = UnsafeMutablePointer<termios>.alloc(1)
        tcgetattr(STDIN_FILENO, attributes)
        recall = attributes.memory.c_lflag
        attributes.memory.c_lflag -= tcflag_t(ICANON + ECHO) // Subtract
        tcsetattr(STDIN_FILENO, TCSANOW, attributes)
        attributes.dealloc(1)
        // WARNING END
        
    }
    
    deinit {
        
        // we get rid of the world of c
        // WARNING attributes to be used only here
        var attributes = UnsafeMutablePointer<termios>.alloc(1)
        tcgetattr(STDIN_FILENO, attributes)
        attributes.memory.c_lflag = recall
        tcsetattr(STDIN_FILENO, TCSANOW, attributes)
        attributes.dealloc(1)
        // WARNING END
        
    }
    
    private enum ascii: UInt8 {
        case NUL =  0
        case SOH =  1
        case STX =  2
        case ETX =  3
        case EOT =  4
        case ENQ =  5
        case ACK =  6
        case BEL =  7
        case BS  =  8
        case TAB =  9
        case LF  = 10
        case VT  = 11
        case FF  = 12
        case CR  = 13
        case SO  = 14
        case SI  = 15
        case DLE = 16
        case DC1 = 17
        case DC2 = 18
        case DC3 = 19
        case DC4 = 20
        case NAK = 21
        case SYN = 22
        case ETB = 23
        case CAN = 24
        case EM  = 25
        case SUB = 26
        case ESC = 27
        case FS  = 28
        case GS  = 29
        case RS  = 30
        case US  = 31
        case DEL = 127
    }
    
    private let ASCII_PRINTABLE = 32...126
    private let CHARSET_EXTENDED = 128...255
    
    private var buffer: [[UInt8]] = []
    private var index = 0
    private var cursor = 0 // TODO: Add cursor control support
    
    // Method to process input, returns true if line is complete - otherwise false
    func process(data: NSData) -> Bool {
        
        var ret = false
        
        // If command buffer is empty create one
        if buffer.isEmpty { buffer.append([]) }
        
        // If empty buffer print a line prefix
        if buffer[index].isEmpty { prefix_in() }

        // Get a byte array
        var bytes = [UInt8](count: data.length, repeatedValue: 0)
        data.getBytes(&bytes, length: data.length)

        // If data is empty return
        if bytes.count <= 0 { return false }

        // Check keys
        if let char = ascii(rawValue: bytes[0]) {
            switch char {
            case .DEL:      // Delete key
                if buffer[index].count > 0 {
                    buffer[index].removeLast()
                    delete()
                }
            case .ESC:      // Escape key
                // Support for arrow keys
                if bytes.count == 3 && bytes[1] == 91 {
                    switch bytes[2] {
                    case 65:    // Arrow up
                        index--
                        if index < 0 {index = 0 }
                    case 66:    // Arrow down
                        index++
                        if index == buffer.count { index-- }
                    case 67:    // TODO: Arrow right
                        break
                    case 68:    // TODO: Arrow left
                        break
                    default:
                        break
                    }
                    reprint()
                }
            case .CR,.LF:
                if buffer[index].count > 0 {
                    control.write([ascii.LF.rawValue])
                    index++
                    if index == buffer.count { buffer.append([]) }
                    ret = true
                }
            default:
                break
            }
        } else {
            for b in bytes {
                control.write([b])
                buffer[index].append(b)
            }
        }
        
        return ret

    }
    
    // Property to get the contents of buffer at previous index
    
    var get: [UInt8] {
        if index > 0 {
            return buffer[index - 1]
        } else {
            return []
        }
    }

    private let ANSI_FG_BLACK: [UInt8] = [27,91,51,48,109]
    private let ANSI_FG_RED: [UInt8] = [27,91,51,49,109]
    private let ANSI_FG_GREEN: [UInt8] = [27,91,51,50,109]
    private let ANSI_FG_YELLOW: [UInt8] = [27,91,51,51,109]
    private let ANSI_FG_BLUE: [UInt8] = [27,91,51,52,109]
    private let ANSI_FG_MAGENTA: [UInt8] = [27,91,51,53,109]
    private let ANSI_FG_CYAN: [UInt8] = [27,91,51,54,109]
    private let ANSI_FG_GRAY: [UInt8] = [27,91,51,55,109]
    
    private let ANSI_BG_BLACK: [UInt8] = [27,91,52,48,109]
    private let ANSI_BG_RED: [UInt8] = [27,91,52,49,109]
    private let ANSI_BG_GREEN: [UInt8] = [27,91,52,50,109]
    private let ANSI_BG_YELLOW: [UInt8] = [27,91,52,51,109]
    private let ANSI_BG_BLUE: [UInt8] = [27,91,52,52,109]
    private let ANSI_BG_MAGENTA: [UInt8] = [27,91,52,53,109]
    private let ANSI_BG_CYAN: [UInt8] = [27,91,52,54,109]
    private let ANSI_BG_GRAY: [UInt8] = [27,91,52,55,109]
    
    private let ANSI_RESET: [UInt8] = [27,91,48,109]
    
    private let VT100_CLEAR_LINE: [UInt8] = [13,27,91,50,75]
    
    private let VT100_DELETE: [UInt8] = [27,91,68,27,91,75]
    
    private let LINE_FEED: [UInt8] = [10]
    
    private let UTF8_PREFIX_IN: [UInt8] = [32,226,134,146,32]
    private let UTF8_PREFIX_OUT: [UInt8] = [32,226,134,144,32]
    
    private func prefix_in() {
        control.write(VT100_CLEAR_LINE + UTF8_PREFIX_IN)
    }

    private func prefix_out() {
        control.write(VT100_CLEAR_LINE + UTF8_PREFIX_OUT)
    }

    private func reprint() {
        prefix_in()
        control.write(buffer[index])
    }
    
    private func delete() {
        control.write(VT100_DELETE)
    }
    
    // Method to use when ready to request data
    func ready() {
        prefix_in()
    }
    
    func output(data: NSData) {
        
        // Get a byte array
        var bytes = [UInt8](count: data.length, repeatedValue: 0)
        data.getBytes(&bytes, length: data.length)
        
        prefix_out()
        control.write(bytes + LINE_FEED)

    }
    
    func echo(data: NSData) {
        var bytes = [UInt8](count: data.length, repeatedValue: 0)
        data.getBytes(&bytes, length: data.length)
        println(bytes)
        control.write(bytes)
    }
    
}
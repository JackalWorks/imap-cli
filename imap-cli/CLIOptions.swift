//
//  CLIOptions.swift
//  imap-cli
//
//  Created by Are Digranes on 16.04.15.
//  Copyright (c) 2015 Are Digranes. All rights reserved.
//

// Processing single character options from the CLI

import Foundation

class CLIOptions {
    
    // Define Boolean string types
    private let BOOL_STRING_FALSE: String = "False"
    private let BOOL_STRING_TRUE: String = "True"
    
    // Define value used for options needing an argument
    private let VALUE_OPTION_CHAR: Character = ":"
    
    // A value used to prefix option character
    private let OPTION_PREFIX: Character = "-"
    
    // A Dictionary containing the options
    private var Options: [Character: String] = [:]
    private var Arguments: [String] = []
    
    // The self optionsstring
    private var optstring: String = ""
    
    // Will be set to true if user entered unknown option
    var UserEnteredUnknownOption: Bool = false
    
    // Getters
    func valueOfOption(option: Character) -> Bool {
        if Options[option] != nil {
            return true
        } else {
            return false
        }
    }
    
    func valueOfOption(option: Character) -> String? {
        return Options[option]
    }

    func valueOfOption(option: Character) -> Int? {
        if let str = Options[option] {
            return str.toInt()
        }
        return nil
    }
    
    func valueOfArgument(argument: Int) -> String? {
        if argument < Arguments.count && argument > 0 {
            return Arguments[argument]
        }
        return nil
    }

    func valueOfArgument(argument: Int) -> Int? {
        if argument < Arguments.count && argument > 0 {
            return Arguments[argument].toInt()
        }
        return nil
    }

    func invocation() -> String? {
        if Arguments.count > 0 {
            return Arguments[0]
        }
        return nil
    }
    
    // Get a option character
    private func optchar(arg: String) -> Character? {
        if count(arg) > 1 && arg[arg.startIndex] == OPTION_PREFIX {
            return arg[advance(arg.startIndex, 1)]
        }
        return nil
    }
    
    // Check if the option character is in optstring
    private func check(optc: Character) -> Bool {
        for i in self.optstring {
            if i == optc { return true }
        }
        return false
    }
    
    // Check if the option character is in optstring and require an option value
    private func checkopts(optc: Character) -> Bool {
        var previous: Character = " "
        for i in self.optstring {
            if previous == optc && i == VALUE_OPTION_CHAR { return true }
            previous = i
        }
        return false
    }
    
    // Init method which takes a string in simple "optstring" format
    init(optstring: String) {
        
        self.optstring = optstring
        
        var previous: String = ""
        for i in Process.arguments {
            if let pre = optchar(previous) {
                if checkopts(pre) {
                    Options[pre] = i
                } 
            }
            if let opt = optchar(i) {
                if check(opt) {
                    Options[opt] = BOOL_STRING_TRUE
                } else {
                    UserEnteredUnknownOption = true
                }
            } else {
                Arguments.append(i)
            }
            previous = i
        }
        
    }
    
}
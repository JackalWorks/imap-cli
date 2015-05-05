//
//  main.swift
//  imap-cli
//
//  Created by Are Digranes on 16.04.15.
//  Copyright (c) 2015 Are Digranes. All rights reserved.
//

// CLI-client for the IMAP protocol

// Version: 1.0α1 - 16.04.15

// LICENSE To be decided


import Foundation

// MARK: Basic setup

let DEFAULT_IMAP_TCP_PORT = 143
let DEFAULT_IMAP_TCP_TLS_PORT = 993

let execution = ImapCLIExecution()

execution.start()


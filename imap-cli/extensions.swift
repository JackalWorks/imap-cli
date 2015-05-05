//
//  extensions.swift
//  imap-cli
//
//  Created by Are Digranes on 18.04.15.
//  Copyright (c) 2015 Are Digranes. All rights reserved.
//

import Foundation

// Extension to string to be able to handle multi-lines
extension String {
    init(_ lines:String...){
        self = ""
        for i in lines {
            self += i
        }
    }
}

/* TODO Don't use, safer but still isssues */
/*
public class SafeArray<T> {
    private var array: [T] = []
    private let queue = dispatch_queue_create("com.jackalworks.SafeArray", DISPATCH_QUEUE_CONCURRENT)

    var count: Int {
        return array.count
    }
    
    func append(newElement: T) {
        dispatch_barrier_async(self.queue) {
            self.array.append(newElement)
        }
    }
    
    subscript(index: Int) -> T {
        set {
            dispatch_barrier_async(self.queue) {
                self.array[index] = newValue
            }
        }
        get {
            var element: T!
            
            dispatch_sync(self.queue) {
                element = self.array[index]
            }
            
            return element
        }
    }
}
*/


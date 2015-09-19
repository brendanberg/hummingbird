//
//  main.swift
//  Hummingbird
//
//  Created by Brendan Berg on 6/3/14.
//  Copyright (c) 2014 NegativeZero. All rights reserved.
//

// import Darwin
import Foundation

println("Hello")

let conn = Socket().connect(8000, address: "127.0.0.1").listen(limit:128).accept() { connection, address in
    println("Accepted a connection from port \(address.addressString)")    
    return connection
}.read() { connection, inStr in
    let arr = inStr.componentsSeparatedByString("\n")
    let response = (arr[0].uppercaseString + "\n")
    return connection.write(response)
}.close()

switch conn {
case .Error(let str):
    println("ERROR: \(str)")
case .Descriptor:
    println("Goodbye")
}

// kevent or kqueue

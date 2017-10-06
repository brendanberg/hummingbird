//
//  main.swift
//  Hummingbird
//
//  Created by Brendan Berg on 6/3/14.
//  Copyright (c) 2014 NegativeZero. All rights reserved.
//

// import Darwin
import Foundation

print("Hello")

let conn = Socket().connect(port: 8000, address: "127.0.0.1").listen(limit:128).accept() { connection, address in
    print("Accepted a connection from port \(address.addressString)")
    return connection
}.read() { connection, inStr in
    let arr = inStr.components(separatedBy: "\n")
    let response = (arr[0].uppercased() + "\n")
    return connection.write(response: response)
}.close()

switch conn {
case .Error(let str):
    print("ERROR: \(str)")
case .Descriptor:
    print("Goodbye")
}

// kevent or kqueue

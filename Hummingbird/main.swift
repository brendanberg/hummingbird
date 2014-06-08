//
//  main.swift
//  Hummingbird
//
//  Created by Brendan Berg on 6/3/14.
//  Copyright (c) 2014 NegativeZero. All rights reserved.
//

import Darwin

println("Hello")

var buffer = new CChar[256]
var bytesRead: Int?

var conn = Socket().connect(8000, address: "127.0.0.1").listen(limit:128).accept() { connection, address in
    let port = address.sin_port
    let addr = address.addressString
    
    println("client port \(port)")
    println("client addr \(addr)")
    
    return connection
}.read() { connection, inStr in
    var arr = inStr.componentsSeparatedByString("\n")
    var response = (arr[0].uppercaseString + "\n")
    return connection.write(response)
}.close()

// Use this to quickly zero out memory if we reuse the same buffer per read
// memset(&array, CInt(sizeof(CChar)) * CInt(array.count), 0)
//
// This is less Swiftish but might be faster...
//
// var buff = calloc(UInt(sizeof(CChar)), 256)
// var n = read(conn, buff, 255)
// var charBuf = UnsafePointer<CChar>(buff)
// charBuf[n] = 0
// var s: String = String.fromCString(charBuf)
// println(s)

switch conn {
case .Error(let str):
    println("There was an error.")
    println("ERROR: \(str)")
case .Socket:
    println("Goodbye")
}

// kevent or kqueue

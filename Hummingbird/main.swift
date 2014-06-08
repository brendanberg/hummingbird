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

var sock = Socket().connect(8000, address: "127.0.0.1").listen(limit:128).accept() { connection in
    switch connection {
    case .Socket(var sock2, var address):
        let port = address.sin_port
        let addr = address.addressString
        
        println("client port \(port)")
        println("client addr \(addr)")
        
        let c = connection.read(&buffer, bytesRead: &bytesRead)
        
        switch c {
        case .Socket(let s, let a):
            buffer[bytesRead!] = 0
            var request = buffer.withUnsafePointerToElements {
                String.fromCString($0)
            }
            var arr = request.componentsSeparatedByString("\n")
            var response: UInt8[] = UInt8[](("\n" + arr[0].uppercaseString).utf8)
            var bytesWritten: UInt?
            c.write(response.reverse(), bytesWritten: &bytesWritten)

        case .Error:
            return ()
        }
    case .Error:
        return ()
    }
}

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

switch sock {
case .Socket:
    switch sock.close() {
    case .Error(let str):
        println("Unable to close connection")
        println("ERROR: \(str)")
    default:
        println("Goodbye")
    }
case .Error(let str):
    println("Finally.")
    println("ERROR: \(str)")
}

// kevent or kqueue

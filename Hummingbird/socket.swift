//
//  socket.swift
//  Hummingbird
//
//  Created by Brendan Berg on 6/4/14.
//  Copyright (c) 2014 NegativeZero. All rights reserved.
//

import Darwin
import Foundation


/**
  Representation of a connected socket or error.
  Either a Descriptor with an associated value for the POSIX
  socket file descriptor or an Error with a string describing
  the error.
 */
enum Connection {
    case Descriptor(CInt)
    case Error(String)
}

/**
  Representation of a socket or error.
  Either a Descriptor with an associated value for the POSIX
  socket file descriptor or an Error with a string describing
  the error.
 */
enum Socket {
    case Descriptor(CInt)
    case Error(String)
    
    /**
    Creates a new, unbound POSIX socket and encapsulates the file descriptor.
    */
    init() {
        let newSocket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        
        if newSocket < 0 {
            self = .Error(String.fromCString(strerror(errno)) ?? "Unknown error")
        } else {
            self = .Descriptor(newSocket)
        }
    }
    
    /**
    Binds a socket to the specified port, listening on the interface specified by `address`.
    */
    func connect(port: CUnsignedShort, address: String = "127.0.0.1", fn: Socket -> Socket = { $0 }) -> Socket {
        switch self {
        case let .Descriptor(sock):
            let addr = inet_addr(address)
            
            if addr == __uint32_t.max {
                return .Error("unable to parse address")
            }
            
            var server_addr = sockaddr()
            server_addr.sa_family = sa_family_t(AF_INET)
            server_addr.sin_port = port
            server_addr.sin_addr = addr
            
            let err = bind(sock, &server_addr, socklen_t(sizeof(sockaddr)))
            
            if err != 0 {
                return .Error(String.fromCString(strerror(errno)) ?? "Unknown error")
            }
            
            return fn(self)
        case .Error:
            return self
        }
    }

    /**
     Listens for connections on the socket, pulling from a queue with
     a maximum length specified by `limit`. Per the man page, `limit`
     is silently limited to 128.
     */
    func listen(limit: CInt = 128, fn: Socket -> Socket = { $0 }) -> Socket {
        switch self {
        case let .Descriptor(sock):
            let success = Darwin.listen(sock, limit)
            
            if success != 0 {
                return .Error(String.fromCString(strerror(errno)) ?? "Unknown error")
            } else {
                return self
            }
        case .Error:
            return self
        }
    }
    
    /**
     Accepts a connection on a socket. Turns a Socket into a Connection.
     */
    func accept(fn: (Connection, sockaddr) -> Connection = { c, _ in c }) -> Connection {
        switch self {
        case .Descriptor(let sock):
            var address = sockaddr()
            var length = socklen_t(sizeof(sockaddr))
            let newSocket = Darwin.accept(sock, &address, &length)
            
            if newSocket < 0 {
                return .Error(String.fromCString(strerror(errno)) ?? "Unknown error")
            } else {
                return fn(.Descriptor(newSocket), address)
            }
        case .Error(let str):
            return .Error(str) // self
        }
    }
    
    /**
     Closes a connection.
     */
    func close(fn: Socket -> Socket = { $0 }) -> Socket {
        switch self {
        case let .Descriptor(sock):
            if Darwin.close(sock) != 0 {
                return .Error(String.fromCString(strerror(errno)) ?? "Unknown error")
            } else {
                return fn(self)
            }
        case .Error:
            return self
        }
    }
}



extension Socket: BooleanType {
    /**
     Gets the logical value of the socket.
    
     Returns `true` if the Socket represents a valid descriptor
     and `false` if the Socket represents an error.
     */
    var boolValue: Bool {
        switch self {
        case .Descriptor:
            return true
        case .Error:
            return false
        }

    }
}



// Connection Extensions
// ---------------------
// Methods on the Connection enum are here because of the forward declaration
// required for the Socket implementation.

extension Connection {
    /**
     Reads data from the connection. The data read from the connection is passed as
     the second parameter to the success function.
    
     The `success` parameter is a function to be called upon successful reading.
    
     Returns a `Connection` monad
     */
    func read(fn: (Connection, String) -> Connection = { c, _ in c }) -> Connection {
        
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
        
        switch self {
        case .Descriptor(let sock):
            var buffer = [CChar](count: 1024, repeatedValue: 0)
            //[CChar] = String().cStringUsingEncoding("UTF8")
            let bytesRead = Darwin.read(sock, &buffer, 1023)
            
            if bytesRead < 0 {
                return .Error(String.fromCString(strerror(errno)) ?? "Unknown error")
            } else {
                buffer[bytesRead] = 0
                let str = buffer.withUnsafeBufferPointer() { String.fromCString($0.baseAddress)! }
                return fn(self, str)
            }
        case .Error:
            return self
        }
    }
    
    /**
     Writes the contents of a string to the connection.
     
     The `response` parameter is the string to be written; `success`
     is the function to be called upon successful writing.
    
     Returns a `Connection` monad.
     */
    func write(response: String, fn: Connection -> Connection = { $0 }) -> Connection {
        switch self {
        case .Descriptor(let sock):
            let bytesWritten = Darwin.write(sock, response, response.lengthOfBytesUsingEncoding(4)) // NSUTF8StringEncoding = 4
            
            if bytesWritten < 0 {
                return .Error(String.fromCString(strerror(errno)) ?? "Unknown error")
            } else {
                return fn(self)
            }
        case .Error:
            return self
        }
    }
    
    /**
     Closes the connection.
     
     The `success` parameter is a function to be called upon successful closure of the connection.
    
     Returns A `Connection` monad.
     */
    func close(fn: Connection -> Connection = { $0 }) -> Connection {
        switch self {
        case let .Descriptor(sock):
            if Darwin.close(sock) != 0 {
                return Connection.Error(String.fromCString(strerror(errno))!)
            } else {
                return fn(self)
            }
        case .Error:
            return self
        }
    }
}



extension Connection : BooleanType {
    /**
     Gets the logical value of the connection.
    
     Returns `true` if the Connection represents a valid descriptor,
     and `false` if the Connection represents an error
     */
    var boolValue : Bool {
        switch self {
        case .Descriptor:
            return true
        case .Error:
            return false
        }
    }
}



// C sockaddr struct Extension
// ---------------------------
// The Swift type checker doesn't allow us to use sockaddr and sockaddr_in
// interchangably, so the following extension destructures port and address
// types and sets the appropriate bytes in sa_data to use with the socket
// system calls.

extension sockaddr {
    init () {
        sa_len = 0
        sa_family = 0
        sa_data = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    var sin_port: in_port_t {
    /*! Gets the socket's port number by restructuring bytes in the sa_data field.
     * \returns The socket's port number as a 16-bit unsigned integer
     */
    get {
        // TODO: Make sure this is done in a machine-architecture indepenent way.
        return (UInt16(sa_data.1) << 8) + UInt16(sa_data.0)
    }
    /*! Sets the socket's port number by destructuring the first two bytes of the
     *  sa_data field.
     * \param newValue The port number as a 16-bit unsigned integer
     */
    set {
        // TODO: Make sure this is done in a machine-architecture indepenent way.
        sa_data.0 = CChar((newValue & 0xFF00) >> 8)
        sa_data.1 = CChar((newValue & 0x00FF) >> 0)
    }

    }
    
    var sin_addr: in_addr_t {
    get {
        return (
            // Restructures bytes 3 through 6 of sa_data into a 32-bit unsigned
            // integer IPv4 address
            // TODO: This should probably go through ntohs() first.
            in_addr_t(sa_data.2) >> 00 + in_addr_t(sa_data.3) >> 08 +
            in_addr_t(sa_data.4) >> 16 + in_addr_t(sa_data.5) >> 24
        )
    }
    set {
        // Destructures a 32-bit IPv4 address to set as bytes 3 through 6 of sa_data
        // TODO: This should probably go through htons() first.
        sa_data.2 = CChar((newValue & 0x000000FF) >> 00)
        sa_data.3 = CChar((newValue & 0x0000FF00) >> 08)
        sa_data.4 = CChar((newValue & 0x00FF0000) >> 16)
        sa_data.5 = CChar((newValue & 0xFF000000) >> 24)
    }
    }
    
    /**
    The human-readable, dotted quad string representation of the socket's IPv4 address.
    */
    var addressString: String {
        let data = self.sa_data
        return "\(data.2).\(data.3).\(data.4).\(data.5)"
    }
}

//
//  socket.swift
//  Hummingbird
//
//  Created by Brendan Berg on 6/4/14.
//  Copyright (c) 2014 NegativeZero. All rights reserved.
//

import Darwin

enum Connection {
    case Descriptor(CInt)
    case Error(String)
}

enum Socket {
    case Descriptor(CInt)
    case Error(String)
    
    init() {
        let newSocket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        
        if newSocket < 0 {
            self = .Error(String.fromCString(strerror(errno)))
        } else {
            self = .Descriptor(newSocket)
        }
    }
    
    func connect(port: CUnsignedShort, address: CString = "127.0.0.1", fn: Socket -> Socket = { $0 }) -> Socket {
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
                return .Error(String.fromCString(strerror(errno)))
            }
            
            return fn(self)
        case .Error:
            return self
        }
    }

    func listen(limit: CInt = 128, fn: Socket -> Socket = { $0 }) -> Socket {
        // Assert a willingness to listen to a socket with a maximum
        // length for the pending connection queue. Per the man page,
        // `limit` is silently limited to 128.
        
        switch self {
        case let .Descriptor(sock):
            let success = Darwin.listen(sock, limit)
            
            if success != 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                return self
            }
        case .Error:
            return self
        }
    }
    
    func accept(fn: (Connection, sockaddr) -> Connection = { c, _ in c }) -> Connection {
        switch self {
        case .Descriptor(let sock):
            var address = sockaddr()
            var length = socklen_t(sizeof(sockaddr))
            let newSocket = Darwin.accept(sock, &address, &length)
            
            if newSocket < 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                return fn(.Descriptor(newSocket), address)
            }
        case .Error(let str):
            return .Error(str) // self
        }
    }
    
    func close(fn: Socket -> Socket = { $0 }) -> Socket {
        switch self {
        case let .Descriptor(sock):
            if Darwin.close(sock) != 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                return self
            }
        case .Error:
            return self
        }
    }
}



extension Socket: LogicValue {
    func getLogicValue() -> Bool {
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
            var buffer = new CChar[256]
            let bytesRead = Darwin.read(sock, &buffer, UInt(buffer.count))
            
            if bytesRead < 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                buffer[bytesRead] = 0
                return fn(self, buffer.withUnsafePointerToElements { String.fromCString($0) })
            }
        case .Error:
            return self
        }
    }
    
    func write(response: String, fn: Connection -> Connection = { $0 }) -> Connection {
        switch self {
        case .Descriptor(let sock):
            let bytesOut = UInt8[](response.utf8)
            let bytesWritten = Darwin.write(sock, bytesOut, UInt(bytesOut.count))
            
            if bytesWritten < 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                return fn(self)
            }
        case .Error:
            return self
        }
    }
    
    func close(fn: Connection -> Connection = { $0 }) -> Connection {
        switch self {
        case let .Descriptor(sock):
            if Darwin.close(sock) != 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                return fn(self)
            }
        case .Error:
            return self
        }
    }
}



extension Connection: LogicValue {
    func getLogicValue() -> Bool {
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
    get {
        return (UInt16(sa_data.1.asUnsigned()) << 8) + UInt16(sa_data.0.asUnsigned())
    }
    set {
        sa_data.0 = CChar((newValue & 0xFF00) >> 8)
        sa_data.1 = CChar((newValue & 0x00FF) >> 0)
    }

    }
    
    var sin_addr: in_addr_t {
    get {
        return (
            in_addr_t(sa_data.2) >> 00 + in_addr_t(sa_data.3) >> 08 +
            in_addr_t(sa_data.4) >> 16 + in_addr_t(sa_data.5) >> 24
        )
    }
    set {
        sa_data.2 = CChar((newValue & 0x000000FF) >> 00)
        sa_data.3 = CChar((newValue & 0x0000FF00) >> 08)
        sa_data.4 = CChar((newValue & 0x00FF0000) >> 16)
        sa_data.5 = CChar((newValue & 0xFF000000) >> 24)
    }
    }
    
    var addressString: String {
        let data = self.sa_data
        return "\(data.2).\(data.3).\(data.4).\(data.5)"
    }
}

//
//  socket.swift
//  Hummingbird
//
//  Created by Brendan Berg on 6/4/14.
//  Copyright (c) 2014 NegativeZero. All rights reserved.
//

import Darwin

enum Connection {
    case Socket(CInt, sockaddr)
    case Error(String)
    
    func read(inout buffer: CChar[], inout bytesRead: Int?, fn: Connection -> () = {_ in ()}) -> Connection {
        switch self {
        case .Socket(let sock, let addr):
            bytesRead = Darwin.read(sock, &buffer, UInt(buffer.count))
            
            if bytesRead < 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                buffer[bytesRead!] = 0
                var request = buffer.withUnsafePointerToElements {
                    String.fromCString($0)
                }
                return self
            }
        case .Error:
            return self
        }
    }
    
    func write(response: UInt8[], inout bytesWritten: UInt?, fn: Connection -> () = {_ in ()}) -> Connection {
        switch self {
        case .Socket(let sock, let addr):
            let bytesWritten = Darwin.write(sock, response, UInt(response.count))
            
            if bytesWritten < 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                return self
            }
        case .Error:
            return self
        }
    }
    
    func close(fn: Connection -> () = {_ in ()}) -> Connection {
        switch self {
        case let .Socket(sock, _):
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
    
    func connect(port: CUnsignedShort, address: CString = "127.0.0.1", fn: Socket -> () = {_ in ()}) -> Socket {
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
            
            fn(self)
            return self
        case .Error:
            return self
        }
    }

    func listen(limit: CInt = 128, fn: Socket -> () = {_ in ()}) -> Socket {
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
    
    func accept(fn: Connection -> () = {_ in ()}) -> Connection {
        switch self {
        case .Descriptor(let sock):
            var address = sockaddr()
            var length = socklen_t(sizeof(sockaddr))
            let newSocket = Darwin.accept(sock, &address, &length)
            
            if newSocket < 0 {
                return .Error(String.fromCString(strerror(errno)))
            } else {
                let socket: Connection = .Socket(newSocket, address)
                fn(socket)
                return socket
            }
        case .Error(let str):
            return .Error(str) // self
        }
    }
    
    func close(fn: Socket -> () = {_ in ()}) -> Socket {
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

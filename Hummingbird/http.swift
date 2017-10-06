//
//  http.swift
//  Hummingbird
//
//  Created by Brendan Berg on 6/4/14.
//  Copyright (c) 2014 NegativeZero. All rights reserved.
//
import Foundation

protocol RequestHandler {
    func get() -> HTTPResponse
    func post() -> HTTPResponse
}

class HTTPRequest {
    var method: String
    var uri: String
    var version: String
    var headers: HTTPHeaders
    var body: [UInt8]?
    
    
    init(method: String, uri: String, version: String = "1.1") {
        self.method = method
        self.uri = uri
        self.version = version
        self.headers = HTTPHeaders()
        
    }
}

class HTTPResponse {
    
}

class HTTPHeaders {
    var headers: [(String, String)]
    
    func setHeader(name: String, value: String) {
        /*
            Sets a value for a header, replacing if it already exits
        */
    }
    
    func getHeader(name: String) -> String? {
        /*
            Returns the value for the header with the specified name if it exists.
        */
        for (key, val) in self.headers {
            if key == name {
                return val
            }
        }
        return nil
    }
    
    init() {
        self.headers = Array()
    }
}

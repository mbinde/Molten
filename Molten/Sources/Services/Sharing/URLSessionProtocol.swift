//
//  URLSessionProtocol.swift
//  Molten
//
//  Protocol for URLSession to enable dependency injection and testing
//

import Foundation

/// Protocol for URLSession to enable mocking
protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func download(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (URL, URLResponse)
}

/// Extend URLSession to conform to protocol
extension URLSession: URLSessionProtocol {}

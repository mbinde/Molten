//
//  Data+Gzip.swift
//  Molten
//
//  Created by Assistant on 11/8/25.
//  Zlib compression/decompression utilities
//  Note: Despite the filename, this uses zlib format (RFC 1950), not gzip (RFC 1952)
//

import Foundation
import Compression

extension Data {

    /// Decompress zlib-compressed data
    nonisolated func gunzipped() throws -> Data {
        guard !self.isEmpty else {
            return self
        }

        var decompressed = Data()

        let bufferSize = 512
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }

        var status = compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard status == COMPRESSION_STATUS_OK else {
            throw CompressionError.streamInitializationFailed
        }

        defer {
            compression_stream_destroy(stream)
        }

        try self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
            guard let inputBaseAddress = inputPointer.baseAddress else {
                throw CompressionError.invalidInput
            }

            stream.pointee.src_ptr = inputBaseAddress.assumingMemoryBound(to: UInt8.self)
            stream.pointee.src_size = self.count
            stream.pointee.dst_ptr = buffer
            stream.pointee.dst_size = bufferSize

            while true {
                let processStatus = compression_stream_process(stream, 0)

                switch processStatus {
                case COMPRESSION_STATUS_OK:
                    // More data to decompress
                    let count = bufferSize - stream.pointee.dst_size
                    decompressed.append(buffer, count: count)

                    stream.pointee.dst_ptr = buffer
                    stream.pointee.dst_size = bufferSize

                case COMPRESSION_STATUS_END:
                    // Decompression complete
                    let count = bufferSize - stream.pointee.dst_size
                    decompressed.append(buffer, count: count)
                    return

                case COMPRESSION_STATUS_ERROR:
                    throw CompressionError.decompressionFailed

                default:
                    throw CompressionError.unknownError
                }
            }
        }

        return decompressed
    }

    /// Check if data has zlib or gzip compression headers
    /// Note: This detects zlib (0x78) or gzip (0x1f 0x8b) wrapped formats.
    /// The gzipped() function produces raw deflate (no wrapper), so this will
    /// return false for data compressed by gzipped(). Use this to detect
    /// externally-compressed data (e.g., from HTTP responses or files).
    nonisolated var isGzipped: Bool {
        guard self.count >= 2 else { return false }

        // Check for zlib header (RFC 1950): 0x78 0x??
        if self[0] == 0x78 && (self[1] & 0x20) == 0 {
            return true
        }

        // Check for gzip header (RFC 1952): 0x1f 0x8b
        if self[0] == 0x1f && self[1] == 0x8b {
            return true
        }

        return false
    }

    /// Compress data using zlib format
    nonisolated func gzipped() throws -> Data {
        guard !self.isEmpty else {
            return self
        }

        var compressed = Data()

        let bufferSize = 512
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }

        var status = compression_stream_init(stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_ZLIB)
        guard status == COMPRESSION_STATUS_OK else {
            throw CompressionError.streamInitializationFailed
        }

        defer {
            compression_stream_destroy(stream)
        }

        try self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
            guard let inputBaseAddress = inputPointer.baseAddress else {
                throw CompressionError.invalidInput
            }

            stream.pointee.src_ptr = inputBaseAddress.assumingMemoryBound(to: UInt8.self)
            stream.pointee.src_size = self.count
            stream.pointee.dst_ptr = buffer
            stream.pointee.dst_size = bufferSize

            while true {
                let processStatus = compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

                switch processStatus {
                case COMPRESSION_STATUS_OK:
                    // More data to compress
                    let count = bufferSize - stream.pointee.dst_size
                    compressed.append(buffer, count: count)

                    stream.pointee.dst_ptr = buffer
                    stream.pointee.dst_size = bufferSize

                case COMPRESSION_STATUS_END:
                    // Compression complete
                    let count = bufferSize - stream.pointee.dst_size
                    compressed.append(buffer, count: count)
                    return

                case COMPRESSION_STATUS_ERROR:
                    throw CompressionError.compressionFailed

                default:
                    throw CompressionError.unknownError
                }
            }
        }

        return compressed
    }
}

enum CompressionError: LocalizedError {
    case invalidInput
    case streamInitializationFailed
    case decompressionFailed
    case compressionFailed
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid input data for compression/decompression"
        case .streamInitializationFailed:
            return "Failed to initialize compression stream"
        case .decompressionFailed:
            return "Decompression failed"
        case .compressionFailed:
            return "Compression failed"
        case .unknownError:
            return "Unknown compression error"
        }
    }
}

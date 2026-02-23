//
//  Data+Gzip.swift
//  Molten
//
//  Created by Assistant on 11/8/25.
//  Gzip and zlib compression/decompression utilities
//

import Foundation
import Compression

extension Data {

    /// Decompress gzip or zlib compressed data
    /// Handles both gzip format (RFC 1952) and zlib format (RFC 1950)
    nonisolated func gunzipped() throws -> Data {
        guard !self.isEmpty else {
            return self
        }

        // Check if this is gzip format (1f 8b header)
        if self.count >= 2 && self[0] == 0x1f && self[1] == 0x8b {
            return try decompressGzip()
        }

        // Otherwise try zlib decompression
        return try decompressZlib()
    }

    /// Decompress gzip format (RFC 1952) data
    private nonisolated func decompressGzip() throws -> Data {
        // Gzip format:
        // - 10+ byte header (magic, method, flags, mtime, xfl, os, optional fields)
        // - Compressed data (raw DEFLATE)
        // - 8 byte trailer (CRC32, original size)

        guard self.count >= 18 else {  // Minimum: 10 header + 0 data + 8 trailer
            throw CompressionError.invalidInput
        }

        // Verify magic number
        guard self[0] == 0x1f && self[1] == 0x8b else {
            throw CompressionError.invalidInput
        }

        // Compression method must be 8 (deflate)
        guard self[2] == 8 else {
            throw CompressionError.invalidInput
        }

        let flags = self[3]
        var offset = 10  // Skip fixed header

        // Skip optional extra field (FEXTRA)
        if flags & 0x04 != 0 {
            guard self.count > offset + 2 else { throw CompressionError.invalidInput }
            let extraLen = Int(self[offset]) | (Int(self[offset + 1]) << 8)
            offset += 2 + extraLen
        }

        // Skip optional filename (FNAME) - null terminated
        if flags & 0x08 != 0 {
            while offset < self.count && self[offset] != 0 {
                offset += 1
            }
            offset += 1  // Skip null terminator
        }

        // Skip optional comment (FCOMMENT) - null terminated
        if flags & 0x10 != 0 {
            while offset < self.count && self[offset] != 0 {
                offset += 1
            }
            offset += 1  // Skip null terminator
        }

        // Skip optional header CRC (FHCRC)
        if flags & 0x02 != 0 {
            offset += 2
        }

        guard offset < self.count - 8 else {
            throw CompressionError.invalidInput
        }

        // Extract compressed data (everything except 8-byte trailer)
        let compressedData = self.subdata(in: offset..<(self.count - 8))

        // Decompress using raw DEFLATE
        return try compressedData.decompressRawDeflate()
    }

    /// Decompress raw DEFLATE data (no header/trailer)
    private nonisolated func decompressRawDeflate() throws -> Data {
        var decompressed = Data()

        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }

        // Use COMPRESSION_ZLIB which can handle raw deflate data
        let status = compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
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
                // Use COMPRESSION_STREAM_FINALIZE to signal end of input
                let flags: Int32 = stream.pointee.src_size == 0 ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                let processStatus = compression_stream_process(stream, flags)

                switch processStatus {
                case COMPRESSION_STATUS_OK:
                    let count = bufferSize - stream.pointee.dst_size
                    if count > 0 {
                        decompressed.append(buffer, count: count)
                    }
                    stream.pointee.dst_ptr = buffer
                    stream.pointee.dst_size = bufferSize

                    // If no progress and no more input, we're stuck
                    if count == 0 && stream.pointee.src_size == 0 {
                        return
                    }

                case COMPRESSION_STATUS_END:
                    let count = bufferSize - stream.pointee.dst_size
                    if count > 0 {
                        decompressed.append(buffer, count: count)
                    }
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

    /// Decompress zlib format (RFC 1950) data
    private nonisolated func decompressZlib() throws -> Data {
        var decompressed = Data()

        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }

        let status = compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
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
                    let count = bufferSize - stream.pointee.dst_size
                    decompressed.append(buffer, count: count)
                    stream.pointee.dst_ptr = buffer
                    stream.pointee.dst_size = bufferSize

                case COMPRESSION_STATUS_END:
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

        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }

        let status = compression_stream_init(stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_ZLIB)
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

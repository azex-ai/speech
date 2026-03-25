import Compression
import Foundation

/// Cloud ASR via Volcengine Seed-ASR 2.0 (豆包大模型语音识别).
/// Uses V3 bigmodel_nostream WebSocket endpoint: send all audio, get one high-accuracy result.
final class VolcEngineRecognizer: @unchecked Sendable {
    private let apiKey: String
    private let resourceId = "volc.bigasr.sauc.duration"
    private let endpoint = URL(string: "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_nostream")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Recognize speech from Float32 audio samples (16kHz mono).
    /// Returns recognized text, or an error message string on failure.
    func recognize(samples: [Float]) async -> String {
        guard !samples.isEmpty else { return "" }

        let pcmData = float32ToPCM16(samples)
        let connectId = UUID().uuidString

        let audioDuration = String(format: "%.1f", Double(samples.count) / 16000.0)

        var request = URLRequest(url: endpoint)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(resourceId, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(connectId, forHTTPHeaderField: "X-Api-Connect-Id")

        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: request)
        ws.resume()

        // Timeout: cancel WebSocket after 30s
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(30))
            ws.cancel(with: .abnormalClosure, reason: nil)
        }

        defer {
            timeoutTask.cancel()
            ws.cancel(with: .normalClosure, reason: nil)
        }

        do {
            // 1. Send config
            let configMsg = buildConfigMessage()
            try await ws.send(.data(configMsg))

            // 2. Send audio chunks (200ms each = 6400 bytes PCM16 at 16kHz)
            let chunkSize = 6400 // 200ms at 16kHz × 2 bytes
            var offset = 0
            var chunkCount = 0

            while offset < pcmData.count {
                let end = min(offset + chunkSize, pcmData.count)
                let chunk = pcmData[offset..<end]
                let isLast = end >= pcmData.count
                chunkCount += 1

                let audioMsg = buildAudioMessage(chunk: Data(chunk), isLast: isLast)
                try await ws.send(.data(audioMsg))
                offset = end
            }
            // 3. Wait for final result
            let text = try await waitForResult(ws: ws)
            logToFile("☁️ Cloud ASR: \(audioDuration)s audio → \"\(text.prefix(80))\"")
            return text

        } catch {
            logToFile("☁️ Cloud ASR error (\(audioDuration)s audio): \(error)")
            if error is CancellationError || "\(error)".contains("cancelled") {
                return "[云端识别超时]"
            }
            return "[云端识别失败: \(error.localizedDescription)]"
        }
    }

    private func logToFile(_ msg: String) {
        let line = "\(msg)\n"
        let path = "/tmp/azex-asr.log"
        if let fh = FileHandle(forWritingAtPath: path) {
            fh.seekToEndOfFile()
            fh.write(Data(line.utf8))
            fh.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: Data(line.utf8))
        }
    }

    // MARK: - Protocol: Build Messages

    /// Binary protocol constants
    private enum Proto {
        static let versionAndHeaderSize: UInt8 = 0x11 // version=1, headerSize=1 (4 bytes)
        // Message types (high nibble of byte 1)
        static let fullClientRequest: UInt8 = 0x1
        static let audioOnlyRequest: UInt8 = 0x2
        static let fullServerResponse: UInt8 = 0x9
        static let serverError: UInt8 = 0xF
        // Flags (low nibble of byte 1)
        static let noSequence: UInt8 = 0x0
        static let posSequence: UInt8 = 0x1
        static let negSequence: UInt8 = 0x2
        // Serialization (high nibble of byte 2)
        static let jsonSerialization: UInt8 = 0x1
        static let noSerialization: UInt8 = 0x0
        // Compression (low nibble of byte 2)
        static let gzipCompression: UInt8 = 0x1
        static let noCompression: UInt8 = 0x0
    }

    private func buildConfigMessage() -> Data {
        let config: [String: Any] = [
            "user": [
                "uid": "azex-speech",
            ],
            "audio": [
                "format": "pcm",
                "rate": 16000,
                "bits": 16,
                "channel": 1,
                "codec": "raw",
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,
                "result_type": "full",
                "show_utterances": false,
            ],
        ]

        let jsonData = try! JSONSerialization.data(withJSONObject: config)

        // Send config WITHOUT compression to avoid gzip format issues
        var msg = Data(capacity: 8 + jsonData.count)
        msg.append(Proto.versionAndHeaderSize)
        msg.append((Proto.fullClientRequest << 4) | Proto.noSequence)
        msg.append((Proto.jsonSerialization << 4) | Proto.noCompression)
        msg.append(0x00) // reserved

        appendUInt32BigEndian(&msg, UInt32(jsonData.count))
        msg.append(jsonData)
        return msg
    }

    private func buildAudioMessage(chunk: Data, isLast: Bool) -> Data {
        // Audio packets: flag 0b0000 for normal, 0b0010 for final (no sequence numbers)
        // Send raw PCM without compression
        let flag: UInt8 = isLast ? 0x02 : 0x00

        var msg = Data(capacity: 8 + chunk.count)
        msg.append(Proto.versionAndHeaderSize)
        msg.append((Proto.audioOnlyRequest << 4) | flag)
        msg.append((Proto.noSerialization << 4) | Proto.noCompression)
        msg.append(0x00) // reserved

        appendUInt32BigEndian(&msg, UInt32(chunk.count))
        msg.append(chunk)
        return msg
    }

    // MARK: - Protocol: Parse Response

    private func waitForResult(ws: URLSessionWebSocketTask) async throws -> String {
        while true {
            let message = try await ws.receive()
            guard case .data(let data) = message, data.count >= 4 else { continue }

            let headerSizeUnits = Int(data[0] & 0x0F)
            let headerBytes = headerSizeUnits * 4
            let messageType = (data[1] >> 4) & 0x0F
            let flags = data[1] & 0x0F
            let serialization = (data[2] >> 4) & 0x0F
            let compression = data[2] & 0x0F

            var offset = headerBytes

            // Skip sequence field if present
            if flags == Proto.posSequence || flags == Proto.negSequence || flags == 0x03 {
                offset += 4
            }

            // Read payload size
            guard data.count >= offset + 4 else { continue }
            let payloadSize = Int(readUInt32BigEndian(data, at: offset))
            offset += 4

            guard data.count >= offset + payloadSize else { continue }
            var payload = Data(data[offset..<(offset + payloadSize)])

            // Decompress
            if compression == Proto.gzipCompression {
                guard let decompressed = payload.volcGzipDecompressed() else {
                    print("☁️ Failed to decompress server response")
                    continue
                }
                payload = decompressed
            }

            // Parse JSON
            if serialization == Proto.jsonSerialization,
               let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
            {
                // Server error
                if messageType == Proto.serverError {
                    let code = json["status_code"] as? Int ?? -1
                    let errorMsg = json["status_text"] as? String
                        ?? json["message"] as? String ?? "Unknown error"
                    print("☁️ Server error \(code): \(errorMsg)")
                    return "[云端错误: \(errorMsg)]"
                }

                // Full server response — extract text
                if messageType == Proto.fullServerResponse {
                    // Try V3 response format
                    if let result = json["result"] as? [String: Any],
                       let text = result["text"] as? String, !text.isEmpty
                    {
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    // Try nested payload_msg format
                    if let payloadMsg = json["payload_msg"] as? [String: Any],
                       let result = payloadMsg["result"] as? [String: Any],
                       let text = result["text"] as? String, !text.isEmpty
                    {
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    // Check if it's an intermediate ack (not the final result)
                    let isLast = json["is_last_package"] as? Bool ?? false
                    if !isLast { continue }

                    // Final package but no text = silence
                    return ""
                }
            }
        }
    }

    // MARK: - Audio Conversion

    /// Convert Float32 [-1,1] samples to 16-bit signed PCM (little-endian)
    private func float32ToPCM16(_ samples: [Float]) -> Data {
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            var int16val = Int16(clamped * 32767.0).littleEndian
            withUnsafeBytes(of: &int16val) { data.append(contentsOf: $0) }
        }
        return data
    }

    // MARK: - Binary Helpers

    private func appendUInt32BigEndian(_ data: inout Data, _ value: UInt32) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    private func appendInt32BigEndian(_ data: inout Data, _ value: Int32) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    private func readUInt32BigEndian(_ data: Data, at offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].withUnsafeBytes { ptr in
            UInt32(bigEndian: ptr.load(as: UInt32.self))
        }
    }
}

// MARK: - Gzip Compression (using Apple Compression framework)

extension Data {
    /// Compress data using gzip format (RFC 1952).
    /// Uses Apple's Compression framework for raw deflate, wrapped with gzip header/footer.
    func volcGzipCompressed() -> Data {
        guard !isEmpty else { return self }

        // Raw deflate via Compression framework
        var src = [UInt8](self)
        let dstCapacity = count + 1024
        var dst = [UInt8](repeating: 0, count: dstCapacity)

        let compressedSize = compression_encode_buffer(
            &dst, dstCapacity, &src, count, nil, COMPRESSION_ZLIB
        )
        guard compressedSize > 0 else { return self }

        // Gzip = 10-byte header + raw deflate + CRC32 + original size
        var result = Data(capacity: 18 + compressedSize)
        result.append(contentsOf: [0x1F, 0x8B]) // magic
        result.append(0x08) // method = deflate
        result.append(0x00) // flags
        result.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // mtime
        result.append(0x00) // extra flags
        result.append(0xFF) // OS = unknown

        result.append(contentsOf: dst[..<compressedSize])

        var crc = volcCRC32().littleEndian
        Swift.withUnsafeBytes(of: &crc) { result.append(contentsOf: $0) }
        var size = UInt32(truncatingIfNeeded: count).littleEndian
        Swift.withUnsafeBytes(of: &size) { result.append(contentsOf: $0) }

        return result
    }

    /// Decompress gzip data (RFC 1952).
    func volcGzipDecompressed() -> Data? {
        guard count > 18, self[0] == 0x1F, self[1] == 0x8B else { return nil }

        // Skip variable-length gzip header
        var offset = 10
        let flags = self[3]
        if flags & 0x04 != 0 { // FEXTRA
            guard count > offset + 2 else { return nil }
            let xlen = Int(self[offset]) | (Int(self[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flags & 0x08 != 0 { // FNAME
            while offset < count, self[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while offset < count, self[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 { offset += 2 } // FHCRC

        guard offset < count - 8 else { return nil }

        // Decompress raw deflate (skip 8-byte footer: CRC32 + size)
        var src = [UInt8](self[offset..<(count - 8)])
        let dstCapacity = count * 20 // generous for text responses
        var dst = [UInt8](repeating: 0, count: dstCapacity)

        let decompressedSize = compression_decode_buffer(
            &dst, dstCapacity, &src, src.count, nil, COMPRESSION_ZLIB
        )
        guard decompressedSize > 0 else { return nil }
        return Data(dst[..<decompressedSize])
    }

    /// CRC-32 checksum per ISO 3309 / ITU-T V.42.
    private func volcCRC32() -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in self {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1 != 0) ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

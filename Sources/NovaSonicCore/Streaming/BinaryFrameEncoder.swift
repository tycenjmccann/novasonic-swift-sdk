//
//  BinaryFrameEncoder.swift
//  NovaSonic Package
//
//  Internal encoder for AWS event-stream binary frames used in binary audio transport mode.
//
import Foundation

/// Internal encoder for AWS event-stream binary frames used in binary audio transport mode.
/// Encodes raw PCM16 LE audio data with appropriate event-stream headers.
struct BinaryFrameEncoder {

    /// Encodes raw PCM16 LE audio data into an AWS event-stream binary frame.
    ///
    /// Frame structure:
    /// - Total byte length (4 bytes, big-endian)
    /// - Headers byte length (4 bytes, big-endian)
    /// - Prelude CRC (4 bytes)
    /// - Headers
    /// - Payload (raw PCM bytes)
    /// - Message CRC (4 bytes)
    ///
    /// Headers included:
    /// - `:event-type` = "audioInput"
    /// - `:content-type` = "application/octet-stream"
    /// - `:message-type` = "event"
    /// - `promptName` = provided prompt name
    /// - `audioContentName` = provided audio content name
    static func encodeAudioFrame(
        audioData: Data,
        promptName: String,
        audioContentName: String
    ) -> Data {
        // Build headers
        var headers = Data()
        appendHeader(&headers, name: ":event-type", value: "audioInput")
        appendHeader(&headers, name: ":content-type", value: "application/octet-stream")
        appendHeader(&headers, name: ":message-type", value: "event")
        appendHeader(&headers, name: "promptName", value: promptName)
        appendHeader(&headers, name: "audioContentName", value: audioContentName)

        let headersLength = UInt32(headers.count)
        let totalLength = UInt32(12 + headers.count + audioData.count + 4) // prelude(12) + headers + payload + message CRC

        // Build prelude
        var prelude = Data()
        appendUInt32BigEndian(&prelude, value: totalLength)
        appendUInt32BigEndian(&prelude, value: headersLength)

        // Prelude CRC
        let preludeCRC = crc32(prelude)
        appendUInt32BigEndian(&prelude, value: preludeCRC)

        // Assemble message (without message CRC)
        var message = Data()
        message.append(prelude)
        message.append(headers)
        message.append(audioData)

        // Message CRC (over entire message so far)
        let messageCRC = crc32(message)
        appendUInt32BigEndian(&message, value: messageCRC)

        return message
    }

    // MARK: - Private Helpers

    private static func appendHeader(_ data: inout Data, name: String, value: String) {
        let nameBytes = Data(name.utf8)
        let valueBytes = Data(value.utf8)

        // Header name length (1 byte)
        data.append(UInt8(nameBytes.count))
        // Header name
        data.append(nameBytes)
        // Header value type (7 = string)
        data.append(UInt8(7))
        // Header value length (2 bytes, big-endian)
        let valueLength = UInt16(valueBytes.count)
        data.append(UInt8((valueLength >> 8) & 0xFF))
        data.append(UInt8(valueLength & 0xFF))
        // Header value
        data.append(valueBytes)
    }

    private static func appendUInt32BigEndian(_ data: inout Data, value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    /// CRC-32C (Castagnoli) used by AWS event-stream protocol.
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0x82F63B78 // CRC-32C polynomial
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

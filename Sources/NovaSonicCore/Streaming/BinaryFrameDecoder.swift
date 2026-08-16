//
//  BinaryFrameDecoder.swift
//  NovaSonic Package
//
//  Internal decoder for incoming AWS event-stream frames.
//
import Foundation

/// Result of decoding an incoming event-stream frame.
enum DecodedFrame {
    /// A binary audio frame containing raw PCM16 LE data.
    case binaryAudio(Data)
    /// A JSON text event (existing pipeline).
    case jsonEvent(String)
    /// Frame could not be decoded.
    case unknown
}

/// Internal decoder for incoming AWS event-stream frames.
/// Demuxes binary audio frames from JSON control events based on :content-type header.
struct BinaryFrameDecoder {

    /// Decodes an AWS event-stream frame and determines its type.
    ///
    /// - Parameter frameData: The complete event-stream frame bytes.
    /// - Returns: A `DecodedFrame` indicating whether this is binary audio or a JSON event.
    static func decode(_ frameData: Data) -> DecodedFrame {
        // Minimum frame size: 12 (prelude) + 4 (message CRC) = 16 bytes
        guard frameData.count >= 16 else {
            return .unknown
        }

        // Parse prelude
        let totalLength = readUInt32BigEndian(frameData, offset: 0)
        let headersLength = readUInt32BigEndian(frameData, offset: 4)

        // Validate frame size
        guard totalLength == UInt32(frameData.count) else {
            return .unknown
        }

        // Parse headers (starting at offset 12, after prelude + prelude CRC)
        let headersStart = 12
        let headersEnd = headersStart + Int(headersLength)

        guard headersEnd <= frameData.count - 4 else { // -4 for message CRC
            return .unknown
        }

        let headers = parseHeaders(frameData, from: headersStart, length: Int(headersLength))

        // Extract payload
        let payloadStart = headersEnd
        let payloadEnd = frameData.count - 4 // exclude message CRC

        guard payloadEnd >= payloadStart else {
            return .unknown
        }

        let payload = frameData[payloadStart..<payloadEnd]

        // Determine frame type based on :content-type header
        let contentType = headers[":content-type"] ?? ""

        if contentType == "application/octet-stream" {
            return .binaryAudio(Data(payload))
        } else if contentType.contains("json") || contentType.contains("text") || contentType.isEmpty {
            if let jsonString = String(data: Data(payload), encoding: .utf8) {
                return .jsonEvent(jsonString)
            }
            return .unknown
        }

        return .unknown
    }

    // MARK: - Private Helpers

    private static func readUInt32BigEndian(_ data: Data, offset: Int) -> UInt32 {
        let bytes = data[offset..<(offset + 4)]
        var value: UInt32 = 0
        for byte in bytes {
            value = (value << 8) | UInt32(byte)
        }
        return value
    }

    private static func parseHeaders(_ data: Data, from offset: Int, length: Int) -> [String: String] {
        var headers: [String: String] = [:]
        var position = offset
        let end = offset + length

        while position < end {
            // Header name length (1 byte)
            guard position < end else { break }
            let nameLength = Int(data[position])
            position += 1

            // Header name
            guard position + nameLength <= end else { break }
            let nameData = data[position..<(position + nameLength)]
            let name = String(data: Data(nameData), encoding: .utf8) ?? ""
            position += nameLength

            // Header value type (1 byte)
            guard position < end else { break }
            let valueType = data[position]
            position += 1

            // For string type (7): 2-byte length + value
            if valueType == 7 {
                guard position + 2 <= end else { break }
                let valueLength = Int(UInt16(data[position]) << 8 | UInt16(data[position + 1]))
                position += 2

                guard position + valueLength <= end else { break }
                let valueData = data[position..<(position + valueLength)]
                let value = String(data: Data(valueData), encoding: .utf8) ?? ""
                position += valueLength

                headers[name] = value
            } else {
                // Skip other value types (not expected in audio frames)
                // Type sizes: 0=bool_true(0), 1=bool_false(0), 2=byte(1), 3=short(2),
                // 4=int(4), 5=long(8), 6=bytes(2+len), 7=string(2+len), 8=timestamp(8), 9=uuid(16)
                let skipSize: Int
                switch valueType {
                case 0, 1: skipSize = 0
                case 2: skipSize = 1
                case 3: skipSize = 2
                case 4: skipSize = 4
                case 5, 8: skipSize = 8
                case 9: skipSize = 16
                case 6: // bytes
                    guard position + 2 <= end else { break }
                    let len = Int(UInt16(data[position]) << 8 | UInt16(data[position + 1]))
                    position += 2 + len
                    continue
                default: break
                }
                position += skipSize
            }
        }

        return headers
    }
}

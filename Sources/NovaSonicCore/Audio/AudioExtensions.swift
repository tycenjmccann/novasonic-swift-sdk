//
//  AudioExtensions.swift
//  NovaSonic Package
//
//  Audio utility extensions for Nova Sonic streaming
//

import AVFAudio

// Helper extensions
extension AVAudioPCMBuffer {
    func toData() -> Data? {
        guard let ptr = int16ChannelData?[0] else { return nil }
        return Data(bytes: ptr, count: Int(frameLength) * 2)
    }
}

extension Data {
    func toPCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(count) / 2
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Copy data to buffer
        let ptr = buffer.int16ChannelData?[0]
        self.withUnsafeBytes { (bufferPtr: UnsafeRawBufferPointer) in
            guard let src = bufferPtr.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            ptr?.initialize(from: src, count: Int(frameCount))
        }
        
        return buffer
    }
}

extension Data {
    // Converts an AVAudioPCMBuffer to Data as if it were Int16.
    // If the buffer is in float32 format, we convert each sample assuming the values are in [-1, 1].
    init?(pcmBuffer buffer: AVAudioPCMBuffer) {
        let sampleCount = Int(buffer.frameLength)
        
        // Check the commonFormat of the buffer.
        if buffer.format.commonFormat == .pcmFormatInt16 {
            // If already int16, we can directly use int16ChannelData.
            guard let channelData = buffer.int16ChannelData else {
                return nil
            }
            let byteCount = sampleCount * MemoryLayout<Int16>.size
            self.init(bytes: UnsafeRawPointer(channelData[0]), count: byteCount)
        }
        else if buffer.format.commonFormat == .pcmFormatFloat32 {
            // Convert float samples to int16.
            guard let floatData = buffer.floatChannelData?[0] else {
                return nil
            }
            var int16Array = [Int16](repeating: 0, count: sampleCount)
            for i in 0..<sampleCount {
                // Clamp the value to [-1, 1] and then multiply by the maximum Int16 value.
                let clamped = Swift.max(Swift.min(floatData[i], 1.0), -1.0)
                int16Array[i] = Int16(clamped * Float(Int16.max))
            }
            self = int16Array.withUnsafeBytes { Data($0) }
        }
        else {
            NovaSonicLogger.error("Unhandled audio format: \(buffer.format.commonFormat)")
            return nil
        }
    }
}




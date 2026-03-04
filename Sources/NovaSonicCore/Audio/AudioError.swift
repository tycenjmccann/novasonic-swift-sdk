// AudioError.swift
import Foundation

public enum AudioError: Error {
    case converterCreationFailed
    case microphoneNotAvailable
    case sessionConfigurationFailed
    case engineStartFailed
    case conversionFailed
    case bufferCreationFailed
    case invalidFormat
}

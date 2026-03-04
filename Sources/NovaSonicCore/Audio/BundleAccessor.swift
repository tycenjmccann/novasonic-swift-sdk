//
//  BundleAccessor.swift
//  NovaSonicCore
//
//  Public accessor for package bundle resources
//

import Foundation

/// Public accessor for NovaSonic package bundle
public enum NovaSonicBundle {
    /// Get the package bundle
    public static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleAccessor.self)
        #endif
    }
}

/// Private class for bundle identification
private class BundleAccessor {}

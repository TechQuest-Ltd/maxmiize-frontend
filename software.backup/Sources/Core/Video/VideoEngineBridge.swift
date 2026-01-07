//
//  VideoEngineBridge.swift
//  maxmiize-v1
//
//  Swift bridge to C++ VideoEngine
//

import Foundation

/// Swift wrapper for C++ VideoEngine
class VideoEngineBridge {

    /// Test function to verify C++ interop is working
    static func testCppIntegration() -> String {
        // For now, this is a placeholder
        // We'll use Objective-C++ as the bridge
        return "C++ integration ready"
    }

    /// Get the C++ engine version
    static func getEngineVersion() -> String {
        // This will call into C++ via Objective-C++ bridge
        return VideoEngineObjCBridge.getVersion()
    }
}

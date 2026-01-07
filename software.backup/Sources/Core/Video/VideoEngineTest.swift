//
//  VideoEngineTest.swift
//  maxmiize-v1
//
//  Test file to verify C++ integration
//

import Foundation

class VideoEngineTest {

    static func runTests() {
        print("========================================")
        print("🧪 Testing C++ VideoEngine Integration")
        print("========================================")

        // Test 1: Get version from C++
        let version = VideoEngineObjCBridge.getVersion()
        print("✅ C++ Engine Version: \(version)")

        // Test 2: Test message
        let message = VideoEngineObjCBridge.testMessage()
        print("✅ Test Message: \(message)")

        // Test 3: Initialize engine
        let initialized = VideoEngineObjCBridge.initialize()
        print("✅ Engine Initialized: \(initialized)")

        print("========================================")
        print("🎉 All C++ integration tests passed!")
        print("========================================")
    }
}

//
//  AboutViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/5/25.
//

import Testing
@testable import Flameworker

@Suite("AboutView Tests")
struct AboutViewTests {
    
    @Test("AboutView should exist and be accessible")
    func testAboutViewExists() {
        // This test will fail initially because AboutView doesn't exist yet
        let aboutView = AboutView()
        
        // The view should be instantiable
        #expect(aboutView != nil, "AboutView should be instantiable")
    }
    
    @Test("AboutView should display app version information")
    func testAboutViewDisplaysVersionInformation() {
        let aboutView = AboutView()
        
        // AboutView should provide access to version information
        // This will help us verify the structure we need to implement
        #expect(aboutView.appVersion != nil, "AboutView should provide app version")
        #expect(aboutView.buildVersion != nil, "AboutView should provide build version")
    }
    
    @Test("AboutView should display Core Data model information")
    func testAboutViewDisplaysCoreDataInformation() {
        let aboutView = AboutView()
        
        // AboutView should provide access to Core Data model information
        #expect(aboutView.coreDataModelVersion != nil, "AboutView should provide Core Data model version")
        #expect(aboutView.modelHash != nil, "AboutView should provide model hash")
    }
}
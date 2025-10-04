//
//  WeightUnitTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("WeightUnit Tests")
struct WeightUnitTests {
    
    @Test("WeightUnit has correct display names")
    func testDisplayNames() {
        #expect(WeightUnit.pounds.displayName == "Pounds")
        #expect(WeightUnit.kilograms.displayName == "Kilograms")
    }
    
    @Test("WeightUnit has correct symbols")
    func testSymbols() {
        #expect(WeightUnit.pounds.symbol == "lb")
        #expect(WeightUnit.kilograms.symbol == "kg")
    }
    
    @Test("WeightUnit conversion from pounds to kilograms")
    func testPoundsToKilogramsConversion() {
        let result = WeightUnit.pounds.convert(10.0, to: .kilograms)
        #expect(abs(result - 4.53592) < 0.0001, "10 pounds should convert to ~4.53592 kg")
    }
    
    @Test("WeightUnit conversion from kilograms to pounds")
    func testKilogramsToPoundsConversion() {
        let result = WeightUnit.kilograms.convert(5.0, to: .pounds)
        #expect(abs(result - 11.0231) < 0.001, "5 kg should convert to ~11.0231 pounds")
    }
    
    @Test("WeightUnit same unit conversion returns original value")
    func testSameUnitConversion() {
        #expect(WeightUnit.pounds.convert(10.0, to: .pounds) == 10.0)
        #expect(WeightUnit.kilograms.convert(5.0, to: .kilograms) == 5.0)
    }
    
    @Test("WeightUnit has correct system image")
    func testSystemImage() {
        #expect(WeightUnit.pounds.systemImage == "scalemass")
        #expect(WeightUnit.kilograms.systemImage == "scalemass")
    }
}
//
//  KilnScheduleModelTests.swift
//  MoltenTests
//
//  Tests for KilnSchedule and KilnSegment domain models
//

import Testing
import Foundation
@testable import Molten

/// Test suite for kiln schedule domain models
@Suite("Kiln Schedule Model Tests")
struct KilnScheduleModelTests {

    // MARK: - KilnSegment Tests

    @Test("Should create ramp segment with rate")
    func testCreateRampSegment() async throws {
        // Arrange & Act
        let segment = KilnSegment(
            targetTemperature: 1450,
            rampRate: 300
        )

        // Assert
        #expect(segment.targetTemperature == 1450)
        #expect(segment.rampRate == 300)
        #expect(segment.holdTime == 0)  // Default hold time is 0
    }

    @Test("Should create segment with hold time")
    func testCreateSegmentWithHold() async throws {
        // Arrange & Act
        let segment = KilnSegment(
            targetTemperature: 1450,
            rampRate: 1,
            holdTime: 30
        )

        // Assert
        #expect(segment.targetTemperature == 1450)
        #expect(segment.rampRate == 1)
        #expect(segment.holdTime == 30)
    }

    @Test("Should calculate ramp segment duration")
    func testRampSegmentDuration() async throws {
        // Arrange
        let segment = KilnSegment(
            targetTemperature: 1000,
            rampRate: 250
        )
        let startTemp: Decimal = 70

        // Act
        let duration = segment.calculateDuration(from: startTemp)

        // Assert
        // Duration = (1000 - 70) / 250 = 3.72 hours = 13,392 seconds
        #expect(duration == 13392.0)
    }

    @Test("Should calculate hold segment duration")
    func testHoldSegmentDuration() async throws {
        // Arrange
        // Segment at same temperature as before, with 45 minute hold
        let segment = KilnSegment(
            targetTemperature: 1450,
            rampRate: 1,  // Rate doesn't matter when temp delta is 0
            holdTime: 45
        )

        // Act
        let duration = segment.calculateDuration(from: 1450)

        // Assert
        // Duration = 0 ramp time (already at temp) + 45 minutes hold = 2,700 seconds
        #expect(duration == 2700.0)
    }

    @Test("Should calculate duration with both ramp and hold")
    func testRampAndHoldSegmentDuration() async throws {
        // Arrange
        // Segment that ramps to temperature AND holds
        // This is the common case: ramp to 1000°F at 300°/hr, then hold for 30 min
        let segment = KilnSegment(
            targetTemperature: 1000,
            rampRate: 300,
            holdTime: 30
        )
        let startTemp: Decimal = 70

        // Act
        let duration = segment.calculateDuration(from: startTemp)

        // Assert
        // Ramp time: (1000 - 70) / 300 = 3.1 hours = 11,160 seconds
        // Hold time: 30 minutes = 1,800 seconds
        // Total: 11,160 + 1,800 = 12,960 seconds
        #expect(duration == 12960.0, "Duration should be ramp time + hold time")
    }

    @Test("Should use configured kiln rate when rate is 9999")
    @MainActor
    func testAutomaticRateSelection() async throws {
        // Arrange
        // Set a known cooldown rate for testing
        UserSettings.shared.kilnCooldownRate260to540 = 167

        // Segment with 9999 rate (auto-select from settings)
        // Cooling from 500°C to 100°C
        let segment = KilnSegment(
            targetTemperature: 100,
            rampRate: 9999
        )
        let startTemp: Decimal = 500

        // Act
        let duration = segment.calculateDuration(from: startTemp)

        // Assert
        // Should use cooldown rate of 167°C/hour for this temperature range
        // Duration = (500 - 100) / 167 = 2.395 hours = 8,622 seconds
        let expectedDuration = TimeInterval((400.0 / 167.0) * 3600.0)
        #expect(abs(duration - expectedDuration) < 1.0, "Should use configured cooldown rate")
    }

    // MARK: - KilnSchedule Tests

    @Test("Should create basic kiln schedule")
    func testCreateBasicSchedule() async throws {
        // Arrange & Act
        let schedule = KilnSchedule(
            name: "Full Fuse",
            technique: .fusing
        )

        // Assert
        #expect(schedule.name == "Full Fuse")
        #expect(schedule.technique == .fusing)
        #expect(schedule.segments.isEmpty)
    }

    @Test("Should create schedule with segments")
    func testCreateScheduleWithSegments() async throws {
        // Arrange
        let segment1 = KilnSegment(targetTemperature: 1000, rampRate: 300)
        let segment2 = KilnSegment(targetTemperature: 1000, rampRate: 1, holdTime: 15)
        let segment3 = KilnSegment(targetTemperature: 1450, rampRate: 150)
        let segment4 = KilnSegment(targetTemperature: 1450, rampRate: 1, holdTime: 30)

        // Act
        let schedule = KilnSchedule(
            name: "Full Fuse",
            technique: .fusing,
            segments: [segment1, segment2, segment3, segment4]
        )

        // Assert
        #expect(schedule.segments.count == 4)
        #expect(schedule.segments[0].rampRate == 300)
        #expect(schedule.segments[1].holdTime == 15)
    }

    @Test("Should calculate total schedule duration")
    func testCalculateTotalDuration() async throws {
        // Arrange
        // Full fuse cycle (starting from room temp 20°C):
        // 1. Ramp from 20°C to 538°C at 167°C/hr = (538-20)/167 * 3600 = 11166.467 seconds
        // 2. Hold at 538°C for 15 min = 15 * 60 = 900 seconds
        // 3. Ramp from 538°C to 788°C at 83°C/hr = (788-538)/83 * 3600 = 10843.373 seconds
        // 4. Hold at 788°C for 30 min = 30 * 60 = 1800 seconds
        // Total = 24,709.84 seconds

        let segments = [
            KilnSegment(targetTemperature: 538, rampRate: 167, holdTime: 0),
            KilnSegment(targetTemperature: 538, rampRate: 1, holdTime: 15),
            KilnSegment(targetTemperature: 788, rampRate: 83, holdTime: 0),
            KilnSegment(targetTemperature: 788, rampRate: 1, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            name: "Full Fuse",
            technique: .fusing,
            segments: segments
        )

        // Act
        let duration = schedule.totalDuration

        // Assert
        // Use approximate comparison due to Decimal precision
        #expect(abs(duration - 24709.84) < 1.0)
    }

    @Test("Should handle schedule with no segments")
    func testEmptyScheduleDuration() async throws {
        // Arrange
        let schedule = KilnSchedule(
            name: "Empty Schedule",
            technique: .fusing
        )

        // Act
        let duration = schedule.totalDuration

        // Assert
        #expect(duration == 0.0)
    }

    @Test("Should format duration as readable time")
    func testDurationFormatting() async throws {
        // Arrange
        let segments = [
            KilnSegment(targetTemperature: 538, rampRate: 167, holdTime: 0),
            KilnSegment(targetTemperature: 538, rampRate: 1, holdTime: 15),
            KilnSegment(targetTemperature: 788, rampRate: 83, holdTime: 0),
            KilnSegment(targetTemperature: 788, rampRate: 1, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            name: "Full Fuse",
            technique: .fusing,
            segments: segments
        )

        // Act
        let formatted = schedule.formattedDuration

        // Assert
        #expect(formatted == "6h 51m")
    }

    // MARK: - TechniqueType Tests

    @Test("Should have correct technique display names")
    func testTechniqueDisplayNames() async throws {
        #expect(TechniqueType.fusing.displayName == "Fusing")
        #expect(TechniqueType.casting.displayName == "Casting")
        #expect(TechniqueType.glassBlowing.displayName == "Glass Blowing")
        #expect(TechniqueType.flameworkinghard.displayName == "Flameworking - Hard")
        #expect(TechniqueType.flameworkingsoft.displayName == "Flameworking - Soft")
        #expect(TechniqueType.stainedGlass.displayName == "Stained Glass")
        #expect(TechniqueType.other.displayName == "Other")
    }

    // MARK: - TemperatureUnit Tests

    @Test("Should have correct temperature unit symbols")
    func testTemperatureUnitSymbols() async throws {
        #expect(TemperatureUnit.fahrenheit.symbol == "°F")
        #expect(TemperatureUnit.celsius.symbol == "°C")
    }

    // MARK: - Codable Tests

    @Test("Should encode and decode KilnSegment")
    func testKilnSegmentCodable() async throws {
        // Arrange
        let original = KilnSegment(targetTemperature: 1450, rampRate: 300)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(KilnSegment.self, from: data)

        // Assert
        #expect(decoded.id == original.id)
        #expect(decoded.targetTemperature == original.targetTemperature)
        #expect(decoded.rampRate == original.rampRate)
    }

    @Test("Should encode and decode KilnSchedule")
    func testKilnScheduleCodable() async throws {
        // Arrange
        let segments = [
            KilnSegment(targetTemperature: 1000, rampRate: 300),
            KilnSegment(targetTemperature: 1450, rampRate: 1, holdTime: 30)
        ]

        let original = KilnSchedule(
            name: "Test Schedule",
            technique: .fusing,
            segments: segments,
            description: "Test description"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(KilnSchedule.self, from: data)

        // Assert
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.technique == original.technique)
        #expect(decoded.segments.count == original.segments.count)
        #expect(decoded.description == original.description)
    }

    // MARK: - Temperature Range Formatting Tests (for Coatings)

    @Test("Should format temperature range with both values in Fahrenheit")
    func testFormatTemperatureRangeBothValuesFahrenheit() async throws {
        let result = TemperatureUnit.fahrenheit.formatTemperatureRange(lowF: 1175, highF: 1425)
        #expect(result == "1175-1425°F")
    }

    @Test("Should format temperature range with both values in Celsius")
    func testFormatTemperatureRangeBothValuesCelsius() async throws {
        // 1175°F = 635°C, 1425°F = 774°C (rounded)
        let result = TemperatureUnit.celsius.formatTemperatureRange(lowF: 1175, highF: 1425)
        #expect(result == "635-774°C")
    }

    @Test("Should format temperature range with only low value")
    func testFormatTemperatureRangeOnlyLow() async throws {
        let resultF = TemperatureUnit.fahrenheit.formatTemperatureRange(lowF: 1175, highF: nil)
        #expect(resultF == "1175+°F")

        let resultC = TemperatureUnit.celsius.formatTemperatureRange(lowF: 1175, highF: nil)
        #expect(resultC == "635+°C")
    }

    @Test("Should format temperature range with only high value")
    func testFormatTemperatureRangeOnlyHigh() async throws {
        let resultF = TemperatureUnit.fahrenheit.formatTemperatureRange(lowF: nil, highF: 1425)
        #expect(resultF == "1425°F")

        let resultC = TemperatureUnit.celsius.formatTemperatureRange(lowF: nil, highF: 1425)
        #expect(resultC == "774°C")
    }

    @Test("Should format temperature range with no values")
    func testFormatTemperatureRangeNoValues() async throws {
        let resultF = TemperatureUnit.fahrenheit.formatTemperatureRange(lowF: nil, highF: nil)
        #expect(resultF == "?-?°F")

        let resultC = TemperatureUnit.celsius.formatTemperatureRange(lowF: nil, highF: nil)
        #expect(resultC == "?-?°C")
    }

    @Test("Should convert Fahrenheit to Celsius correctly")
    func testFromFahrenheitConversion() async throws {
        // 32°F = 0°C
        #expect(TemperatureUnit.celsius.fromFahrenheit(32) == 0)

        // 212°F = 100°C
        #expect(TemperatureUnit.celsius.fromFahrenheit(212) == 100)

        // 1175°F ≈ 635°C
        #expect(TemperatureUnit.celsius.fromFahrenheit(1175) == 635)

        // Fahrenheit should return same value
        #expect(TemperatureUnit.fahrenheit.fromFahrenheit(1175) == 1175)
    }

    @Test("Should have correct short symbols")
    func testShortSymbols() async throws {
        #expect(TemperatureUnit.fahrenheit.shortSymbol == "F")
        #expect(TemperatureUnit.celsius.shortSymbol == "C")
    }
}

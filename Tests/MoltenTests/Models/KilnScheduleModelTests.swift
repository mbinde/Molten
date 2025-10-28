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
        #expect(segment.segmentType == .ramp)
        #expect(segment.targetTemperature == 1450)
        #expect(segment.rampRate == 300)
        #expect(segment.holdTime == nil)
    }

    @Test("Should create hold segment with time")
    func testCreateHoldSegment() async throws {
        // Arrange & Act
        let segment = KilnSegment(
            targetTemperature: 1450,
            holdTime: 30
        )

        // Assert
        #expect(segment.segmentType == .hold)
        #expect(segment.targetTemperature == 1450)
        #expect(segment.holdTime == 30)
        #expect(segment.rampRate == nil)
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
        let segment = KilnSegment(
            targetTemperature: 1450,
            holdTime: 45
        )

        // Act
        let duration = segment.calculateDuration(from: 70)

        // Assert
        // Duration = 45 minutes = 2,700 seconds
        #expect(duration == 2700.0)
    }

    // MARK: - KilnSchedule Tests

    @Test("Should create basic kiln schedule")
    func testCreateBasicSchedule() async throws {
        // Arrange & Act
        let schedule = KilnSchedule(
            name: "Full Fuse",
            technique: .fusing,
            startTemperature: 70,
            temperatureUnit: .fahrenheit
        )

        // Assert
        #expect(schedule.name == "Full Fuse")
        #expect(schedule.technique == .fusing)
        #expect(schedule.startTemperature == 70)
        #expect(schedule.temperatureUnit == .fahrenheit)
        #expect(schedule.segments.isEmpty)
    }

    @Test("Should create schedule with segments")
    func testCreateScheduleWithSegments() async throws {
        // Arrange
        let segment1 = KilnSegment(targetTemperature: 1000, rampRate: 300)
        let segment2 = KilnSegment(targetTemperature: 1000, holdTime: 15)
        let segment3 = KilnSegment(targetTemperature: 1450, rampRate: 150)
        let segment4 = KilnSegment(targetTemperature: 1450, holdTime: 30)

        // Act
        let schedule = KilnSchedule(
            name: "Full Fuse",
            technique: .fusing,
            segments: [segment1, segment2, segment3, segment4],
            startTemperature: 70,
            temperatureUnit: .fahrenheit
        )

        // Assert
        #expect(schedule.segments.count == 4)
        #expect(schedule.segments[0].segmentType == .ramp)
        #expect(schedule.segments[1].segmentType == .hold)
    }

    @Test("Should calculate total schedule duration")
    func testCalculateTotalDuration() async throws {
        // Arrange
        // Full fuse cycle:
        // 1. Ramp from 70°F to 1000°F at 300°/hr = 3.1 hours
        // 2. Hold at 1000°F for 15 min = 0.25 hours
        // 3. Ramp from 1000°F to 1450°F at 150°/hr = 3 hours
        // 4. Hold at 1450°F for 30 min = 0.5 hours
        // Total = 6.85 hours = 24,660 seconds

        let segments = [
            KilnSegment(targetTemperature: 1000, rampRate: 300),
            KilnSegment(targetTemperature: 1000, holdTime: 15),
            KilnSegment(targetTemperature: 1450, rampRate: 150),
            KilnSegment(targetTemperature: 1450, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            name: "Full Fuse",
            technique: .fusing,
            segments: segments,
            startTemperature: 70,
            temperatureUnit: .fahrenheit
        )

        // Act
        let duration = schedule.totalDuration

        // Assert
        #expect(duration == 24660.0)
    }

    @Test("Should handle schedule with no segments")
    func testEmptyScheduleDuration() async throws {
        // Arrange
        let schedule = KilnSchedule(
            name: "Empty Schedule",
            technique: .annealing,
            startTemperature: 70,
            temperatureUnit: .fahrenheit
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
            KilnSegment(targetTemperature: 1000, rampRate: 300),
            KilnSegment(targetTemperature: 1000, holdTime: 15),
            KilnSegment(targetTemperature: 1450, rampRate: 150),
            KilnSegment(targetTemperature: 1450, holdTime: 30)
        ]

        let schedule = KilnSchedule(
            name: "Full Fuse",
            technique: .fusing,
            segments: segments,
            startTemperature: 70,
            temperatureUnit: .fahrenheit
        )

        // Act
        let formatted = schedule.formattedDuration

        // Assert
        #expect(formatted == "6h 51m")
    }

    // MARK: - KilnTechnique Tests

    @Test("Should have correct technique display names")
    func testTechniqueDisplayNames() async throws {
        #expect(KilnTechnique.fusing.displayName == "Fusing")
        #expect(KilnTechnique.slumping.displayName == "Slumping")
        #expect(KilnTechnique.casting.displayName == "Casting")
        #expect(KilnTechnique.annealing.displayName == "Annealing")
        #expect(KilnTechnique.tackFuse.displayName == "Tack Fuse")
        #expect(KilnTechnique.fullFuse.displayName == "Full Fuse")
        #expect(KilnTechnique.other.displayName == "Other")
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
            KilnSegment(targetTemperature: 1450, holdTime: 30)
        ]

        let original = KilnSchedule(
            name: "Test Schedule",
            technique: .fusing,
            segments: segments,
            notes: "Test notes",
            startTemperature: 70,
            temperatureUnit: .fahrenheit
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
        #expect(decoded.notes == original.notes)
    }
}

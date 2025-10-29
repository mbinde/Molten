//
//  KilnScheduleModels.swift
//  Molten
//
//  Domain models for kiln firing schedules
//

import Foundation

// MARK: - Enums

/// Temperature unit for kiln schedules
enum TemperatureUnit: String, Codable, Sendable, CaseIterable {
    case fahrenheit
    case celsius

    nonisolated var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .fahrenheit: return "Fahrenheit"
        case .celsius: return "Celsius"
        }
    }

    /// Convert a temperature from this unit to Celsius
    nonisolated func toCelsius(_ temperature: Decimal) -> Decimal {
        switch self {
        case .celsius:
            return temperature
        case .fahrenheit:
            return (temperature - 32) * 5 / 9
        }
    }

    /// Convert a temperature from Celsius to this unit
    nonisolated func fromCelsius(_ temperature: Decimal) -> Decimal {
        switch self {
        case .celsius:
            return temperature
        case .fahrenheit:
            return (temperature * 9 / 5) + 32
        }
    }
}

// KilnTechnique has been deprecated - use TechniqueType from ProjectModels instead
// This provides consistency across the app for flameworking, fusing, glass blowing, etc.

/// Type of kiln segment (ramp or hold)
enum KilnSegmentType: String, Codable, Sendable, CaseIterable {
    case ramp
    case hold

    nonisolated var displayName: String {
        switch self {
        case .ramp: return "Ramp"
        case .hold: return "Hold"
        }
    }
}

// MARK: - KilnSegment

/// Represents a single segment in a kiln firing schedule
/// Can be either a ramp (temperature change at rate) or hold (maintain temperature)
nonisolated struct KilnSegment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let targetTemperature: Decimal
    let rampRate: Decimal?        // Degrees per hour (for ramp segments)
    let holdTime: Decimal?        // Minutes (for hold segments)

    /// Segment type is determined by which parameter is set
    var segmentType: KilnSegmentType {
        if rampRate != nil {
            return .ramp
        } else {
            return .hold
        }
    }

    /// Initialize a ramp segment with target temperature and rate
    nonisolated init(
        id: UUID = UUID(),
        targetTemperature: Decimal,
        rampRate: Decimal
    ) {
        self.id = id
        self.targetTemperature = targetTemperature
        self.rampRate = rampRate
        self.holdTime = nil
    }

    /// Initialize a hold segment with target temperature and hold time
    nonisolated init(
        id: UUID = UUID(),
        targetTemperature: Decimal,
        holdTime: Decimal
    ) {
        self.id = id
        self.targetTemperature = targetTemperature
        self.rampRate = nil
        self.holdTime = holdTime
    }

    /// Calculate duration in seconds for this segment
    /// - Parameter previousTemperature: Starting temperature for ramp segments (temperature at end of previous segment)
    /// - Returns: Duration in seconds
    nonisolated func calculateDuration(from previousTemperature: Decimal) -> TimeInterval {
        switch segmentType {
        case .ramp:
            guard let rate = rampRate, rate > 0 else { return 0 }

            // Special case: 9999 means use kiln's max rates from settings
            let actualRate: Decimal
            if rate == 9999 {
                let isHeatingUp = targetTemperature > previousTemperature

                if isHeatingUp {
                    // Use appropriate heatup rate based on target temperature
                    actualRate = UserSettings.getHeatupRate(forTemperature: targetTemperature)
                } else {
                    // Use appropriate cooldown rate based on starting temperature
                    actualRate = UserSettings.getCooldownRate(forTemperature: previousTemperature)
                }
            } else {
                actualRate = rate
            }

            let temperatureDelta = abs(targetTemperature - previousTemperature)
            let hours = temperatureDelta / actualRate
            return TimeInterval(truncating: hours as NSNumber) * 3600.0

        case .hold:
            guard let minutes = holdTime else { return 0 }
            return TimeInterval(truncating: minutes as NSNumber) * 60.0
        }
    }
}

// MARK: - KilnSchedule

/// Represents a complete kiln firing schedule with multiple segments
nonisolated struct KilnSchedule: Identifiable, Codable, Hashable, Sendable {
    // Identity
    let id: UUID
    let name: String
    let technique: TechniqueType?  // Uses app-wide technique types (flameworking, fusing, glass blowing, etc.)

    // Metadata
    let dateCreated: Date
    let dateModified: Date

    // Configuration
    // Note: All temperatures are stored in Celsius for consistency
    let temperatureUnit: TemperatureUnit  // For backwards compatibility/import-export only
    let segments: [KilnSegment]  // Segment temperatures always in Celsius
    let description: String?  // Optional description of the schedule

    /// Calculate total duration for the entire schedule
    /// Assumes starting from room temperature (20°C) for first ramp segment
    var totalDuration: TimeInterval {
        var currentTemperature: Decimal = 20  // Assume room temperature start
        var totalSeconds: TimeInterval = 0

        for segment in segments {
            let segmentDuration = segment.calculateDuration(from: currentTemperature)
            totalSeconds += segmentDuration
            currentTemperature = segment.targetTemperature
        }

        return totalSeconds
    }

    /// Format duration as human-readable string (e.g., "6h 51m")
    var formattedDuration: String {
        let totalMinutes = Int(totalDuration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Temperature Conversion Helpers

    /// Get a converted copy of the schedule for display in a specific unit
    /// Note: The underlying storage remains in Celsius
    /// - Parameter displayUnit: Unit to display temperatures in
    /// - Returns: Schedule with temperatures converted for display
    nonisolated func converted(to displayUnit: TemperatureUnit) -> KilnSchedule {
        guard displayUnit != .celsius else { return self }

        let convertedSegments = segments.map { segment in
            if let rampRate = segment.rampRate {
                return KilnSegment(
                    id: segment.id,
                    targetTemperature: displayUnit.fromCelsius(segment.targetTemperature),
                    rampRate: rampRate  // Rate is per hour, same regardless of unit
                )
            } else if let holdTime = segment.holdTime {
                return KilnSegment(
                    id: segment.id,
                    targetTemperature: displayUnit.fromCelsius(segment.targetTemperature),
                    holdTime: holdTime
                )
            } else {
                return segment
            }
        }

        return KilnSchedule(
            id: id,
            name: name,
            technique: technique,
            dateCreated: dateCreated,
            dateModified: dateModified,
            segments: convertedSegments,
            description: description,
            temperatureUnit: displayUnit
        )
    }

    /// Create a schedule from user input, normalizing to Celsius for storage
    /// - Parameters:
    ///   - id: Schedule ID
    ///   - name: Schedule name
    ///   - technique: Glass working technique
    ///   - dateCreated: Creation date
    ///   - dateModified: Modification date
    ///   - segments: Segments with temperatures in inputUnit
    ///   - description: Optional description
    ///   - inputUnit: Unit that temperatures are provided in
    /// - Returns: Schedule with all temperatures normalized to Celsius
    nonisolated static func fromInput(
        id: UUID = UUID(),
        name: String,
        technique: TechniqueType?,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        segments: [KilnSegment],
        description: String? = nil,
        inputUnit: TemperatureUnit
    ) -> KilnSchedule {
        let normalizedSegments = segments.map { segment in
            if let rampRate = segment.rampRate {
                return KilnSegment(
                    id: segment.id,
                    targetTemperature: inputUnit.toCelsius(segment.targetTemperature),
                    rampRate: rampRate
                )
            } else if let holdTime = segment.holdTime {
                return KilnSegment(
                    id: segment.id,
                    targetTemperature: inputUnit.toCelsius(segment.targetTemperature),
                    holdTime: holdTime
                )
            } else {
                return segment
            }
        }

        return KilnSchedule(
            id: id,
            name: name,
            technique: technique,
            dateCreated: dateCreated,
            dateModified: dateModified,
            segments: normalizedSegments,
            description: description,
            temperatureUnit: .celsius  // Always store as Celsius
        )
    }

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        technique: TechniqueType?,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        segments: [KilnSegment] = [],
        description: String? = nil,
        temperatureUnit: TemperatureUnit = .celsius
    ) {
        self.id = id
        self.name = name
        self.technique = technique
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.segments = segments
        self.description = description
        self.temperatureUnit = temperatureUnit
    }
}

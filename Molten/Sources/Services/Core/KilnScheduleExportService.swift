//
//  KilnScheduleExportService.swift
//  Molten
//
//  Service for exporting and importing kiln schedules as JSON
//

import Foundation

/// Service for exporting and importing kiln schedules
actor KilnScheduleExportService {

    // MARK: - Export

    /// Exports a kiln schedule to JSON data
    func exportSchedule(_ schedule: KilnSchedule) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(schedule)
    }

    /// Exports multiple schedules to JSON data
    func exportSchedules(_ schedules: [KilnSchedule]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(schedules)
    }

    /// Exports a schedule to a temporary file and returns the URL
    func exportScheduleToFile(_ schedule: KilnSchedule) throws -> URL {
        let data = try exportSchedule(schedule)
        let filename = sanitizeFilename(schedule.name) + ".json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tempURL)
        return tempURL
    }

    // MARK: - Import

    /// Imports a kiln schedule from JSON data
    func importSchedule(from data: Data) throws -> KilnSchedule {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var schedule = try decoder.decode(KilnSchedule.self, from: data)

        // Generate new ID and update dates for imported schedule
        schedule = KilnSchedule(
            id: UUID(),
            name: schedule.name,
            technique: schedule.technique,
            dateCreated: Date(),
            dateModified: Date(),
            segments: schedule.segments.map { segment in
                if let rampRate = segment.rampRate {
                    return KilnSegment(
                        id: UUID(),
                        targetTemperature: segment.targetTemperature,
                        rampRate: rampRate
                    )
                } else if let holdTime = segment.holdTime {
                    return KilnSegment(
                        id: UUID(),
                        targetTemperature: segment.targetTemperature,
                        holdTime: holdTime
                    )
                } else {
                    // Fallback for malformed data
                    return KilnSegment(
                        id: UUID(),
                        targetTemperature: segment.targetTemperature,
                        rampRate: 100
                    )
                }
            },
            notes: schedule.notes,
            startTemperature: schedule.startTemperature,
            temperatureUnit: schedule.temperatureUnit
        )

        return schedule
    }

    /// Imports multiple schedules from JSON data
    func importSchedules(from data: Data) throws -> [KilnSchedule] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let schedules = try decoder.decode([KilnSchedule].self, from: data)

        // Generate new IDs and update dates for all imported schedules
        return schedules.map { schedule in
            KilnSchedule(
                id: UUID(),
                name: schedule.name,
                technique: schedule.technique,
                dateCreated: Date(),
                dateModified: Date(),
                segments: schedule.segments.map { segment in
                    if let rampRate = segment.rampRate {
                        return KilnSegment(
                            id: UUID(),
                            targetTemperature: segment.targetTemperature,
                            rampRate: rampRate
                        )
                    } else if let holdTime = segment.holdTime {
                        return KilnSegment(
                            id: UUID(),
                            targetTemperature: segment.targetTemperature,
                            holdTime: holdTime
                        )
                    } else {
                        // Fallback for malformed data
                        return KilnSegment(
                            id: UUID(),
                            targetTemperature: segment.targetTemperature,
                            rampRate: 100
                        )
                    }
                },
                notes: schedule.notes,
                startTemperature: schedule.startTemperature,
                temperatureUnit: schedule.temperatureUnit
            )
        }
    }

    /// Imports a schedule from a file URL
    func importSchedule(from url: URL) throws -> KilnSchedule {
        let data = try Data(contentsOf: url)
        return try importSchedule(from: data)
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        return name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
    }
}

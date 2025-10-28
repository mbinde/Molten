//
//  KilnScheduleRowView.swift
//  Molten
//
//  Row component for displaying a kiln schedule in a list
//

import SwiftUI

struct KilnScheduleRowView: View {
    let schedule: KilnSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            scheduleHeader
            scheduleDetails
            if let notes = schedule.notes, !notes.isEmpty {
                scheduleNotes
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Makes the entire row tappable
    }

    // MARK: - View Components

    private var scheduleHeader: some View {
        HStack {
            // Schedule name
            Text(schedule.name)
                .font(.headline)
                .lineLimit(2)

            Spacer()

            // Duration badge
            durationBadge
        }
    }

    private var durationBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.caption2)
            Text(schedule.formattedDuration)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(techniqueColor.opacity(0.8))
        .clipShape(Capsule())
    }

    private var scheduleDetails: some View {
        HStack(spacing: 12) {
            // Technique badge
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                Text(schedule.technique.displayName)
                    .font(.caption)
            }
            .foregroundColor(techniqueColor)

            Spacer()

            // Segment count
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                Text("\(schedule.segments.count) segments")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            // Temperature unit
            Text(schedule.temperatureUnit.symbol)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var scheduleNotes: some View {
        Text(schedule.notes ?? "")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
    }

    // MARK: - Computed Properties

    private var techniqueColor: Color {
        switch schedule.technique {
        case .fusing, .fullFuse:
            return .orange
        case .tackFuse:
            return .yellow
        case .slumping:
            return .blue
        case .casting:
            return .purple
        case .annealing:
            return .green
        case .other:
            return .gray
        }
    }
}

#Preview("Single Schedule") {
    List {
        KilnScheduleRowView(
            schedule: KilnSchedule(
                name: "Full Fuse - Dichroic",
                technique: .fullFuse,
                segments: [
                    KilnSegment(targetTemperature: 1000, rampRate: 300),
                    KilnSegment(targetTemperature: 1000, holdTime: 15),
                    KilnSegment(targetTemperature: 1450, rampRate: 150),
                    KilnSegment(targetTemperature: 1450, holdTime: 30)
                ],
                notes: "Recommended for dichroic glass with base layer",
                startTemperature: 70,
                temperatureUnit: .fahrenheit
            )
        )
    }
}

#Preview("Multiple Schedules") {
    List {
        KilnScheduleRowView(
            schedule: KilnSchedule(
                name: "Full Fuse",
                technique: .fullFuse,
                segments: [
                    KilnSegment(targetTemperature: 1000, rampRate: 300),
                    KilnSegment(targetTemperature: 1450, holdTime: 30)
                ],
                startTemperature: 70,
                temperatureUnit: .fahrenheit
            )
        )

        KilnScheduleRowView(
            schedule: KilnSchedule(
                name: "Slump to Plate",
                technique: .slumping,
                segments: [
                    KilnSegment(targetTemperature: 1200, rampRate: 250),
                    KilnSegment(targetTemperature: 1200, holdTime: 20)
                ],
                notes: "Works well for 10-inch plates",
                startTemperature: 70,
                temperatureUnit: .fahrenheit
            )
        )

        KilnScheduleRowView(
            schedule: KilnSchedule(
                name: "Annealing Only",
                technique: .annealing,
                segments: [
                    KilnSegment(targetTemperature: 960, rampRate: 200),
                    KilnSegment(targetTemperature: 960, holdTime: 60)
                ],
                startTemperature: 70,
                temperatureUnit: .fahrenheit
            )
        )
    }
}

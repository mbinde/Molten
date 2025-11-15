//
//  KilnScheduleRowView.swift
//  Molten
//
//  Row component for displaying a kiln schedule in a list
//

import SwiftUI

struct KilnScheduleRowView: View {
    let schedule: KilnSchedule

    // Convert schedule to user's preferred temperature unit for display
    private var displaySchedule: KilnSchedule {
        schedule.converted(to: UserSettings.shared.preferredTemperatureUnit)
    }

    var body: some View {
        Group {
            if let description = schedule.description, !description.isEmpty {
                ListRowContainer(
                    header: { scheduleHeader },
                    details: { scheduleDetails },
                    footer: { scheduleNotes }
                )
            } else {
                ListRowContainer(
                    header: { scheduleHeader },
                    details: { scheduleDetails }
                )
            }
        }
    }

    // MARK: - View Components

    private var scheduleHeader: some View {
        HStack {
            // Schedule name
            Text(displaySchedule.name)
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
            Text(displaySchedule.formattedDuration)
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
            if let technique = displaySchedule.technique {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text(technique.displayName)
                        .font(.caption)
                }
                .foregroundColor(techniqueColor)
            }

            Spacer()

            // Segment count
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                Text("\(displaySchedule.segments.count) segments")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            // Temperature unit
            Text(displaySchedule.temperatureUnit.symbol)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var scheduleNotes: some View {
        Text(displaySchedule.description ?? "")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
    }

    // MARK: - Computed Properties

    private var techniqueColor: Color {
        switch displaySchedule.technique {
        case .fusing: return .orange
        case .casting: return .purple
        case .glassBlowing: return .blue
        case .flameworkinghard, .flameworkingsoft: return .red
        case .stainedGlass: return .green
        case .other, .none: return .gray
        }
    }
}

#Preview("Single Schedule") {
    List {
        KilnScheduleRowView(
            schedule: KilnSchedule(
                name: "Full Fuse - Dichroic",
                technique: .fusing,
                segments: [
                    KilnSegment(targetTemperature: 1000, rampRate: 300),
                    KilnSegment(targetTemperature: 1000, rampRate: 1, holdTime: 15),
                    KilnSegment(targetTemperature: 1450, rampRate: 150),
                    KilnSegment(targetTemperature: 1450, rampRate: 1, holdTime: 30)
                ],
                description: "Recommended for dichroic glass with base layer",
                temperatureUnit: .celsius
            )
        )
    }
}

#Preview("Multiple Schedules") {
    List {
        KilnScheduleRowView(
            schedule: KilnSchedule(
                name: "Full Fuse",
                technique: .fusing,
                segments: [
                    KilnSegment(targetTemperature: 1000, rampRate: 300),
                    KilnSegment(targetTemperature: 1450, rampRate: 1, holdTime: 30)
                ],
                description: nil,
                temperatureUnit: .celsius
            )
        )

        KilnScheduleRowView(
            schedule: KilnSchedule(
                name: "Slump to Plate",
                technique: .casting,
                segments: [
                    KilnSegment(targetTemperature: 1200, rampRate: 250),
                    KilnSegment(targetTemperature: 1200, rampRate: 1, holdTime: 20)
                ],
                description: "Works well for 10-inch plates",
                temperatureUnit: .celsius
            )
        )

        KilnScheduleRowView(
            schedule: KilnSchedule(
                name: "Annealing Only",
                technique: .other,
                segments: [
                    KilnSegment(targetTemperature: 960, rampRate: 200),
                    KilnSegment(targetTemperature: 960, rampRate: 1, holdTime: 60)
                ],
                description: nil,
                temperatureUnit: .celsius
            )
        )
    }
}

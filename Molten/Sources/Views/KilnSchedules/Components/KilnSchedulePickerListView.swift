//
//  KilnSchedulePickerListView.swift
//  Molten
//
//  Simple list view for picking a kiln schedule
//

import SwiftUI

struct KilnSchedulePickerListView: View {
    let kilnScheduleService: KilnScheduleService
    let onSelect: (KilnSchedule) -> Void

    @State private var schedules: [KilnSchedule] = []
    @State private var isLoading = false

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if schedules.isEmpty {
                Text("No kiln schedules available")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                ForEach(schedules) { schedule in
                    Button {
                        onSelect(schedule)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(schedule.name)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                HStack(spacing: 12) {
                                    if let technique = schedule.technique {
                                        IconTextBadge.flame(technique.displayName, color: .orange)
                                    }

                                    IconTextBadge.time(schedule.formattedDuration)

                                    IconTextBadge(
                                        systemImage: "list.number",
                                        text: "\(schedule.segments.count) segments",
                                        foregroundColor: .secondary,
                                        font: .caption,
                                        iconFont: .caption2
                                    )
                                }
                            }

                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("kiln_schedule_picker_\(schedule.name.lowercased().replacingOccurrences(of: " ", with: "_"))")
                }
            }
        }
        .task {
            await loadSchedules()
        }
    }

    private func loadSchedules() async {
        isLoading = true
        do {
            schedules = try await kilnScheduleService.getAllSchedules()
        } catch {
            print("Error loading kiln schedules: \(error)")
        }
        isLoading = false
    }
}

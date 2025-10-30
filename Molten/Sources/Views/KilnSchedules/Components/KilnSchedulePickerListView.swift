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
                    .foregroundColor(.secondary)
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
                                        HStack(spacing: 4) {
                                            Image(systemName: "flame.fill")
                                                .font(.caption2)
                                            Text(technique.displayName)
                                                .font(.caption)
                                        }
                                        .foregroundColor(.orange)
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.fill")
                                            .font(.caption2)
                                        Text(schedule.formattedDuration)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)

                                    HStack(spacing: 4) {
                                        Image(systemName: "list.number")
                                            .font(.caption2)
                                        Text("\(schedule.segments.count) segments")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                    }
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

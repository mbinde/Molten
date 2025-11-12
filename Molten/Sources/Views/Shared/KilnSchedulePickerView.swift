//
//  KilnSchedulePickerView.swift
//  Molten
//
//  Reusable picker component for selecting kiln schedules
//

import SwiftUI

struct KilnSchedulePickerView: View {
    @Binding var selectedScheduleId: UUID?
    let kilnScheduleService: KilnScheduleService

    @State private var schedules: [KilnSchedule] = []
    @State private var isLoading = false
    @State private var showingScheduleDetail = false

    var selectedSchedule: KilnSchedule? {
        schedules.first(where: { $0.id == selectedScheduleId })
    }

    // Convert schedules to user's preferred temperature unit for display
    private var displaySchedules: [KilnSchedule] {
        let preferredUnit = UserSettings.shared.preferredTemperatureUnit
        return schedules.map { $0.converted(to: preferredUnit) }
    }

    private var selectedDisplaySchedule: KilnSchedule? {
        displaySchedules.first(where: { $0.id == selectedScheduleId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading schedules...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if schedules.isEmpty {
                HStack {
                    Image(systemName: "flame")
                        .foregroundColor(.secondary)
                    Text("No kiln schedules available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Picker("Kiln Schedule", selection: $selectedScheduleId) {
                    Text("None").tag(nil as UUID?)
                    ForEach(displaySchedules) { schedule in
                        HStack {
                            Text(schedule.name)
                            Spacer()
                            Text(schedule.formattedDuration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(schedule.id as UUID?)
                    }
                }

                if let selected = selectedDisplaySchedule {
                    scheduleInfoCard(selected)
                }
            }
        }
        .task {
            await loadSchedules()
        }
    }

    private func scheduleInfoCard(_ schedule: KilnSchedule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let technique = schedule.technique {
                    Image(systemName: "flame.fill")
                        .foregroundColor(techniqueColor(technique))
                        .font(.caption)
                    Text(technique.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text(schedule.formattedDuration)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            HStack {
                Text("\(schedule.segments.count) segments")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showingScheduleDetail = true
                } label: {
                    Text("View Details")
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingScheduleDetail) {
            NavigationStack {
                KilnScheduleDetailView(
                    schedule: schedule,
                    kilnScheduleService: kilnScheduleService
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingScheduleDetail = false
                        }
                    }
                }
            }
        }
    }

    private func techniqueColor(_ technique: TechniqueType?) -> Color {
        switch technique {
        case .fusing: return .orange
        case .casting: return .purple
        case .glassBlowing: return .blue
        case .flameworkinghard, .flameworkingsoft: return .red
        case .stainedGlass: return .green
        case .other, .none: return .gray
        }
    }

    private func loadSchedules() async {
        isLoading = true
        do {
            schedules = try await kilnScheduleService.getAllSchedules()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            print("Error loading schedules: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    @Previewable @State var selectedId: UUID? = nil
    let deps = AppDependencies(forTesting: true)

    return Form {
        Section("Firing Schedule") {
            KilnSchedulePickerView(
                selectedScheduleId: $selectedId,
                kilnScheduleService: deps.kilnScheduleService
            )
        }
    }
}

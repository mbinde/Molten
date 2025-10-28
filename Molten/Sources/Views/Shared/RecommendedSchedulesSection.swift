//
//  RecommendedSchedulesSection.swift
//  Molten
//
//  Section showing recommended kiln schedules for a glass item
//

import SwiftUI

struct RecommendedSchedulesSection: View {
    let glassItemId: String
    let kilnScheduleService: KilnScheduleService

    @State private var recommendedSchedules: [KilnSchedule] = []
    @State private var isLoading = false
    @State private var selectedSchedule: KilnSchedule? = nil

    var body: some View {
        Section {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading schedules...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if recommendedSchedules.isEmpty {
                HStack {
                    Image(systemName: "flame")
                        .foregroundColor(.secondary)
                    Text("No recommended schedules")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            } else {
                ForEach(recommendedSchedules) { schedule in
                    Button {
                        selectedSchedule = schedule
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
                                        .foregroundColor(techniqueColor(technique))
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.fill")
                                            .font(.caption2)
                                        Text(schedule.formattedDuration)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Label("Recommended Kiln Schedules", systemImage: "flame")
        } footer: {
            if !recommendedSchedules.isEmpty {
                Text("These firing schedules are recommended for this glass type")
                    .font(.caption)
            }
        }
        .task {
            await loadRecommendedSchedules()
        }
        .sheet(item: $selectedSchedule) { schedule in
            NavigationStack {
                KilnScheduleDetailView(
                    schedule: schedule,
                    kilnScheduleService: kilnScheduleService
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            selectedSchedule = nil
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

    private func loadRecommendedSchedules() async {
        isLoading = true
        do {
            // Get all schedules and filter to ones recommended for this glass item
            // Note: This is a simplified implementation. In production, you'd query
            // the relationship directly through the repository
            let allSchedules = try await kilnScheduleService.getAllSchedules()
            // TODO: Add filtering based on glass item relationship
            // For now, showing all schedules as an example
            recommendedSchedules = []
        } catch {
            print("Error loading recommended schedules: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    let service = RepositoryFactory.createKilnScheduleService()
    return Form {
        RecommendedSchedulesSection(
            glassItemId: "bullseye-clear-0",
            kilnScheduleService: service
        )
    }
}

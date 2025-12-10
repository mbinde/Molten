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
    let glassItemRepository: GlassItemRepository
    var onSchedulesChanged: (([UUID]) -> Void)?

    @State private var recommendedSchedules: [KilnSchedule] = []
    @State private var isLoading = false
    @State private var selectedSchedule: KilnSchedule? = nil
    @State private var showingSchedulePicker = false

    var body: some View {
        Section {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading schedules...")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else if recommendedSchedules.isEmpty {
                HStack {
                    Image(systemName: "flame")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("No recommended schedules")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
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
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await removeSchedule(schedule)
                            }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .accessibilityIdentifier("recommended_schedules_remove")
                    }
                }

                // Add schedule button
                Button {
                    showingSchedulePicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Kiln Schedule")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color.accentColor)
                }
                .padding(.top, 8)
                .accessibilityIdentifier("recommended_schedules_add")
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
                        .accessibilityIdentifier("recommended_schedules_detail_done")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSchedulePicker) {
            NavigationStack {
                KilnSchedulePickerListView(
                    kilnScheduleService: kilnScheduleService,
                    onSelect: { schedule in
                        showingSchedulePicker = false
                        Task {
                            await addSchedule(schedule)
                        }
                    }
                )
                .navigationTitle("Add Kiln Schedule")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingSchedulePicker = false
                        }
                        .accessibilityIdentifier("recommended_schedules_picker_cancel")
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
            // Get recommended schedule IDs for this glass item
            let scheduleIds = try await glassItemRepository.getRecommendedSchedules(forGlassItem: glassItemId)

            // Fetch the actual schedules
            if !scheduleIds.isEmpty {
                let allSchedules = try await kilnScheduleService.getAllSchedules()
                recommendedSchedules = allSchedules.filter { scheduleIds.contains($0.id) }
            } else {
                recommendedSchedules = []
            }

            // Notify parent of the change
            onSchedulesChanged?(scheduleIds)
        } catch {
            print("Error loading recommended schedules: \(error)")
            recommendedSchedules = []
            onSchedulesChanged?([])
        }
        isLoading = false
    }

    private func addSchedule(_ schedule: KilnSchedule) async {
        do {
            try await glassItemRepository.addRecommendedSchedule(scheduleId: schedule.id, toGlassItem: glassItemId)
            await loadRecommendedSchedules()
        } catch {
            print("Error adding recommended schedule: \(error)")
        }
    }

    private func removeSchedule(_ schedule: KilnSchedule) async {
        do {
            try await glassItemRepository.removeRecommendedSchedule(scheduleId: schedule.id, fromGlassItem: glassItemId)
            await loadRecommendedSchedules()
        } catch {
            print("Error removing recommended schedule: \(error)")
        }
    }
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return Form {
        RecommendedSchedulesSection(
            glassItemId: "bullseye-clear-0",
            kilnScheduleService: deps.kilnScheduleService,
            glassItemRepository: deps.glassItemRepository
        )
    }
}

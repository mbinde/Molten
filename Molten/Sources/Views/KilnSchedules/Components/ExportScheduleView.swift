//
//  ExportScheduleView.swift
//  Molten
//
//  View for exporting/sharing kiln schedules
//

import SwiftUI

struct ExportScheduleView: View {
    let schedule: KilnSchedule
    @Environment(\.dismiss) private var dismiss

    @State private var exportService = KilnScheduleExportService()
    @State private var shareURL: URL?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // Convert schedule to user's preferred temperature unit for display
    private var displaySchedule: KilnSchedule {
        schedule.converted(to: UserSettings.shared.preferredTemperatureUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        IconTextBadge.flame(
                            displaySchedule.name,
                            color: techniqueColor
                        )
                        .font(.headline)

                        HStack(spacing: 16) {
                            IconTextBadge.chart("\(displaySchedule.segments.count) segments")
                            IconTextBadge.time(displaySchedule.formattedDuration)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Schedule to Export")
                }

                Section {
                    Button {
                        exportSchedule()
                    } label: {
                        Label("Export & Share", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Export Options")
                } footer: {
                    Text("Export this schedule as a JSON file that can be imported by other users or saved as a backup.")
                }
            }
            .navigationTitle("Export Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

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

    private func exportSchedule() {
        Task {
            do {
                let url = try await exportService.exportScheduleToFile(schedule)
                await MainActor.run {
                    shareURL = url
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to export schedule: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    let schedule = KilnSchedule(
        name: "Full Fuse - Standard",
        technique: .fusing,
        segments: [
            KilnSegment(targetTemperature: 1000, rampRate: 300),
            KilnSegment(targetTemperature: 1450, rampRate: 1, holdTime: 30)
        ],
        description: "Standard full fuse schedule",
        temperatureUnit: .celsius
    )
    ExportScheduleView(schedule: schedule)
}

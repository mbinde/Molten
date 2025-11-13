//
//  ImportScheduleView.swift
//  Molten
//
//  View for importing kiln schedules from JSON files
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportScheduleView: View {
    let kilnScheduleService: KilnScheduleService
    let onImportComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var exportService = KilnScheduleExportService()
    @State private var showingFilePicker = false
    @State private var importedSchedule: KilnSchedule?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSuccess = false

    // Convert imported schedule to user's preferred temperature unit for display
    private var displaySchedule: KilnSchedule? {
        importedSchedule?.converted(to: UserSettings.shared.preferredTemperatureUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Choose File to Import", systemImage: "doc.badge.plus")
                    }
                } header: {
                    Text("Import Schedule")
                } footer: {
                    Text("Select a JSON file containing a kiln schedule to import it into your library.")
                }

                if let schedule = displaySchedule {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(techniqueColor(schedule.technique))
                                Text(schedule.name)
                                    .font(.headline)
                            }

                            HStack(spacing: 16) {
                                DetailItem(icon: "chart.line.uptrend.xyaxis", text: "\(schedule.segments.count) segments")
                                DetailItem(icon: "clock.fill", text: schedule.formattedDuration)
                                DetailItem(icon: "thermometer", text: "\(schedule.temperatureUnit.symbol)")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)

                            if let description = schedule.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 4)

                        Button {
                            importSchedule()
                        } label: {
                            if isImporting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Importing...")
                                }
                            } else {
                                Label("Import This Schedule", systemImage: "square.and.arrow.down")
                            }
                        }
                        .disabled(isImporting)
                    } header: {
                        Text("Preview")
                    }
                }
            }
            .navigationTitle("Import Schedule")
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
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    onImportComplete?()
                    dismiss()
                }
            } message: {
                Text("Schedule imported successfully!")
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

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file"
                showingError = true
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            Task {
                do {
                    let schedule = try await exportService.importSchedule(from: url)
                    await MainActor.run {
                        importedSchedule = schedule
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to read schedule: \(error.localizedDescription)"
                        showingError = true
                    }
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func importSchedule() {
        guard let schedule = importedSchedule else { return }

        isImporting = true

        Task {
            do {
                _ = try await kilnScheduleService.createSchedule(schedule)
                await MainActor.run {
                    isImporting = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = "Failed to import schedule: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    let deps = AppDependencies(persistenceController: .createTestController())
    return ImportScheduleView(kilnScheduleService: deps.kilnScheduleService, onImportComplete: nil)
}

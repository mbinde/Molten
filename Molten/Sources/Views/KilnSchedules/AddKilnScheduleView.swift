//
//  AddKilnScheduleView.swift
//  Molten
//
//  Form for creating new kiln firing schedules
//

import SwiftUI

struct AddKilnScheduleView: View {
    @Environment(\.dismiss) private var dismiss

    let kilnScheduleService: KilnScheduleService
    let onScheduleCreated: ((KilnSchedule) -> Void)?

    // Form state
    @State private var name: String = ""
    @State private var selectedTechnique: TechniqueType? = .fusing
    @State private var temperatureUnit: TemperatureUnit
    @State private var description: String = ""
    @State private var segments: [KilnSegmentInput] = []

    // UI state
    @State private var showingAddSegment = false
    @State private var editingSegmentIndex: Int? = nil
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false

    init(kilnScheduleService: KilnScheduleService, onScheduleCreated: ((KilnSchedule) -> Void)? = nil) {
        self.kilnScheduleService = kilnScheduleService
        self.onScheduleCreated = onScheduleCreated
        // Default to user's preferred temperature unit
        _temperatureUnit = State(initialValue: UserSettings.shared.preferredTemperatureUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                scheduleInfoSection
                segmentsSection

                if !segments.isEmpty {
                    durationPreviewSection
                }
            }
            .navigationTitle("New Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddSegment) {
                AddSegmentView(
                    temperatureUnit: temperatureUnit,
                    onSave: { segment in
                        if let index = editingSegmentIndex {
                            segments[index] = segment
                            editingSegmentIndex = nil
                        } else {
                            segments.append(segment)
                        }
                    }
                )
            }
            .sheet(item: $editingSegmentIndex) { index in
                AddSegmentView(
                    segment: segments[index],
                    temperatureUnit: temperatureUnit,
                    onSave: { segment in
                        segments[index] = segment
                    }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    // MARK: - View Sections

    private var scheduleInfoSection: some View {
        Section("Schedule Information") {
            TextField("Schedule Name", text: $name)

            Picker("Technique", selection: $selectedTechnique) {
                Text("None").tag(nil as TechniqueType?)
                ForEach(TechniqueType.allCases, id: \.self) { technique in
                    Text(technique.displayName).tag(technique as TechniqueType?)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $description)
                    .frame(minHeight: 80)
            }
        }
    }


    private var segmentsSection: some View {
        Section {
            if segments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.6))

                    Text("No segments added")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Add ramp and hold segments to define your firing schedule")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    SegmentRowView(
                        segment: segment,
                        index: index,
                        temperatureUnit: temperatureUnit
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            segments.remove(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editingSegmentIndex = index
                            showingAddSegment = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onMove { from, to in
                    segments.move(fromOffsets: from, toOffset: to)
                }
            }

            Button {
                showingAddSegment = true
            } label: {
                Label("Add Segment", systemImage: "plus.circle.fill")
            }
        } header: {
            HStack {
                Text("Segments")
                Spacer()
                if !segments.isEmpty {
                    Text("\(segments.count) segment\(segments.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var durationPreviewSection: some View {
        Section {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.secondary)
                Text("Estimated Duration")
                    .foregroundColor(.secondary)
                Spacer()
                Text(calculateEstimatedDuration())
                    .fontWeight(.medium)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveSchedule()
            }
            .disabled(!isFormValid || isSaving)
        }
    }

    // MARK: - Helper Methods

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !segments.isEmpty
    }

    private func calculateEstimatedDuration() -> String {
        // Assume room temperature start (20°C)
        var currentTemp: Decimal = 20
        var totalSeconds: TimeInterval = 0

        for segment in segments {
            let segmentDuration = segment.calculateDuration(from: currentTemp)
            totalSeconds += segmentDuration
            currentTemp = segment.targetTemperature
        }

        let totalMinutes = Int(totalSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func saveSchedule() {
        guard isFormValid else { return }

        isSaving = true

        Task {
            do {
                // Convert segment inputs to domain models
                let domainSegments = segments.map { input -> KilnSegment in
                    if let rampRate = input.rampRate {
                        return KilnSegment(
                            targetTemperature: input.targetTemperature,
                            rampRate: rampRate
                        )
                    } else if let holdTime = input.holdTime {
                        return KilnSegment(
                            targetTemperature: input.targetTemperature,
                            holdTime: holdTime
                        )
                    } else {
                        // This shouldn't happen if validation is correct, but provide a fallback
                        return KilnSegment(
                            targetTemperature: input.targetTemperature,
                            rampRate: 100 // Default ramp rate
                        )
                    }
                }

                // Use fromInput to normalize temperatures to Celsius for storage
                let schedule = KilnSchedule.fromInput(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    technique: selectedTechnique,
                    segments: domainSegments,
                    description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                    inputUnit: temperatureUnit
                )

                let savedSchedule = try await kilnScheduleService.createSchedule(schedule)

                await MainActor.run {
                    onScheduleCreated?(savedSchedule)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Input model for building segments in the form
struct KilnSegmentInput: Identifiable {
    let id: UUID
    let targetTemperature: Decimal
    let rampRate: Decimal?  // Degrees per hour
    let holdTime: Decimal?  // Minutes

    var segmentType: KilnSegmentType {
        if rampRate != nil {
            return .ramp
        } else {
            return .hold
        }
    }

    init(id: UUID = UUID(), targetTemperature: Decimal, rampRate: Decimal? = nil, holdTime: Decimal? = nil) {
        self.id = id
        self.targetTemperature = targetTemperature
        self.rampRate = rampRate
        self.holdTime = holdTime
    }

    func calculateDuration(from currentTemperature: Decimal) -> TimeInterval {
        if let rampRate = rampRate {
            // Ramp segment: calculate time based on temperature change and rate
            let tempDelta = abs(targetTemperature - currentTemperature)
            let hours = tempDelta / rampRate
            return TimeInterval(truncating: hours * 3600 as NSNumber)
        } else if let holdTime = holdTime {
            // Hold segment: use the specified hold time
            return TimeInterval(truncating: holdTime * 60 as NSNumber)
        } else {
            return 0
        }
    }
}

// MARK: - Segment Row View

struct SegmentRowView: View {
    let segment: KilnSegmentInput
    let index: Int
    let temperatureUnit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Segment number badge
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(segmentColor))

                // Segment type badge
                HStack(spacing: 4) {
                    Image(systemName: segment.segmentType == .ramp ? "arrow.up.right" : "timer")
                        .font(.caption2)
                    Text(segment.segmentType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(segmentColor)

                Spacer()

                // Target temperature
                Text("\(segment.targetTemperature.formatted()) \(temperatureUnit.symbol)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Segment details
            HStack(spacing: 12) {
                Spacer()
                    .frame(width: 24) // Align with badge

                if let rampRate = segment.rampRate {
                    Text("Rate: \(rampRate.formatted()) \(temperatureUnit.symbol)/hr")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let holdTime = segment.holdTime {
                    Text("Hold: \(holdTime.formatted()) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var segmentColor: Color {
        segment.segmentType == .ramp ? .orange : .blue
    }
}

// Make Int identifiable for sheet presentation
extension Int: Identifiable {
    public var id: Int { self }
}

#Preview {
    let service = RepositoryFactory.createKilnScheduleService()
    return AddKilnScheduleView(kilnScheduleService: service)
}

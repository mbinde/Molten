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

                if validSegmentCount > 0 {
                    durationPreviewSection
                }

                descriptionSection
            }
            .navigationTitle("New Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                toolbarContent
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
        }
    }

    private var descriptionSection: some View {
        Section("Description") {
            TextEditor(text: $description)
                .frame(minHeight: 80)
        }
    }


    // Display segments include actual segments plus one empty row
    private var displaySegments: Binding<[KilnSegmentInput]> {
        Binding(
            get: {
                var allSegments = segments
                // Always append an empty segment for new input
                allSegments.append(KilnSegmentInput(
                    targetTemperature: 0,
                    rampRate: nil,
                    holdTime: nil
                ))
                return allSegments
            },
            set: { newSegments in
                // Filter out the empty placeholder when updating
                segments = newSegments.filter { segment in
                    segment.targetTemperature > 0 && (segment.rampRate != nil || segment.holdTime != nil)
                }
            }
        )
    }

    private var validSegmentCount: Int {
        segments.filter { $0.targetTemperature > 0 && ($0.rampRate != nil || $0.holdTime != nil) }.count
    }

    private var segmentsSection: some View {
        Section {
            ForEach(displaySegments.indices, id: \.self) { index in
                InlineSegmentRow(
                    segment: displaySegments[index],
                    index: index,
                    temperatureUnit: temperatureUnit,
                    onDelete: {
                        if index < segments.count {
                            segments.remove(at: index)
                        }
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if index < segments.count {
                        Button(role: .destructive) {
                            segments.remove(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .onMove { from, to in
                // Only allow moving actual segments, not the empty placeholder
                let filteredFrom = from.filter { $0 < segments.count }
                if !filteredFrom.isEmpty && to <= segments.count {
                    segments.move(fromOffsets: IndexSet(filteredFrom), toOffset: to)
                }
            }
        } header: {
            HStack {
                Text("Segments")
                Spacer()
                if validSegmentCount > 0 {
                    Text("\(validSegmentCount) segment\(validSegmentCount == 1 ? "" : "s")")
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
                // Filter out empty/incomplete segments before saving
                let validSegments = segments.filter { segment in
                    segment.targetTemperature > 0 && (segment.rampRate != nil || segment.holdTime != nil)
                }

                // Convert segment inputs to domain models
                let domainSegments = validSegments.map { input -> KilnSegment in
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

// MARK: - Inline Segment Editor

struct InlineSegmentRow: View {
    @Binding var segment: KilnSegmentInput
    let index: Int
    let temperatureUnit: TemperatureUnit
    let onDelete: () -> Void

    @State private var targetText: String
    @State private var rateText: String
    @State private var holdText: String
    @FocusState private var focusedField: Field?

    enum Field {
        case target, rate, hold
    }

    init(segment: Binding<KilnSegmentInput>, index: Int, temperatureUnit: TemperatureUnit, onDelete: @escaping () -> Void) {
        self._segment = segment
        self.index = index
        self.temperatureUnit = temperatureUnit
        self.onDelete = onDelete

        // Initialize text fields from segment
        let target = segment.wrappedValue.targetTemperature
        _targetText = State(initialValue: target > 0 ? target.description : "")
        _rateText = State(initialValue: segment.wrappedValue.rampRate?.description ?? "")
        _holdText = State(initialValue: segment.wrappedValue.holdTime != nil ? Self.formatTime(segment.wrappedValue.holdTime!) : "")
    }

    var body: some View {
        HStack(spacing: 8) {
            // Segment number
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(segmentColor))

            // Rate (degrees/hour)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rate °/hr")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("300", text: $rateText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .rate)
                    .onChange(of: rateText) { _, newValue in
                        updateRate(newValue)
                    }
            }
            .frame(maxWidth: .infinity)

            // Target temperature
            VStack(alignment: .leading, spacing: 2) {
                Text("Target")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("1450", text: $targetText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .target)
                    .onChange(of: targetText) { _, newValue in
                        updateTarget(newValue)
                    }
            }
            .frame(maxWidth: .infinity)

            // Hold time
            VStack(alignment: .leading, spacing: 2) {
                Text("Hold")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("30m", text: $holdText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .hold)
                    .onChange(of: holdText) { _, newValue in
                        updateHold(newValue)
                    }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
    }

    private var segmentColor: Color {
        if segment.rampRate != nil {
            return .orange  // Ramp
        } else if segment.holdTime != nil {
            return .blue  // Hold
        } else {
            return .gray  // Invalid/incomplete
        }
    }

    private func updateTarget(_ text: String) {
        if text.isEmpty {
            // Clear target
            segment = KilnSegmentInput(
                id: segment.id,
                targetTemperature: 0,
                rampRate: segment.rampRate,
                holdTime: segment.holdTime
            )
        } else if let value = Decimal(string: text), value >= 0 {
            segment = KilnSegmentInput(
                id: segment.id,
                targetTemperature: value,
                rampRate: segment.rampRate,
                holdTime: segment.holdTime
            )
        }
    }

    private func updateRate(_ text: String) {
        if text.isEmpty {
            // Clear rate
            segment = KilnSegmentInput(
                id: segment.id,
                targetTemperature: segment.targetTemperature,
                rampRate: nil,
                holdTime: segment.holdTime
            )
        } else if let value = Decimal(string: text), value > 0 {
            // If target is empty, set a default
            let target = segment.targetTemperature > 0 ? segment.targetTemperature : 1450
            segment = KilnSegmentInput(
                id: segment.id,
                targetTemperature: target,
                rampRate: value,
                holdTime: nil  // Clear hold when rate is set
            )
        }
    }

    private func updateHold(_ text: String) {
        if text.isEmpty {
            // Clear hold
            segment = KilnSegmentInput(
                id: segment.id,
                targetTemperature: segment.targetTemperature,
                rampRate: segment.rampRate,
                holdTime: nil
            )
        } else if let minutes = parseTimeInput(text) {
            // If target is empty, set a default
            let target = segment.targetTemperature > 0 ? segment.targetTemperature : 1450
            segment = KilnSegmentInput(
                id: segment.id,
                targetTemperature: target,
                rampRate: nil,  // Clear rate when hold is set
                holdTime: minutes
            )
        }
    }

    /// Parse time input like "13h", "30m", "1.5h" into minutes
    private func parseTimeInput(_ input: String) -> Decimal? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.hasSuffix("h") {
            // Hours
            let numberPart = String(trimmed.dropLast())
            guard let hours = Decimal(string: numberPart) else { return nil }
            return hours * 60
        } else if trimmed.hasSuffix("m") {
            // Minutes
            let numberPart = String(trimmed.dropLast())
            return Decimal(string: numberPart)
        } else {
            // Try parsing as minutes by default
            return Decimal(string: trimmed)
        }
    }

    /// Format time in minutes back to "Xh" or "Xm"
    private static func formatTime(_ minutes: Decimal) -> String {
        let minutesDouble = NSDecimalNumber(decimal: minutes).doubleValue
        if minutesDouble >= 60 {
            let hours = minutesDouble / 60
            if hours.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(hours))h"
            } else {
                return String(format: "%.1fh", hours)
            }
        } else {
            return "\(Int(minutesDouble))m"
        }
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

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
    @State private var selectedTechnique: TechniqueType?
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
        // Default to user's preferred temperature unit and last selected technique
        _temperatureUnit = State(initialValue: UserSettings.shared.preferredTemperatureUnit)
        _selectedTechnique = State(initialValue: UserSettings.shared.lastSelectedKilnTechnique)
    }

    var body: some View {
        NavigationStack {
            Form {
                scheduleInfoSection

                if validSegmentCount > 0 {
                    durationPreviewSection
                }

                segmentsSection
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
            .onChange(of: selectedTechnique) { _, newValue in
                // Remember the last selected technique for next time
                UserSettings.shared.lastSelectedKilnTechnique = newValue
            }

            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("Description and notes")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $description)
                    .frame(minHeight: 80)
            }
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
                    rampRate: 0,
                    holdTime: 0
                ))
                return allSegments
            },
            set: { newSegments in
                // Filter out completely empty segments (the placeholder)
                // Keep segments that have ANY data entered (even if incomplete)
                segments = newSegments.filter { segment in
                    segment.targetTemperature > 0 || segment.rampRate > 0 || segment.holdTime > 0
                }
            }
        )
    }

    private var validSegmentCount: Int {
        segments.filter { $0.targetTemperature > 0 && $0.rampRate > 0 }.count
    }

    private var segmentsSection: some View {
        Section {
            // Column headers
            HStack(spacing: 8) {
                Text("#")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rate °/hr")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Spacer for delete button column
                Text("")
                    .frame(width: 30)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            ForEach(displaySegments.indices, id: \.self) { index in
                InlineSegmentRow(
                    segment: displaySegments[index],
                    index: index,
                    temperatureUnit: temperatureUnit,
                    showLabels: false,
                    previousTarget: index > 0 ? displaySegments.wrappedValue[index - 1].targetTemperature : 20,
                    onDelete: {
                        if index < segments.count {
                            segments.remove(at: index)
                        } else {
                            // Clear the placeholder row
                            // Creating a new segment with zeros will be filtered out by setter,
                            // and a fresh placeholder will be added by getter
                            displaySegments.wrappedValue[index] = KilnSegmentInput(
                                targetTemperature: 0,
                                rampRate: 0,
                                holdTime: 0
                            )
                        }
                    }
                )
                .id(displaySegments.wrappedValue[index].id)
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

        // Only include segments that have both rate and target
        let validSegments = segments.filter { $0.targetTemperature > 0 && $0.rampRate > 0 }

        for segment in validSegments {
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
                // A valid segment must have both target temp and ramp rate > 0
                let validSegments = segments.filter { segment in
                    segment.targetTemperature > 0 && segment.rampRate > 0
                }

                // Convert segment inputs to domain models
                let domainSegments = validSegments.map { input -> KilnSegment in
                    KilnSegment(
                        targetTemperature: input.targetTemperature,
                        rampRate: input.rampRate,
                        holdTime: input.holdTime
                    )
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
    let rampRate: Decimal      // Degrees per hour (required)
    let holdTime: Decimal      // Minutes (default 0)

    init(id: UUID = UUID(), targetTemperature: Decimal, rampRate: Decimal, holdTime: Decimal = 0) {
        self.id = id
        self.targetTemperature = targetTemperature
        self.rampRate = rampRate
        self.holdTime = holdTime
    }

    func calculateDuration(from currentTemperature: Decimal) -> TimeInterval {
        var totalSeconds: TimeInterval = 0

        // Add ramp time (required)
        guard rampRate > 0 else { return 0 }

        // Special case: 9999 means use kiln's max rates from settings
        let actualRate: Decimal
        if rampRate == 9999 {
            let isHeatingUp = targetTemperature > currentTemperature
            if isHeatingUp {
                // Use appropriate heatup rate based on target temperature
                actualRate = UserSettings.getHeatupRate(forTemperature: targetTemperature)
            } else {
                // Use appropriate cooldown rate based on starting temperature
                actualRate = UserSettings.getCooldownRate(forTemperature: currentTemperature)
            }
        } else {
            actualRate = rampRate
        }

        let tempDelta = abs(targetTemperature - currentTemperature)
        let hours = tempDelta / actualRate
        totalSeconds += TimeInterval(truncating: hours * 3600 as NSNumber)

        // Add hold time (optional, may be 0)
        if holdTime > 0 {
            totalSeconds += TimeInterval(truncating: holdTime * 60 as NSNumber)
        }

        return totalSeconds
    }
}

// MARK: - Inline Segment Editor

struct InlineSegmentRow: View {
    @Binding var segment: KilnSegmentInput
    let index: Int
    let temperatureUnit: TemperatureUnit
    let showLabels: Bool
    let previousTarget: Decimal  // Previous segment's target (or room temp 20 for first segment)
    let onDelete: () -> Void

    @State private var targetText: String
    @State private var rateText: String
    @State private var holdText: String
    @FocusState private var focusedField: Field?

    enum Field {
        case target, rate, hold
    }

    init(segment: Binding<KilnSegmentInput>, index: Int, temperatureUnit: TemperatureUnit, showLabels: Bool = true, previousTarget: Decimal = 20, onDelete: @escaping () -> Void) {
        self._segment = segment
        self.index = index
        self.temperatureUnit = temperatureUnit
        self.showLabels = showLabels
        self.previousTarget = previousTarget
        self.onDelete = onDelete

        // Initialize text fields from segment
        let target = segment.wrappedValue.targetTemperature
        _targetText = State(initialValue: target > 0 ? target.description : "")
        _rateText = State(initialValue: segment.wrappedValue.rampRate > 0 ? segment.wrappedValue.rampRate.description : "")
        _holdText = State(initialValue: segment.wrappedValue.holdTime > 0 ? Self.formatTime(segment.wrappedValue.holdTime) : "")
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
            if showLabels {
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
            } else {
                TextField("300", text: $rateText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .rate)
                    .onChange(of: rateText) { _, newValue in
                        updateRate(newValue)
                    }
                    .frame(maxWidth: .infinity)
            }

            // Target temperature
            if showLabels {
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
            } else {
                TextField("1450", text: $targetText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .target)
                    .onChange(of: targetText) { _, newValue in
                        updateTarget(newValue)
                    }
                    .frame(maxWidth: .infinity)
            }

            // Hold time
            if showLabels {
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
            } else {
                TextField("30m", text: $holdText)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .hold)
                    .onChange(of: holdText) { _, newValue in
                        updateHold(newValue)
                    }
                    .frame(maxWidth: .infinity)
            }

            // Delete button (only show for actual segments, not the empty placeholder)
            if !showLabels && (segment.targetTemperature > 0 || segment.rampRate > 0) {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
                .frame(width: 30)
            } else if !showLabels {
                // Empty spacer for alignment when there's no delete button
                Color.clear
                    .frame(width: 30)
            }
        }
        .padding(.vertical, 4)
    }

    private var segmentColor: Color {
        let hasValidRate = segment.rampRate > 0
        let hasValidTarget = segment.targetTemperature > 0

        // A segment needs both rate and target to be valid
        if hasValidRate && hasValidTarget {
            // Red for heating up, blue for cooling down
            if segment.targetTemperature > previousTarget {
                return .red  // Heating up
            } else if segment.targetTemperature < previousTarget {
                return .blue  // Cooling down
            } else {
                return .orange  // Same temperature (holding)
            }
        } else {
            return .gray  // Incomplete
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
        let rateValue: Decimal
        if text.isEmpty {
            rateValue = 0  // Clear rate (marks segment as incomplete)
        } else if let value = Decimal(string: text), value > 0 {
            rateValue = value
        } else {
            return  // Invalid input, don't update
        }

        segment = KilnSegmentInput(
            id: segment.id,
            targetTemperature: segment.targetTemperature,
            rampRate: rateValue,
            holdTime: segment.holdTime
        )
    }

    private func updateHold(_ text: String) {
        let holdValue: Decimal
        if text.isEmpty {
            holdValue = 0  // Clear hold (no hold time)
        } else if let minutes = parseTimeInput(text) {
            holdValue = minutes
        } else {
            return  // Invalid input, don't update
        }

        segment = KilnSegmentInput(
            id: segment.id,
            targetTemperature: segment.targetTemperature,
            rampRate: segment.rampRate,
            holdTime: holdValue
        )
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

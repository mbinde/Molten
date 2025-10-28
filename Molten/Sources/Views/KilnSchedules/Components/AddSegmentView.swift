//
//  AddSegmentView.swift
//  Molten
//
//  Component for adding or editing a single kiln segment
//

import SwiftUI

struct AddSegmentView: View {
    @Environment(\.dismiss) private var dismiss

    let temperatureUnit: TemperatureUnit
    let onSave: (KilnSegmentInput) -> Void

    // Form state
    @State private var segmentType: KilnSegmentType = .ramp
    @State private var targetTemperature: String = ""
    @State private var rampRate: String = ""
    @State private var holdTime: String = ""

    // Editing state
    private let editingSegment: KilnSegmentInput?

    init(segment: KilnSegmentInput? = nil, temperatureUnit: TemperatureUnit, onSave: @escaping (KilnSegmentInput) -> Void) {
        self.editingSegment = segment
        self.temperatureUnit = temperatureUnit
        self.onSave = onSave

        // Initialize state from editing segment
        if let segment = segment {
            _segmentType = State(initialValue: segment.segmentType)
            _targetTemperature = State(initialValue: segment.targetTemperature.formatted())
            _rampRate = State(initialValue: segment.rampRate?.formatted() ?? "")
            _holdTime = State(initialValue: segment.holdTime?.formatted() ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                segmentTypeSection
                targetTemperatureSection

                switch segmentType {
                case .ramp:
                    rampRateSection
                case .hold:
                    holdTimeSection
                }

                explanationSection
            }
            .navigationTitle(editingSegment == nil ? "Add Segment" : "Edit Segment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarContent
            }
        }
    }

    // MARK: - View Sections

    private var segmentTypeSection: some View {
        Section {
            Picker("Segment Type", selection: $segmentType) {
                ForEach(KilnSegmentType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.systemImage)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Type")
        }
    }

    private var targetTemperatureSection: some View {
        Section {
            HStack {
                Text("Target Temperature")
                Spacer()
                TextField("1450", text: $targetTemperature)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text(temperatureUnit.symbol)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Target")
        } footer: {
            Text("The temperature the kiln should reach at the end of this segment")
        }
    }

    private var rampRateSection: some View {
        Section {
            HStack {
                Text("Ramp Rate")
                Spacer()
                TextField("300", text: $rampRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("\(temperatureUnit.symbol)/hr")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Rate")
        } footer: {
            Text("How quickly the kiln temperature should increase or decrease per hour")
        }
    }

    private var holdTimeSection: some View {
        Section {
            HStack {
                Text("Hold Time")
                Spacer()
                TextField("30", text: $holdTime)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text("min")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Duration")
        } footer: {
            Text("How long to maintain the target temperature")
        }
    }

    private var explanationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: segmentType.systemImage)
                        .foregroundColor(segmentType == .ramp ? .orange : .blue)
                    Text(segmentType == .ramp ? "Ramp Segment" : "Hold Segment")
                        .fontWeight(.semibold)
                }

                Text(segmentExplanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var segmentExplanation: String {
        switch segmentType {
        case .ramp:
            return "A ramp segment changes the kiln temperature from the current temperature to the target temperature at the specified rate. The duration is automatically calculated based on the temperature difference."
        case .hold:
            return "A hold segment maintains the current temperature for the specified duration. This is useful for soaking or annealing phases."
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
            Button(editingSegment == nil ? "Add" : "Save") {
                saveSegment()
            }
            .disabled(!isFormValid)
        }
    }

    // MARK: - Helper Methods

    private var isFormValid: Bool {
        guard !targetTemperature.isEmpty,
              Decimal(string: targetTemperature) != nil else {
            return false
        }

        switch segmentType {
        case .ramp:
            return !rampRate.isEmpty && Decimal(string: rampRate) != nil
        case .hold:
            return !holdTime.isEmpty && Decimal(string: holdTime) != nil
        }
    }

    private func saveSegment() {
        guard isFormValid,
              let targetTemp = Decimal(string: targetTemperature) else {
            return
        }

        let segment: KilnSegmentInput

        switch segmentType {
        case .ramp:
            guard let rate = Decimal(string: rampRate) else { return }
            segment = KilnSegmentInput(
                id: editingSegment?.id ?? UUID(),
                targetTemperature: targetTemp,
                rampRate: rate,
                holdTime: nil
            )
        case .hold:
            guard let time = Decimal(string: holdTime) else { return }
            segment = KilnSegmentInput(
                id: editingSegment?.id ?? UUID(),
                targetTemperature: targetTemp,
                rampRate: nil,
                holdTime: time
            )
        }

        onSave(segment)
        dismiss()
    }
}

// MARK: - Supporting Extensions

extension KilnSegmentType {
    var systemImage: String {
        switch self {
        case .ramp:
            return "arrow.up.right"
        case .hold:
            return "timer"
        }
    }
}

#Preview("Add Ramp") {
    AddSegmentView(temperatureUnit: .fahrenheit) { _ in }
}

#Preview("Add Hold") {
    @Previewable @State var type: KilnSegmentType = .hold
    return AddSegmentView(temperatureUnit: .fahrenheit) { _ in }
}

#Preview("Edit Segment") {
    let segment = KilnSegmentInput(
        targetTemperature: 1450,
        rampRate: 300,
        holdTime: nil
    )
    return AddSegmentView(segment: segment, temperatureUnit: .fahrenheit) { _ in }
}

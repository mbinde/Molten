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
    @State private var targetTemperature: String = ""
    @State private var rampRate: String = ""
    @State private var holdTime: String = "0"

    // Editing state
    private let editingSegment: KilnSegmentInput?

    init(segment: KilnSegmentInput? = nil, temperatureUnit: TemperatureUnit, onSave: @escaping (KilnSegmentInput) -> Void) {
        self.editingSegment = segment
        self.temperatureUnit = temperatureUnit
        self.onSave = onSave

        // Initialize state from editing segment
        if let segment = segment {
            _targetTemperature = State(initialValue: segment.targetTemperature.formatted())
            _rampRate = State(initialValue: segment.rampRate.formatted())
            _holdTime = State(initialValue: segment.holdTime > 0 ? segment.holdTime.formatted() : "0")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                targetTemperatureSection
                rampRateSection
                holdTimeSection
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
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.orange)
                    Text("Segment")
                        .fontWeight(.semibold)
                }

                Text(segmentExplanation)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var segmentExplanation: String {
        "A segment ramps the kiln to the target temperature at the specified rate, then optionally holds that temperature for the specified duration. Set hold time to 0 if no hold is needed."
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .accessibilityIdentifier("add_segment_cancel")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(editingSegment == nil ? "Add" : "Save") {
                saveSegment()
            }
            .disabled(!isFormValid)
            .accessibilityIdentifier("add_segment_save")
        }
    }

    // MARK: - Helper Methods

    private var isFormValid: Bool {
        guard !targetTemperature.isEmpty,
              Decimal(string: targetTemperature) != nil,
              !rampRate.isEmpty,
              Decimal(string: rampRate) != nil else {
            return false
        }
        return true
    }

    private func saveSegment() {
        guard isFormValid,
              let targetTemp = Decimal(string: targetTemperature),
              let rate = Decimal(string: rampRate) else {
            return
        }

        let hold = Decimal(string: holdTime) ?? 0

        let segment = KilnSegmentInput(
            id: editingSegment?.id ?? UUID(),
            targetTemperature: targetTemp,
            rampRate: rate,
            holdTime: hold
        )

        onSave(segment)
        dismiss()
    }
}

// MARK: - Previews

#Preview("Add Segment") {
    AddSegmentView(temperatureUnit: .fahrenheit) { _ in }
}

#Preview("Edit Segment") {
    let segment = KilnSegmentInput(
        targetTemperature: 1450,
        rampRate: 300,
        holdTime: 15
    )
    return AddSegmentView(segment: segment, temperatureUnit: .fahrenheit) { _ in }
}

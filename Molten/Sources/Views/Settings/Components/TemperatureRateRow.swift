//
//  TemperatureRateRow.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct TemperatureRateRow: View {
    let label: String
    @Binding var value: Decimal
    let placeholder: String
    @State private var textValue: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: $textValue)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
                .multilineTextAlignment(.trailing)
                .onChange(of: textValue) { _, newValue in
                    if let decimal = Decimal(string: newValue), decimal > 0 {
                        value = decimal
                    }
                }
                .onAppear {
                    textValue = value.description
                }
        }
    }
}

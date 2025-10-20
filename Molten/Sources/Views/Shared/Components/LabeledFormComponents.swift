//
//  LabeledFormComponents.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Reusable labeled form field components
//

import SwiftUI

// MARK: - LabeledField

/// Generic labeled field wrapper that provides consistent label styling
/// Eliminates duplication of VStack { Text + Field } pattern across forms
struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
            content
        }
    }
}

// MARK: - DecimalInputField

/// Specialized text field for decimal number input (quantity, price, etc.)
/// Eliminates duplication of TextField + .keyboardType(.decimalPad) pattern
struct DecimalInputField: View {
    let placeholder: String
    @Binding var value: String
    let width: CGFloat?

    init(placeholder: String = "0", value: Binding<String>, width: CGFloat? = nil) {
        self.placeholder = placeholder
        self._value = value
        self.width = width
    }

    var body: some View {
        TextField(placeholder, text: $value)
            #if canImport(UIKit)
            .keyboardType(.decimalPad)
            #endif
            .textFieldStyle(.roundedBorder)
            .modifier(ConditionalWidthModifier(width: width))
    }
}

/// Helper modifier to conditionally apply frame width
private struct ConditionalWidthModifier: ViewModifier {
    let width: CGFloat?

    func body(content: Content) -> some View {
        if let width = width {
            content.frame(width: width)
        } else {
            content
        }
    }
}

// MARK: - LabeledDecimalField

/// Convenience combination of LabeledField + DecimalInputField
struct LabeledDecimalField: View {
    let label: String
    @Binding var value: String
    let placeholder: String
    let width: CGFloat?

    init(_ label: String, value: Binding<String>, placeholder: String = "0", width: CGFloat? = nil) {
        self.label = label
        self._value = value
        self.placeholder = placeholder
        self.width = width
    }

    var body: some View {
        LabeledField(label) {
            DecimalInputField(placeholder: placeholder, value: $value, width: width)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var name = ""
    @Previewable @State var quantity = ""
    @Previewable @State var price = ""
    @Previewable @State var type = "rod"

    return Form {
        Section("LabeledField Examples") {
            // Basic usage with text field
            LabeledField("Name") {
                TextField("Enter name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // With picker
            LabeledField("Type") {
                Picker("Type", selection: $type) {
                    Text("Rod").tag("rod")
                    Text("Sheet").tag("sheet")
                }
                .pickerStyle(.menu)
            }
        }

        Section("DecimalInputField Examples") {
            // Standalone decimal input
            LabeledField("Quantity") {
                DecimalInputField(value: $quantity)
            }

            // Labeled decimal field (convenience)
            LabeledDecimalField("Price", value: $price, placeholder: "0.00")

            // Decimal input with fixed width
            LabeledField("Amount") {
                HStack {
                    DecimalInputField(value: $quantity, width: 80)
                    Text("units")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

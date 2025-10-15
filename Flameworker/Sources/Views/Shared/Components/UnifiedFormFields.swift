//
//  UnifiedFormFields.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI
import Foundation

// MARK: - Generic Form Field Protocol

protocol FormFieldConfiguration {
    associatedtype Value: Equatable
    var title: String { get }
    var placeholder: String { get }
    var keyboardType: UIKeyboardType { get }
    var textInputAutocapitalization: TextInputAutocapitalization { get }
    func formatValue(_ value: Value) -> String
    func parseValue(_ text: String) -> Value?
}

// MARK: - Unified Form Field Component

struct UnifiedFormField<Config: FormFieldConfiguration>: View {
    let config: Config
    @Binding var value: Config.Value
    @State private var text: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !config.title.isEmpty {
                Text(config.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            TextField(config.placeholder, text: $text)
                .keyboardType(config.keyboardType)
                .textInputAutocapitalization(config.textInputAutocapitalization)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { _, newValue in
                    if let parsedValue = config.parseValue(newValue) {
                        value = parsedValue
                    }
                }
                .onAppear {
                    text = config.formatValue(value)
                }
                .onChange(of: value) { _, newValue in
                    text = config.formatValue(newValue)
                }
        }
    }
}

// MARK: - Multiline Form Field

struct UnifiedMultilineFormField<Config: FormFieldConfiguration>: View where Config.Value == String {
    let config: Config
    @Binding var value: Config.Value
    let lineLimit: ClosedRange<Int>
    
    init(config: Config, value: Binding<Config.Value>, lineLimit: ClosedRange<Int> = 2...4) {
        self.config = config
        self._value = value
        self.lineLimit = lineLimit
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !config.title.isEmpty {
                Text(config.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            TextField(config.placeholder, text: $value, axis: .vertical)
                .lineLimit(lineLimit)
                .textInputAutocapitalization(config.textInputAutocapitalization)
        }
    }
}

// MARK: - Specific Field Configurations

struct CountFieldConfig: FormFieldConfiguration {
    let title: String
    let placeholder: String = "Amount"
    let keyboardType: UIKeyboardType = .decimalPad
    let textInputAutocapitalization: TextInputAutocapitalization = .never
    
    func formatValue(_ value: String) -> String {
        return value
    }
    
    func parseValue(_ text: String) -> String? {
        return text
    }
}

struct PriceFieldConfig: FormFieldConfiguration {
    let title: String
    let placeholder: String = "0.00"
    let keyboardType: UIKeyboardType = .decimalPad
    let textInputAutocapitalization: TextInputAutocapitalization = .never
    
    func formatValue(_ value: String) -> String {
        return value
    }
    
    func parseValue(_ text: String) -> String? {
        return text
    }
}

struct NotesFieldConfig: FormFieldConfiguration {
    let title: String = "Notes"
    let placeholder: String = "Notes"
    let keyboardType: UIKeyboardType = .default
    let textInputAutocapitalization: TextInputAutocapitalization = .sentences
    
    func formatValue(_ value: String) -> String {
        return value
    }
    
    func parseValue(_ text: String) -> String? {
        return text
    }
}

// MARK: - Enhanced Picker Component

struct UnifiedPickerField<T>: View where T: CaseIterable, T: Hashable, T: Identifiable, T.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: T
    let displayProvider: (T) -> String
    let imageProvider: ((T) -> String)?
    let colorProvider: ((T) -> Color)?
    let style: PickerStyle
    
    enum PickerStyle {
        case segmented, menu, navigationLink
    }
    
    init(
        title: String,
        selection: Binding<T>,
        displayProvider: @escaping (T) -> String,
        imageProvider: ((T) -> String)? = nil,
        colorProvider: ((T) -> Color)? = nil,
        style: PickerStyle = .menu
    ) {
        self.title = title
        self._selection = selection
        self.displayProvider = displayProvider
        self.imageProvider = imageProvider
        self.colorProvider = colorProvider
        self.style = style
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Group {
                switch style {
                case .segmented:
                    segmentedPicker
                case .menu:
                    menuPicker
                case .navigationLink:
                    navigationPicker
                }
            }
        }
    }
    
    @ViewBuilder
    private var segmentedPicker: some View {
        Picker(title, selection: $selection) {
            ForEach(Array(T.allCases), id: \.self) { item in
                pickerLabel(for: item).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    private var menuPicker: some View {
        Picker(title, selection: $selection) {
            ForEach(Array(T.allCases), id: \.self) { item in
                pickerLabel(for: item).tag(item)
            }
        }
        .pickerStyle(.menu)
    }
    
    @ViewBuilder
    private var navigationPicker: some View {
        NavigationLink(destination: pickerNavigation) {
            HStack {
                pickerLabel(for: selection)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var pickerNavigation: some View {
        List {
            ForEach(Array(T.allCases), id: \.self) { item in
                Button(action: {
                    selection = item
                }) {
                    HStack {
                        pickerLabel(for: item)
                        Spacer()
                        if selection == item {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
    }
    
    @ViewBuilder
    private func pickerLabel(for item: T) -> some View {
        HStack {
            if let imageProvider = imageProvider {
                Image(systemName: imageProvider(item))
                    .foregroundColor(colorProvider?(item) ?? .primary)
            }
            Text(displayProvider(item))
        }
    }
}

// MARK: - Combined Input Components

struct CountUnitsInputRow: View {
    @Binding var count: String
    @Binding var units: CatalogUnits
    
    var body: some View {
        HStack(spacing: 12) {
            UnifiedFormField(
                config: CountFieldConfig(title: ""),
                value: $count
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            
            UnifiedPickerField(
                title: "",
                selection: $units,
                displayProvider: { $0.displayName },
                style: .menu
            )
            .frame(width: 120)
        }
    }
}

struct CountUnitsTypeInputRow: View {
    @Binding var count: String
    @Binding var units: CatalogUnits
    @Binding var selectedType: String // Changed from InventoryItemType to String
    
    let availableTypes = ["rod", "sheet", "frit", "stringer", "powder", "other"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UnifiedFormField(
                config: CountFieldConfig(title: "Count"),
                value: $count
            )
            
            UnifiedPickerField(
                title: "Units",
                selection: $units,
                displayProvider: { $0.displayName },
                style: .segmented
            )
            
            // Simple picker for inventory types
            VStack(alignment: .leading, spacing: 4) {
                Text("Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Type", selection: $selectedType) {
                    ForEach(availableTypes, id: \.self) { type in
                        Text(type.capitalized).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

struct InventoryTypeSegmentedPicker: View {
    @Binding var selectedType: String // Changed from InventoryItemType to String
    var iconOnly: Bool = false
    
    let availableTypes = ["rod", "sheet", "frit", "stringer", "powder", "other"]
    
    var body: some View {
        Picker("Type", selection: $selectedType) {
            ForEach(availableTypes, id: \.self) { type in
                if iconOnly {
                    Image(systemName: iconForType(type))
                        .foregroundColor(colorForType(type))
                        .tag(type)
                } else {
                    HStack {
                        Image(systemName: iconForType(type))
                            .foregroundColor(colorForType(type))
                        Text(type.capitalized)
                    }
                    .tag(type)
                }
            }
        }
        .pickerStyle(.segmented)
    }
    
    // Helper functions for type-based styling
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "rod": return "rectangle.stack"
        case "sheet": return "rectangle.3.offgrid"
        case "frit": return "circle.grid.cross"
        case "stringer": return "line.diagonal"
        case "powder": return "aqi.medium"
        default: return "square.grid.2x2"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "rod": return .blue
        case "sheet": return .green
        case "frit": return .orange
        case "stringer": return .purple
        case "powder": return .red
        default: return .gray
        }
    }
}

struct InventoryTypeVerticalPicker: View {
    @Binding var selectedType: String // Changed from InventoryItemType to String
    var iconOnly: Bool = true
    var spacing: CGFloat = 8
    
    let availableTypes = ["rod", "sheet", "frit"] // Simplified for vertical picker

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(availableTypes, id: \.self) { type in
                Button(action: { selectedType = type }) {
                    HStack(spacing: 8) {
                        Image(systemName: iconForType(type))
                            .foregroundColor(selectedType == type ? .white : colorForType(type))
                        if !iconOnly {
                            Text(type.capitalized)
                                .foregroundColor(selectedType == type ? .white : .primary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, iconOnly ? 6 : 10)
                    .frame(maxWidth: iconOnly ? nil : .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedType == type ? colorForType(type) : Color(.systemGray5))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // Helper functions for type-based styling
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "rod": return "rectangle.stack"
        case "sheet": return "rectangle.3.offgrid"
        case "frit": return "circle.grid.cross"
        default: return "square.grid.2x2"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "rod": return .blue
        case "sheet": return .green
        case "frit": return .orange
        default: return .gray
        }
    }
}

struct PriceInputField: View {
    @Binding var price: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Unit price")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("$")
                    .foregroundColor(.secondary)
                
                UnifiedFormField(
                    config: PriceFieldConfig(title: ""),
                    value: $price
                )
                .frame(maxWidth: 120)
                
                Spacer()
            }
            
            Text("Price per unit (e.g. per rod or per pound)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct NotesInputField: View {
    @Binding var notes: String
    
    var body: some View {
        UnifiedMultilineFormField(
            config: NotesFieldConfig(),
            value: $notes
        )
    }
}

struct DateAddedInputField: View {
    @Binding var dateAdded: Date
    
    var body: some View {
        DatePicker("Date Added", selection: $dateAdded, displayedComponents: [.date])
            .datePickerStyle(.compact)
    }
}


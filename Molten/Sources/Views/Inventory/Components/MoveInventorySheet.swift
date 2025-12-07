//
//  MoveInventorySheet.swift
//  Molten
//
//  Sheet for moving inventory to a different location
//

import SwiftUI

/// Sheet for selecting a destination location and quantity to move inventory
struct MoveInventorySheet: View {
    let sourceKey: InventoryGroupKey
    let itemName: String
    let availableQuantity: Double
    let onMove: (String?, Int) -> Void  // destination location (nil = no location), quantity to move

    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastMoveDestination") private var lastDestination: String = ""
    @State private var selectedDestination: String? = nil
    @State private var customDestination: String = ""
    @State private var quantityToMove: Int = 1
    @State private var existingLocations: [String] = []
    @State private var isLoading = true

    private let storageLocationDefinitionRepository: StorageLocationDefinitionRepository

    init(
        sourceKey: InventoryGroupKey,
        itemName: String,
        availableQuantity: Double,
        storageLocationDefinitionRepository: StorageLocationDefinitionRepository,
        onMove: @escaping (String?, Int) -> Void
    ) {
        self.sourceKey = sourceKey
        self.itemName = itemName
        self.availableQuantity = availableQuantity
        self.storageLocationDefinitionRepository = storageLocationDefinitionRepository
        self.onMove = onMove
    }

    /// Convenience init using AppDependencies
    init(
        sourceKey: InventoryGroupKey,
        itemName: String,
        availableQuantity: Double,
        deps: AppDependencies = .shared,
        onMove: @escaping (String?, Int) -> Void
    ) {
        self.init(
            sourceKey: sourceKey,
            itemName: itemName,
            availableQuantity: availableQuantity,
            storageLocationDefinitionRepository: deps.storageLocationDefinitionRepository,
            onMove: onMove
        )
    }

    private var maxQuantity: Int {
        Int(availableQuantity)
    }

    private var sourceLocationDisplay: String {
        sourceKey.location ?? "No location"
    }

    private var typeDisplay: String {
        var parts = [GlassTerminologySettings.shared.displayName(for: sourceKey.type).capitalized]
        if let sub = sourceKey.subtype, !sub.isEmpty {
            parts.append(sub.capitalized)
        }
        if let subsub = sourceKey.subsubtype, !subsub.isEmpty {
            parts.append(subsub.capitalized)
        }
        return parts.joined(separator: " · ")
    }

    /// Locations available to move to (excludes current location)
    private var availableLocations: [String] {
        existingLocations.filter { $0 != sourceKey.location }
    }

    /// The effective destination (selected, custom, or nil for "no location")
    private var effectiveDestination: String? {
        if selectedDestination == "__none__" {
            return nil
        }
        if selectedDestination == "__custom__" {
            let trimmed = customDestination.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        return selectedDestination
    }

    /// Display text for the current destination
    private var destinationDisplayText: String {
        if selectedDestination == "__none__" {
            return "No location"
        }
        if selectedDestination == "__custom__" {
            let trimmed = customDestination.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "Enter location..." : trimmed
        }
        return selectedDestination ?? "Select..."
    }

    /// Whether the Move button should be enabled
    private var canMove: Bool {
        if selectedDestination == nil { return false }
        if selectedDestination == "__custom__" {
            return !customDestination.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            List {
                // Info section with From/To
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(itemName)
                            .font(DesignSystem.Typography.formLabel)
                            .fontWeight(DesignSystem.FontWeight.semibold)
                        Text(typeDisplay)
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    HStack {
                        Text("From")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(width: 40, alignment: .leading)
                        Text(sourceLocationDisplay)
                            .fontWeight(DesignSystem.FontWeight.medium)
                        Spacer()
                    }

                    if isLoading {
                        HStack {
                            Text("To")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 40, alignment: .leading)
                            ProgressView()
                                .scaleEffect(0.8)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Text("To")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(width: 40, alignment: .leading)

                            Picker("", selection: $selectedDestination) {
                                Text("Select...").tag(nil as String?)

                                ForEach(availableLocations, id: \.self) { location in
                                    Text(location).tag(location as String?)
                                }

                                if sourceKey.location != nil {
                                    Text("No location").tag("__none__" as String?)
                                }

                                Text("New location...").tag("__custom__" as String?)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()

                            Spacer()
                        }

                        // Show text field when custom is selected
                        if selectedDestination == "__custom__" {
                            HStack {
                                Text("")
                                    .frame(width: 40, alignment: .leading)
                                TextField("Enter new location", text: $customDestination)
                                    .textInputAutocapitalization(.words)
                            }
                        }
                    }
                }

                // Quantity section with Move button
                Section("Quantity available: \(maxQuantity)") {
                    HStack {
                        Button(action: {
                            if quantityToMove > 1 {
                                quantityToMove -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(quantityToMove > 1 ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .disabled(quantityToMove <= 1)

                        Text("\(quantityToMove)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(minWidth: 50)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            if quantityToMove < maxQuantity {
                                quantityToMove += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(quantityToMove < maxQuantity ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .disabled(quantityToMove >= maxQuantity)

                        Spacer()

                        Button(action: {
                            performMove()
                        }) {
                            Text("Move")
                                .fontWeight(DesignSystem.FontWeight.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(canMove ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        }
                        .disabled(!canMove)
                    }
                }
            }
            .navigationTitle("Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadLocations()
                // Pre-select last used destination if available and valid
                if !lastDestination.isEmpty && lastDestination != sourceKey.location {
                    if availableLocations.contains(lastDestination) {
                        selectedDestination = lastDestination
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func loadLocations() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let definitions = try await storageLocationDefinitionRepository.fetchAll()
            await MainActor.run {
                existingLocations = definitions.map { $0.name }.sorted()
            }
        } catch {
            print("Error loading locations: \(error)")
        }
    }

    private func performMove() {
        // Save selected destination to UserDefaults for next time
        if let dest = effectiveDestination {
            lastDestination = dest
        }

        onMove(effectiveDestination, quantityToMove)
        dismiss()
    }
}

#Preview {
    MoveInventorySheet(
        sourceKey: InventoryGroupKey(
            location: "Studio",
            type: "rod",
            subtype: nil,
            subsubtype: nil
        ),
        itemName: "Bullseye Red Opal",
        availableQuantity: 12,
        onMove: { destination, quantity in
            print("Moving \(quantity) to: \(destination ?? "no location")")
        }
    )
}

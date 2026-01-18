//
//  BundledFlagsChipsView.swift
//  Molten
//
//  Displays bundled catalog flags as tag-style chips.
//  This component can be used anywhere glass item descriptions are displayed.
//

import SwiftUI

/// Displays bundled catalog flags as styled chips/tags
/// Use this component to show flags wherever glass item descriptions are shown
struct BundledFlagsChipsView: View {
    let itemStableId: String
    let repository: CatalogFlagBundledRepository

    @State private var flags: [CatalogFlagBundledModel] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !flags.isEmpty {
                FlowLayout(spacing: DesignSystem.Spacing.xs) {
                    ForEach(flags) { flag in
                        flagChip(for: flag)
                    }
                }
            }
        }
        .task(id: itemStableId) {
            await loadFlags()
        }
    }

    // MARK: - Private Methods

    private func loadFlags() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            flags = try await repository.fetchFlags(for: itemStableId)
        } catch {
            // No flags is fine, just leave empty
        }
    }

    @ViewBuilder
    private func flagChip(for flag: CatalogFlagBundledModel) -> some View {
        Text(displayText(for: flag))
            .font(DesignSystem.Typography.listItemCaption)
            .fontWeight(.semibold)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(DesignSystem.Colors.tintTeal)
            .foregroundColor(DesignSystem.Colors.accentSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
    }

    /// Format flag display text, respecting user preferences for temperature units
    private func displayText(for flag: CatalogFlagBundledModel) -> String {
        guard let key = flag.typedFlagKey else {
            return flag.flag_key
        }

        // Handle numeric values with unit conversion
        if let numeric = flag.flag_numeric {
            switch key {
            case .customAnnealTemp, .maxWorkingTemp:
                // Temperature flags - convert based on user preference
                // Values are stored in Fahrenheit
                let tempUnit = UserSettings.shared.preferredTemperatureUnit
                let displayValue: Double
                if tempUnit == .celsius {
                    displayValue = (numeric - 32) * 5 / 9
                } else {
                    displayValue = numeric
                }
                let formatted = displayValue.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", displayValue)
                    : String(format: "%.0f", displayValue)
                return "\(key.displayName): \(formatted)\(tempUnit.symbol)"

            case .holdTime:
                // Time in minutes - no conversion needed
                let formatted = numeric.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", numeric)
                    : String(format: "%.1f", numeric)
                return "\(key.displayName): \(formatted)min"

            case .rampDownRate:
                // Rate in °F/hr - convert if needed
                let tempUnit = UserSettings.shared.preferredTemperatureUnit
                let displayValue: Double
                let unitSymbol: String
                if tempUnit == .celsius {
                    displayValue = numeric * 5 / 9  // Convert rate (no offset needed)
                    unitSymbol = "°C/hr"
                } else {
                    displayValue = numeric
                    unitSymbol = "°F/hr"
                }
                let formatted = displayValue.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", displayValue)
                    : String(format: "%.1f", displayValue)
                return "\(key.displayName): \(formatted)\(unitSymbol)"

            default:
                break
            }
        }

        return key.displayName
    }
}

// MARK: - Convenience Initializer

extension BundledFlagsChipsView {
    /// Initialize using AppDependencies (convenience for most views)
    init(itemStableId: String, deps: AppDependencies = .shared) {
        self.itemStableId = itemStableId
        self.repository = deps.catalogFlagBundledRepository
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Sample Flags Display")
            .font(.headline)

        BundledFlagsChipsView(
            itemStableId: "sample-item-id"
        )
    }
    .padding()
}

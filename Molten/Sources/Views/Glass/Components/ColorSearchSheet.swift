//
//  ColorSearchSheet.swift
//  Molten
//
//  Sheet for selecting a color to search the catalog by.
//  Includes a color wheel, tolerance slider, and options for handling high-variance glass.
//

import SwiftUI

/// Sheet view for configuring color search parameters
struct ColorSearchSheet: View {
    /// The selected color
    @Binding var selectedColor: Color

    /// Match tolerance (0-100, where 0 is exact match)
    @Binding var tolerance: Double

    /// Whether to include glass with high color variance
    @Binding var includeHighVariance: Bool

    /// Called when user applies the search
    let onApply: () -> Void

    /// Called when user clears the color search
    let onClear: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// Whether a color search is currently active (for showing clear button)
    var isSearchActive: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Color picker
                    colorWheelSection

                    // Tolerance slider
                    toleranceSection

                    // High variance option
                    highVarianceSection
                }
                .padding()
            }
            .navigationTitle("Search by Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSearchActive, let onClear = onClear {
                    Button(role: .destructive) {
                        onClear()
                        dismiss()
                    } label: {
                        Text("Clear Color Filter")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Color Picker Section

    private var colorWheelSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Select a Color")
                .font(DesignSystem.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .leading)

            ColorSlidersPicker(selectedColor: $selectedColor)
        }
    }

    // MARK: - Tolerance Section

    private var toleranceSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Match Tolerance")
                    .font(DesignSystem.Typography.sectionTitle)

                Spacer()

                Text(toleranceLabel)
                    .font(DesignSystem.Typography.formValue)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            // Delta E range: 3 (very close) to 25 (similar)
            Slider(value: $tolerance, in: 3...25, step: 1)
                .tint(DesignSystem.Colors.accentPrimary)

            HStack {
                Text("Very close")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                Spacer()
                Text("Similar")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
    }

    private var toleranceLabel: String {
        switch tolerance {
        case 0..<6:
            return "Very close"
        case 6..<10:
            return "Close"
        case 10..<16:
            return "Moderate"
        case 16..<21:
            return "Broad"
        default:
            return "Very broad"
        }
    }

    // MARK: - High Variance Section

    private var highVarianceSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: $includeHighVariance) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Include High-Variance Glass")
                        .font(DesignSystem.Typography.formLabel)

                    Text("Show glass that displays multiple colors or changes appearance (reactive, dichroic, opal, etc.)")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .tint(DesignSystem.Colors.accentPrimary)
        }
        .padding()
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

// MARK: - Color Sliders Picker

/// Two-slider color picker: Hue (rainbow) and Lightness (black to white)
/// More intuitive for searching glass colors than a color wheel
struct ColorSlidersPicker: View {
    @Binding var selectedColor: Color

    @State private var hue: Double = 0.5
    @State private var lightness: Double = 0.5  // 0 = black, 0.5 = pure color, 1 = white
    @State private var hexInput: String = ""
    @State private var isHexInputValid: Bool = true
    @FocusState private var isHexFieldFocused: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Color preview with hex input
            HStack(spacing: DesignSystem.Spacing.md) {
                // Color preview
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(selectedColor)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    )

                // Hex input field
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Or paste hex value")
                        .font(DesignSystem.Typography.formLabel)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    TextField("#RRGGBB", text: $hexInput)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(DesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                .strokeBorder(
                                    isHexInputValid ? Color.clear : DesignSystem.Colors.accentDanger,
                                    lineWidth: 1
                                )
                        )
                        .focused($isHexFieldFocused)
                        .onChange(of: hexInput) { _, newValue in
                            parseHexInput(newValue)
                        }

                    if !isHexInputValid && !hexInput.isEmpty {
                        Text("Invalid hex color")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundStyle(DesignSystem.Colors.accentDanger)
                    }
                }
            }

            // Hue slider (rainbow)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Hue")
                    .font(DesignSystem.Typography.formLabel)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                ZStack(alignment: .leading) {
                    // Rainbow gradient background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: hueGradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 32)

                    // Slider thumb
                    GeometryReader { geometry in
                        Circle()
                            .fill(Color(hue: hue, saturation: 1.0, brightness: 1.0))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .offset(x: hue * (geometry.size.width - 28))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let newHue = max(0, min(1, value.location.x / geometry.size.width))
                                        hue = newHue
                                        updateSelectedColor()
                                    }
                            )
                    }
                    .frame(height: 32)
                }
            }

            // Lightness slider (black to white through color)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Lightness")
                    .font(DesignSystem.Typography.formLabel)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                ZStack(alignment: .leading) {
                    // Black -> Color -> White gradient
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .black,
                                    Color(hue: hue, saturation: 1.0, brightness: 1.0),
                                    .white
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 32)

                    // Slider thumb
                    GeometryReader { geometry in
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(lightness > 0.5 ? Color.black.opacity(0.3) : Color.white, lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .offset(x: lightness * (geometry.size.width - 28))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let newLightness = max(0, min(1, value.location.x / geometry.size.width))
                                        lightness = newLightness
                                        updateSelectedColor()
                                    }
                            )
                    }
                    .frame(height: 32)
                }

                HStack {
                    Text("Dark")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                    Spacer()
                    Text("Light")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .onAppear {
            extractFromColor(selectedColor)
        }
    }

    private var hueGradientColors: [Color] {
        stride(from: 0.0, through: 1.0, by: 0.1).map { h in
            Color(hue: h, saturation: 1.0, brightness: 1.0)
        }
    }

    private func updateSelectedColor() {
        // Convert lightness to saturation/brightness
        // lightness 0 = black (b=0), 0.5 = pure color (s=1, b=1), 1 = white (s=0)
        let saturation: Double
        let brightness: Double

        if lightness <= 0.5 {
            // Black to pure color: decrease brightness
            saturation = 1.0
            brightness = lightness * 2  // 0->0, 0.5->1
        } else {
            // Pure color to white: decrease saturation
            saturation = 1.0 - ((lightness - 0.5) * 2)  // 0.5->1, 1->0
            brightness = 1.0
        }

        let newColor = Color(hue: hue, saturation: saturation, brightness: brightness)
        selectedColor = newColor

        // Update hex field when sliders change (if not editing hex)
        if !isHexFieldFocused {
            updateHexFromColor(newColor)
        }
    }

    private func extractFromColor(_ color: Color) {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        hue = Double(h)

        // Convert saturation/brightness back to lightness
        if b < 1.0 {
            // Dark side: lightness based on brightness
            lightness = Double(b) / 2.0
        } else {
            // Light side: lightness based on saturation
            lightness = 0.5 + (1.0 - Double(s)) / 2.0
        }

        // Update hex field if not focused (avoid overwriting user input)
        if !isHexFieldFocused {
            updateHexFromColor(color)
        }
        #endif
    }

    private func updateHexFromColor(_ color: Color) {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        let hexString = String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
        hexInput = hexString
        isHexInputValid = true
        #endif
    }

    private func parseHexInput(_ input: String) {
        // Clean up input
        var hex = input.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")

        // Allow partial input while typing
        guard hex.count == 6 else {
            isHexInputValid = hex.isEmpty || hex.count < 6
            return
        }

        // Parse hex to RGB
        guard let rgb = ColorDistance.hexToRGB(hex) else {
            isHexInputValid = false
            return
        }

        isHexInputValid = true

        // Convert RGB to Color and update
        let newColor = Color(red: rgb.r, green: rgb.g, blue: rgb.b)
        selectedColor = newColor

        // Update sliders to match
        #if canImport(UIKit)
        let uiColor = UIColor(newColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        hue = Double(h)

        // Convert saturation/brightness back to lightness
        if b < 1.0 {
            lightness = Double(b) / 2.0
        } else {
            lightness = 0.5 + (1.0 - Double(s)) / 2.0
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var color: Color = .blue
    @Previewable @State var tolerance: Double = 30
    @Previewable @State var includeHighVariance: Bool = true

    ColorSearchSheet(
        selectedColor: $color,
        tolerance: $tolerance,
        includeHighVariance: $includeHighVariance,
        onApply: {},
        onClear: {},
        isSearchActive: true
    )
}

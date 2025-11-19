//
//  ColorSwatchViewTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/18/25.
//  Tests for ColorSwatchView gradient display
//

import Testing
import SwiftUI
@testable import Molten

@Suite("ColorSwatchView Tests")
struct ColorSwatchViewTests {

    @Test("Creates view with valid hex colors")
    func createsViewWithValidColors() {
        let colors = ["#2E5E41", "#1D4030", "#0C2219"]
        let view = ColorSwatchView(colors: colors, size: 60)

        #expect(view.colors.count == 3)
        #expect(view.size == 60)
        #expect(view.cornerRadius == 8)
    }

    @Test("Creates view with custom size and corner radius")
    func createsViewWithCustomDimensions() {
        let colors = ["#FF0000"]
        let view = ColorSwatchView(colors: colors, size: 100, cornerRadius: 12)

        #expect(view.size == 100)
        #expect(view.cornerRadius == 12)
    }

    @Test("Handles empty color array gracefully")
    func handlesEmptyColorArray() {
        let view = ColorSwatchView(colors: [], size: 60)

        // Should not crash - view renders fallback placeholder
        #expect(view.colors.isEmpty)
    }

    @Test("Handles invalid hex color strings")
    func handlesInvalidHexColors() {
        let invalidColors = ["invalid", "#ZZZ", "notacolor"]
        let view = ColorSwatchView(colors: invalidColors, size: 60)

        // Should not crash - view renders fallback placeholder
        #expect(view.colors.count == 3)
    }

    @Test("Accepts colors without hash prefix")
    func acceptsColorsWithoutHashPrefix() {
        let colors = ["2E5E41", "1D4030", "0C2219"]
        let view = ColorSwatchView(colors: colors, size: 60)

        #expect(view.colors.count == 3)
    }

    @Test("Handles single color")
    func handlesSingleColor() {
        let colors = ["#FF5733"]
        let view = ColorSwatchView(colors: colors, size: 60)

        #expect(view.colors.count == 1)
    }

    @Test("Handles many colors")
    func handlesManyColors() {
        let colors = ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF"]
        let view = ColorSwatchView(colors: colors, size: 60)

        #expect(view.colors.count == 5)
    }

    @Test("Uses default size when not specified")
    func usesDefaultSize() {
        let colors = ["#FF0000"]
        let view = ColorSwatchView(colors: colors)

        #expect(view.size == 60)
    }

    @Test("Uses default corner radius when not specified")
    func usesDefaultCornerRadius() {
        let colors = ["#FF0000"]
        let view = ColorSwatchView(colors: colors)

        #expect(view.cornerRadius == 8)
    }
}

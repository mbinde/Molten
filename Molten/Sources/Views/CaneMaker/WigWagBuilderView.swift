//
//  WigWagBuilderView.swift
//  Molten
//
//  Interactive wigwag cane builder with drag-to-twist interface
//

import SwiftUI

struct WigWagBuilderView: View {
    @State private var design = WigWagDesign()

    /// Tracks the drag for twist gesture
    @State private var dragStartX: CGFloat = 0
    @State private var twistAtDragStart: Double = 0

    /// Sensitivity: how many radians per point of horizontal drag (0.02 = slow, 0.1 = fast)
    @State private var twistSensitivity: Double = 0.05

    /// Timer to record twist history as user drags
    @State private var recordTimer: Timer?

    /// Selected point index for revert (nil = no selection)
    @State private var selectedRevertIndex: Int?

    /// Toggle between Sphere View and Flattened View
    @State private var showFlattenedView = false

    // MARK: - Save/Load State

    @State private var showingSavePatternSheet = false
    @State private var showingLoadPatternSheet = false
    @State private var showingSavePaletteSheet = false
    @State private var showingLoadPaletteSheet = false
    @State private var savePatternName = ""
    @State private var savePaletteName = ""

    /// All catalog items in the palette (for saving allCatalogItemIds)
    @State private var paletteItems: [UnifiedCatalogItem] = []

    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Sphere view / Flattened view - toggleable visualization
                    visualizationSection

                    // Twist history visualization
                    twistHistorySection

                    // Color pattern - shows current segments
                    colorPatternSection

                    // Color palette for selecting segment colors
                    GlassColorPalette(
                        title: "Colors",
                        onColorSelected: { item in
                            addColorFromCatalog(item)
                        },
                        onPaletteChanged: { items in
                            paletteItems = items
                        }
                    )
                }
                .padding(DesignSystem.Padding.generous)
                .padding(.bottom, 100) // Extra space for tab bar
            }
            .navigationTitle("Wig Wag")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Colors.background)
            .sheet(isPresented: $showingSavePatternSheet) {
                SavePatternSheet(
                    name: $savePatternName,
                    onSave: { name in
                        Task {
                            await savePattern(name: name)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingLoadPatternSheet) {
                LoadPatternSheet(
                    onSelect: { pattern in
                        loadPattern(pattern)
                    }
                )
            }
            .sheet(isPresented: $showingSavePaletteSheet) {
                SavePaletteSheet(
                    name: $savePaletteName,
                    onSave: { name in
                        Task {
                            await savePalette(name: name)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingLoadPaletteSheet) {
                LoadPaletteSheet(
                    onSelect: { palette in
                        loadPalette(palette)
                    }
                )
            }
        }
    }

    // MARK: - Save/Load Methods

    private func savePattern(name: String) async {
        let pattern = TwistPatternModel(
            name: name,
            twistHistory: design.twistHistory + [design.currentTwist]
        )
        do {
            _ = try await dependencies.twistPatternRepository.create(pattern)
            showingSavePatternSheet = false
            savePatternName = ""
        } catch {
            print("Error saving pattern: \(error)")
        }
    }

    private func loadPattern(_ pattern: TwistPatternModel) {
        withAnimation {
            design.twistHistory = pattern.twistHistory
            design.currentTwist = pattern.twistHistory.last ?? 0.0
            selectedRevertIndex = nil
        }
        showingLoadPatternSheet = false
    }

    private func savePalette(name: String) async {
        // Extract hex colors from current segments
        let hexColors = design.segments.map { segment -> String in
            segment.color.toHex() ?? "000000"
        }

        // Get all catalog item IDs from the palette (even those not used in the pattern)
        let allItemIds = paletteItems.map { $0.stable_id }

        let palette = GlassPaletteModel(
            name: name,
            type: "wigwag",
            coe: 0, // We don't track COE for wigwag palettes since colors are already selected
            catalogItemIds: hexColors, // Store hex colors directly since we don't have catalog IDs
            allCatalogItemIds: allItemIds
        )
        do {
            _ = try await dependencies.glassPaletteRepository.create(palette)
            showingSavePaletteSheet = false
            savePaletteName = ""
        } catch {
            print("Error saving palette: \(error)")
        }
    }

    private func loadPalette(_ palette: GlassPaletteModel) {
        withAnimation {
            // Convert stored hex colors back to segments
            let segments = palette.catalogItemIds.map { hex in
                WigWagSegment(color: Color(hex: hex), angularWidth: .pi)
            }
            if !segments.isEmpty {
                design.segments = segments
                design.redistributeWidths()
            }
        }
        showingLoadPaletteSheet = false
    }

    private func addColorFromCatalog(_ item: UnifiedCatalogItem) {
        guard let hex = item.representative_color ?? item.dominant_colors?.first else { return }
        let color = Color(hex: hex)
        withAnimation {
            design.segments.append(WigWagSegment(color: color, angularWidth: .pi / 2))
            design.redistributeWidths()
        }
    }

    // MARK: - Color Pattern Section

    @State private var selectedSegmentIndex: Int?

    private var colorPatternSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Color Pattern")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)

                Spacer()

                Menu {
                    Button {
                        showingSavePaletteSheet = true
                    } label: {
                        Label("Save Palette", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        showingLoadPaletteSheet = true
                    } label: {
                        Label("Load Palette", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) {
                        withAnimation {
                            design.resetColors()
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            // Horizontal scrolling color chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(design.segments.enumerated()), id: \.element.id) { index, segment in
                        colorChip(segment: segment, index: index)
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
            }

            Text("Tap to select • Long press to delete")
                .font(DesignSystem.Typography.listItemCaptionSmall)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func colorChip(segment: WigWagSegment, index: Int) -> some View {
        let isSelected = selectedSegmentIndex == index

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if selectedSegmentIndex == index {
                    selectedSegmentIndex = nil
                } else {
                    selectedSegmentIndex = index
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(segment.color)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle()
                            .stroke(
                                isSelected ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textTertiary.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .shadow(color: isSelected ? DesignSystem.Colors.accentPrimary.opacity(0.3) : .clear, radius: 4)

                if isSelected {
                    Button {
                        deleteSegment(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, DesignSystem.Colors.accentDanger)
                    }
                    .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func deleteSegment(at index: Int) {
        withAnimation {
            if selectedSegmentIndex == index {
                selectedSegmentIndex = nil
            } else if let selected = selectedSegmentIndex, selected > index {
                selectedSegmentIndex = selected - 1
            }
            design.segments.remove(at: index)
            design.redistributeWidths()
        }
    }

    // MARK: - Visualization Section (Sphere View / Flattened View toggle)
    //
    // NOTE: Flattened view is a work in progress. The goal is to show a stereographic
    // projection of the sphere as if you poked a hole on the equator and flattened it.
    // The two poles should appear as spiral centers on opposite sides of the disk.
    //
    // References for future work:
    // - https://en.wikipedia.org/wiki/Stereographic_projection
    // - https://mathworld.wolfram.com/StereographicProjection.html
    //
    // Key insight: All color regions must remain connected after projection
    // (continuous transformation preserves connectivity).
    //
    // To re-enable: change showFlattenedViewEnabled to true

    /// Set to true to show the Sphere/Flattened picker (work in progress)
    private let showFlattenedViewEnabled = false

    private var visualizationSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                // Toggle between Sphere View and Flattened View (hidden until projection is fixed)
                if showFlattenedViewEnabled {
                    Picker("View", selection: $showFlattenedView) {
                        Text("Sphere").tag(false)
                        Text("Flattened").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                Spacer()

                // Sensitivity slider (only for Sphere View since that's where drag works)
                if !showFlattenedView {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "tortoise")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        Slider(value: $twistSensitivity, in: 0.02...0.12)
                            .frame(width: 80)
                        Image(systemName: "hare")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }

            // The visualization with drag gesture
            Group {
                if showFlattenedView && showFlattenedViewEnabled {
                    WigWagFlattenedView(design: design)
                } else {
                    WigWagSphereView(design: design)
                }
            }
            .frame(width: 280, height: 280)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartX == 0 {
                            dragStartX = value.startLocation.x
                            twistAtDragStart = design.currentTwist
                            startRecordingTimer()
                        }

                        let deltaX = value.location.x - dragStartX
                        design.currentTwist = twistAtDragStart + deltaX * twistSensitivity
                    }
                    .onEnded { _ in
                        dragStartX = 0
                        stopRecordingTimer()
                        // Record final position
                        design.recordTwist()
                    }
            )

            Text("Drag left/right to twist")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Twist History Section

    private var twistHistorySection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Twist History")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)

                Spacer()

                if let revertIndex = selectedRevertIndex {
                    Button {
                        withAnimation {
                            design.revertToIndex(revertIndex)
                            selectedRevertIndex = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Revert")
                        }
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundStyle(DesignSystem.Colors.accentPrimary)
                    }
                } else if design.canUndo {
                    Button {
                        withAnimation {
                            design.undo()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundStyle(DesignSystem.Colors.accentPrimary)
                    }
                }

                Menu {
                    Button {
                        showingSavePatternSheet = true
                    } label: {
                        Label("Save Pattern", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        showingLoadPatternSheet = true
                    } label: {
                        Label("Load Pattern", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) {
                        withAnimation {
                            design.resetTwist()
                            selectedRevertIndex = nil
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            // Visual representation of twist history
            TwistHistoryGraph(
                history: design.twistHistory,
                currentTwist: design.currentTwist,
                selectedIndex: selectedRevertIndex,
                onTap: { index in
                    withAnimation {
                        if selectedRevertIndex == index {
                            selectedRevertIndex = nil
                        } else {
                            selectedRevertIndex = index
                        }
                    }
                }
            )
            .frame(height: 60)
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }


    // MARK: - Timer for Recording

    private func startRecordingTimer() {
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            design.recordTwist()
        }
    }

    private func stopRecordingTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
    }
}

// MARK: - Sphere View Visualization

struct WigWagSphereView: View {
    let design: WigWagDesign

    /// Number of rings scales with twist history - more history = more rings needed
    /// Minimum of 75 for smooth appearance, max of 150 to avoid Moiré patterns
    private var renderRingCount: Int {
        min(150, max(75, design.twistHistory.count * 2))
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 4
            let ringCount = renderRingCount
            let ringWidth = maxRadius / CGFloat(ringCount)

            // Build the full twist data including current position
            let allTwists = design.twistHistory + [design.currentTwist]

            // Draw from outside in with interpolated twist values
            for ringIndex in 0..<ringCount {
                let outerRadius = maxRadius - CGFloat(ringIndex) * ringWidth
                let innerRadius = outerRadius - ringWidth

                // Map ring index to position in twist history (0 = oldest/outer, 1 = newest/inner)
                let t = Double(ringIndex) / Double(ringCount - 1)
                let twist = interpolateTwist(allTwists, at: t)

                drawRing(
                    context: context,
                    center: center,
                    innerRadius: max(0, innerRadius),
                    outerRadius: outerRadius,
                    twist: twist,
                    segments: design.segments
                )
            }

            // Draw outline
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: center.x - maxRadius,
                    y: center.y - maxRadius,
                    width: maxRadius * 2,
                    height: maxRadius * 2
                )),
                with: .color(DesignSystem.Colors.textTertiary.opacity(0.5)),
                lineWidth: 1
            )
        }
    }

    /// Interpolates twist value at position t (0-1) through the twist history
    private func interpolateTwist(_ twists: [Double], at t: Double) -> Double {
        guard twists.count > 1 else {
            return twists.first ?? 0
        }

        // Map t to position in array
        let position = t * Double(twists.count - 1)
        let lowerIndex = Int(position)
        let upperIndex = min(lowerIndex + 1, twists.count - 1)
        let fraction = position - Double(lowerIndex)

        // Linear interpolation between adjacent points
        let lower = twists[lowerIndex]
        let upper = twists[upperIndex]
        return lower + (upper - lower) * fraction
    }

    private func drawRing(
        context: GraphicsContext,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        twist: Double,
        segments: [WigWagSegment]
    ) {
        var startAngle: Double = twist

        for segment in segments {
            let endAngle = startAngle + segment.angularWidth

            var path = Path()
            path.addArc(
                center: center,
                radius: outerRadius,
                startAngle: .radians(startAngle),
                endAngle: .radians(endAngle),
                clockwise: false
            )
            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: .radians(endAngle),
                endAngle: .radians(startAngle),
                clockwise: true
            )
            path.closeSubpath()

            context.fill(path, with: .color(segment.color))

            startAngle = endAngle
        }
    }
}

// MARK: - Twist History Graph

struct TwistHistoryGraph: View {
    let history: [Double]
    let currentTwist: Double
    var selectedIndex: Int?
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !history.isEmpty else { return }

                let allValues = history + [currentTwist]
                let maxAbsTwist = CGFloat(max(allValues.map { abs($0) }.max() ?? 1.0, 1.0))

                let centerY = size.height / 2
                let scaleY = (size.height / 2 - 4) / maxAbsTwist
                let pointCount = allValues.count

                // Draw center line
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: centerY))
                        path.addLine(to: CGPoint(x: size.width, y: centerY))
                    },
                    with: .color(DesignSystem.Colors.textTertiary.opacity(0.3)),
                    lineWidth: 1
                )

                // Draw twist history line
                var path = Path()
                for (index, twist) in allValues.enumerated() {
                    let x = size.width * CGFloat(index) / CGFloat(max(pointCount - 1, 1))
                    let y = centerY - CGFloat(twist) * scaleY

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(DesignSystem.Colors.accentPrimary),
                    lineWidth: 2
                )

                // Draw selected point indicator
                if let selectedIndex = selectedIndex, selectedIndex < history.count {
                    let x = size.width * CGFloat(selectedIndex) / CGFloat(max(pointCount - 1, 1))
                    let y = centerY - CGFloat(history[selectedIndex]) * scaleY

                    // Vertical line at selection
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        },
                        with: .color(DesignSystem.Colors.accentPrimary.opacity(0.5)),
                        lineWidth: 1
                    )

                    // Circle at selected point
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)),
                        with: .color(DesignSystem.Colors.accentPrimary)
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard history.count > 1 else { return }

                // Map tap X to history index
                let fraction = location.x / geometry.size.width
                let index = Int(round(fraction * Double(history.count - 1)))
                let clampedIndex = max(0, min(history.count - 1, index))
                onTap?(clampedIndex)
            }
        }
        .background(DesignSystem.Colors.backgroundTertiary.opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.small)
    }
}

// MARK: - Flattened Sphere View (Equator Poke Projection)

/// Visualizes the wigwag as if you poked a hole on the equator of the sphere and flattened it.
/// - The poke point becomes the outer rim of the flattened image
/// - The two poles (north and south spirals) appear on opposite sides (left and right)
/// - The equator stretches between them as wavy lines
struct WigWagFlattenedView: View {
    let design: WigWagDesign

    /// Generate the flattened pendant image using stereographic projection
    /// Physical model: poke a hole at one point on the equator, stretch it to become the rim
    ///
    /// Key insight: The color bands on the sphere run from north pole to south pole
    /// like lines of longitude. The twist pattern determines how these bands spiral.
    /// When we flatten, these bands should remain connected - they just get distorted.
    private var marbleImage: CGImage? {
        let size = 300  // Fixed render size for performance
        let allTwists = design.twistHistory + [design.currentTwist]

        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let center = Double(size) / 2
        let maxRadius = center - 2

        // Stereographic projection from point P on equator.
        // We project from P = (1, 0, 0) onto the plane tangent at (-1, 0, 0).
        //
        // For a point (x, y, z) on the unit sphere, the stereographic projection
        // from P = (1, 0, 0) onto plane x = -1 is:
        //   X_proj = -2y / (1 - x)
        //   Y_proj = -2z / (1 - x)
        //
        // Inverse (from plane back to sphere):
        // Given (X, Y) in the plane where X corresponds to -y direction, Y to -z:
        //   Let r² = X² + Y²
        //   x = (r² - 4) / (r² + 4)
        //   y = -4X / (r² + 4)
        //   z = -4Y / (r² + 4)
        //
        // At center of image (X=Y=0): x = -4/4 = -1, y = 0, z = 0 ✓ (antipodal to projection point)
        // As r → ∞: x → 1, approaching the projection point

        let scale = 4.0  // Scale factor for the projection plane (larger = see more of sphere)

        for py in 0..<size {
            for px in 0..<size {
                let dx = Double(px) - center
                let dy = Double(py) - center
                let dist = sqrt(dx * dx + dy * dy)

                // Skip pixels outside the circle
                guard dist <= maxRadius else { continue }

                // Map pixel to projection plane coordinates
                // Scale so that the edge of our circle corresponds to a reasonable portion of sphere
                let X = (dx / maxRadius) * scale
                let Y = (dy / maxRadius) * scale

                let rSq = X * X + Y * Y
                let denom = rSq + 4

                // Inverse stereographic from (1,0,0)
                let sx = (rSq - 4) / denom
                let sy = -4 * X / denom
                let sz = -4 * Y / denom

                // Now (sx, sy, sz) is a point on the unit sphere
                // sx: -1 at center (antipodal to projection), approaches 1 at edge (projection point)
                // sz: +1 is north pole, -1 is south pole

                // Convert to spherical coordinates
                // sz is the "up" direction (toward north pole)
                let lat = asin(max(-1, min(1, sz)))  // latitude: -π/2 to π/2
                let colatitude = .pi / 2 - lat        // 0 at north pole, π at south pole

                // Longitude in the equatorial plane (sx-sy plane)
                // atan2(sy, sx) gives angle from positive-x axis
                let lon = atan2(sy, sx)

                // Get the twist at this colatitude
                let twist = calculateTwistAtColatitude(colat: colatitude, allTwists: allTwists)

                // The color is determined by longitude + twist
                // This gives us the "stripe" that this point belongs to
                var angle = lon + twist

                // Normalize to 0..2π
                angle = angle.truncatingRemainder(dividingBy: 2 * .pi)
                if angle < 0 { angle += 2 * .pi }

                let rgba = colorComponentsForAngle(angle, segments: design.segments)

                context.setFillColor(red: rgba.r, green: rgba.g, blue: rgba.b, alpha: 1.0)
                context.fill(CGRect(x: px, y: py, width: 1, height: 1))
            }
        }

        return context.makeImage()
    }

    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)

            ZStack {
                if let image = marbleImage {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: dimension, height: dimension)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: dimension, height: dimension)
                }

                // Draw outline
                Circle()
                    .stroke(DesignSystem.Colors.textTertiary.opacity(0.5), lineWidth: 1)
                    .frame(width: dimension - 8, height: dimension - 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Calculate the accumulated twist at a given colatitude (angle from north pole).
    /// colat=0 is the north pole, colat=π is the south pole.
    ///
    /// Physical model: The cane runs from north pole to south pole.
    /// - At north pole (colat=0): twist = first twist value (center of cane)
    /// - At equator (colat=π/2): twist = last twist value (one end of cane)
    /// - At south pole (colat=π): twist = first twist value again (back to center)
    ///
    /// The twist history records the profile from pole to equator.
    /// The south hemisphere mirrors the north (same cane, viewed from the other side).
    private func calculateTwistAtColatitude(colat: Double, allTwists: [Double]) -> Double {
        guard allTwists.count > 1 else {
            return allTwists.first ?? 0
        }

        // Map colatitude to a parameter t ∈ [0, 1] through the twist history
        // North hemisphere (colat 0→π/2): t goes 0→1
        // South hemisphere (colat π/2→π): t goes 1→0 (mirror)
        let t: Double
        if colat <= .pi / 2 {
            t = colat / (.pi / 2)
        } else {
            t = 1.0 - (colat - .pi / 2) / (.pi / 2)
        }

        // Interpolate through twist history
        let position = t * Double(allTwists.count - 1)
        let lowerIndex = Int(position)
        let upperIndex = min(lowerIndex + 1, allTwists.count - 1)
        let fraction = position - Double(lowerIndex)

        let lower = allTwists[lowerIndex]
        let upper = allTwists[upperIndex]
        return lower + (upper - lower) * fraction
    }

    /// Get RGB components for the color at a given angle
    private func colorComponentsForAngle(_ angle: Double, segments: [WigWagSegment]) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        guard !segments.isEmpty else { return (0.5, 0.5, 0.5) }

        // Normalize angle to 0-2π
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if normalizedAngle < 0 { normalizedAngle += 2 * .pi }

        var accumulated = 0.0
        for segment in segments {
            accumulated += segment.angularWidth
            if normalizedAngle < accumulated {
                return extractRGB(from: segment.color)
            }
        }
        return extractRGB(from: segments.last?.color ?? .gray)
    }

    /// Extract RGB components from a SwiftUI Color
    private func extractRGB(from color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        #if os(iOS)
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
        #else
        let nsColor = NSColor(color)
        return (nsColor.redComponent, nsColor.greenComponent, nsColor.blueComponent)
        #endif
    }
}

// MARK: - Save/Load Sheets

struct SavePatternSheet: View {
    @Binding var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Pattern Name", text: $name)
                }
            }
            .navigationTitle("Save Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct LoadPatternSheet: View {
    let onSelect: (TwistPatternModel) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @State private var patterns: [TwistPatternModel] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if patterns.isEmpty {
                    ContentUnavailableView(
                        "No Saved Patterns",
                        systemImage: "waveform.path",
                        description: Text("Save a twist pattern to see it here.")
                    )
                } else {
                    List(patterns) { pattern in
                        Button {
                            onSelect(pattern)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pattern.name)
                                    .font(DesignSystem.Typography.formValue)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text("\(pattern.twistHistory.count) points")
                                    .font(DesignSystem.Typography.listItemCaption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Load Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            do {
                patterns = try await dependencies.twistPatternRepository.getAllSortedByDate()
            } catch {
                print("Error loading patterns: \(error)")
            }
            isLoading = false
        }
        .presentationDetents([.medium, .large])
    }
}

struct SavePaletteSheet: View {
    @Binding var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Palette Name", text: $name)
                }
            }
            .navigationTitle("Save Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct LoadPaletteSheet: View {
    let onSelect: (GlassPaletteModel) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @State private var palettes: [GlassPaletteModel] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if palettes.isEmpty {
                    ContentUnavailableView(
                        "No Saved Palettes",
                        systemImage: "paintpalette",
                        description: Text("Save a color palette to see it here.")
                    )
                } else {
                    List(palettes) { palette in
                        Button {
                            onSelect(palette)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(palette.name)
                                    .font(DesignSystem.Typography.formValue)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text("\(palette.catalogItemIds.count) colors")
                                    .font(DesignSystem.Typography.listItemCaption)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Load Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            do {
                palettes = try await dependencies.glassPaletteRepository.getByType("wigwag")
            } catch {
                print("Error loading palettes: \(error)")
            }
            isLoading = false
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    WigWagBuilderView()
}

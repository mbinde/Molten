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
                    // End view - the main visualization
                    endViewSection

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

    // MARK: - End View Section

    private var endViewSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("End View")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)

                Spacer()

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

            // The circular end view with drag gesture
            WigWagEndView(design: design)
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

// MARK: - End View Visualization

struct WigWagEndView: View {
    let design: WigWagDesign

    /// Number of rings scales with twist history - more history = more rings needed
    /// Minimum of 50 for smooth appearance, max of 150 to avoid Moiré patterns
    private var renderRingCount: Int {
        min(150, max(50, design.twistHistory.count * 2))
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

//
//  CaneBuilderView.swift
//  Molten
//
//  Main view for the Cane Maker tab - allows designing and visualizing twisted canes.
//

import SwiftUI

struct CaneBuilderView: View {
    @State private var design = CaneDesign()
    @State private var selectedSegmentIndex: Int?

    // MARK: - Save/Load State

    @State private var showingSaveCaneSheet = false
    @State private var showingLoadCaneSheet = false
    @State private var saveCaneNameInput = ""

    /// All catalog items in the palette (for saving allCatalogItemIds)
    @State private var paletteItems: [UnifiedCatalogItem] = []

    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Color list - the primary way to build the cane
                    colorListSection

                    // Color palette for adding colors
                    GlassColorPalette(
                        title: selectedSegmentIndex != nil ? "Replace Color" : "Add Color",
                        onColorSelected: { item in
                            addPaletteItem(item)
                        },
                        onPaletteChanged: { items in
                            paletteItems = items
                        }
                    )

                    // Side view (twisted stripe visualization)
                    sideViewSection

                    // Twist and stretch controls
                    twistControlSection
                    stretchControlSection
                }
                .padding(DesignSystem.Padding.generous)
                .padding(.bottom, 100) // Extra space for tab bar
            }
            .navigationTitle("Twist")
            .navigationBarTitleDisplayMode(.inline)
            .background(DesignSystem.Colors.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingSaveCaneSheet = true
                        } label: {
                            Label("Save Cane", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showingLoadCaneSheet = true
                        } label: {
                            Label("Load Cane", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(role: .destructive) {
                            withAnimation {
                                design.segments = []
                                design.twistRotations = 1.0
                                design.stretchFactor = 1.0
                                selectedSegmentIndex = nil
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
            }
            .sheet(isPresented: $showingSaveCaneSheet) {
                SaveTwistCaneSheet(
                    name: $saveCaneNameInput,
                    onSave: { name in
                        Task {
                            await saveCane(name: name)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingLoadCaneSheet) {
                LoadTwistCaneSheet(
                    onSelect: { cane, palette in
                        loadCane(cane, palette: palette)
                    }
                )
            }
        }
    }

    // MARK: - Save/Load Methods

    private func saveCane(name: String) async {
        // First, save the palette with type "twist"
        let catalogItemIds = design.segments.compactMap { $0.catalogItemId }
        let allItemIds = paletteItems.map { $0.stable_id }

        let palette = GlassPaletteModel(
            name: name,
            type: "twist",
            coe: 0,
            catalogItemIds: catalogItemIds,
            allCatalogItemIds: allItemIds
        )

        do {
            let savedPalette = try await dependencies.glassPaletteRepository.create(palette)

            // Then save the cane referencing the palette
            let cane = TwistCaneModel(
                name: name,
                glassPaletteId: savedPalette.id,
                twist: design.twistRotations,
                width: design.stretchFactor
            )

            _ = try await dependencies.twistCaneRepository.create(cane)
            showingSaveCaneSheet = false
            saveCaneNameInput = ""
        } catch {
            print("Error saving cane: \(error)")
        }
    }

    private func loadCane(_ cane: TwistCaneModel, palette: GlassPaletteModel) {
        withAnimation {
            // Restore twist and width
            design.twistRotations = cane.twist
            design.stretchFactor = cane.width

            // Restore segments from palette catalog IDs
            // For now, create segments with colors from hex (stored in catalogItemIds for wigwag style)
            // For twist canes, we should look up actual catalog items
            design.segments = palette.catalogItemIds.map { id in
                // If it's a hex color, create segment directly
                if id.hasPrefix("#") || id.count == 6 {
                    return CaneSegment(color: Color(hex: id), angularWidth: .pi, catalogItemId: nil, catalogItemName: nil)
                }
                // Otherwise it's a stable_id, create segment with reference
                return CaneSegment(color: .gray, angularWidth: .pi, catalogItemId: id, catalogItemName: nil)
            }
            design.redistributeWidths()
            selectedSegmentIndex = nil
        }
        showingLoadCaneSheet = false
    }

    private func addPaletteItem(_ item: UnifiedCatalogItem) {
        let segment = CaneSegment.fromCatalogItem(item)
        withAnimation {
            if let index = selectedSegmentIndex {
                // Replace selected segment
                design.segments[index] = CaneSegment(
                    id: design.segments[index].id,
                    color: segment.color,
                    angularWidth: design.segments[index].angularWidth,
                    catalogItemId: segment.catalogItemId,
                    catalogItemName: segment.catalogItemName
                )
                selectedSegmentIndex = nil
            } else {
                // Add new segment
                design.segments.append(segment)
                design.redistributeWidths()
            }
        }
    }

    // MARK: - Color List Section

    private var colorListSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Color Pattern")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)

                Spacer()

                Text("\(design.segments.count) colors")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            if design.segments.isEmpty {
                Text("Tap colors below to build your pattern")
                    .font(DesignSystem.Typography.formValue)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            } else {
                // Horizontal layout with sticky end view and scrolling color chips
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Mini end view preview (stays fixed)
                    CaneEndView(
                        design: design,
                        size: 48,
                        onSegmentTapped: { index in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedSegmentIndex == index {
                                    selectedSegmentIndex = nil
                                } else {
                                    selectedSegmentIndex = index
                                }
                            }
                        }
                    )

                    // Divider
                    Rectangle()
                        .fill(DesignSystem.Colors.textTertiary.opacity(0.3))
                        .frame(width: 1, height: 40)

                    // Scrolling color chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(design.segments) { segment in
                                if let index = design.segments.firstIndex(where: { $0.id == segment.id }) {
                                    colorChip(segment: segment, index: index)
                                        .draggable(segment.id.uuidString) {
                                            // Drag preview
                                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                                                .fill(segment.color)
                                                .frame(width: 40, height: 40)
                                                .opacity(0.8)
                                        }
                                        .dropDestination(for: String.self) { items, _ in
                                            guard let draggedIDString = items.first,
                                                  let draggedID = UUID(uuidString: draggedIDString),
                                                  let fromIndex = design.segments.firstIndex(where: { $0.id == draggedID }),
                                                  let toIndex = design.segments.firstIndex(where: { $0.id == segment.id }),
                                                  fromIndex != toIndex else {
                                                return false
                                            }
                                            withAnimation {
                                                let movedSegment = design.segments.remove(at: fromIndex)
                                                design.segments.insert(movedSegment, at: toIndex)
                                                if selectedSegmentIndex == fromIndex {
                                                    selectedSegmentIndex = toIndex
                                                } else if let selected = selectedSegmentIndex {
                                                    // Adjust selection if it shifted
                                                    if fromIndex < selected && toIndex >= selected {
                                                        selectedSegmentIndex = selected - 1
                                                    } else if fromIndex > selected && toIndex <= selected {
                                                        selectedSegmentIndex = selected + 1
                                                    }
                                                }
                                            }
                                            return true
                                        }
                                }
                            }
                        }
                        .padding(.top, 8)  // Space for X button overflow
                        .padding(.trailing, 8)  // Space for last X button
                    }
                }

                // Instructions
                Text("Tap to select • Drag to reorder")
                    .font(DesignSystem.Typography.listItemCaptionSmall)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func colorChip(segment: CaneSegment, index: Int) -> some View {
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
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(segment.color)
                    .frame(width: 40, height: 40)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(
                                isSelected ? DesignSystem.Colors.accentPrimary : DesignSystem.Colors.textTertiary.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .shadow(color: isSelected ? DesignSystem.Colors.accentPrimary.opacity(0.3) : .clear, radius: 4)

                // Delete button when selected
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

    // MARK: - Twist Control Section

    private var twistControlSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Twist")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)

                Spacer()

                Text(String(format: "%.1f rotations", design.twistRotations))
                    .font(DesignSystem.Typography.prominentNumberSmall)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.accentPrimary)
            }

            Slider(
                value: $design.twistRotations,
                in: 0...20,
                step: 0.5
            )
            .tint(DesignSystem.Colors.accentPrimary)
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Stretch Control Section

    private var stretchControlSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Width")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)

                Spacer()

                Text(String(format: "%.0f%%", design.stretchFactor * 100))
                    .font(DesignSystem.Typography.prominentNumberSmall)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignSystem.Colors.accentPrimary)
            }

            Slider(
                value: $design.stretchFactor,
                in: 0.2...1.0,
                step: 0.05
            )
            .tint(DesignSystem.Colors.accentPrimary)
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Side View Section

    private var sideViewSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text("Side View")
                .font(DesignSystem.Typography.subsectionTitle)
                .fontWeight(DesignSystem.FontWeight.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geometry in
                CaneSideView(
                    design: design,
                    width: geometry.size.width,
                    height: 80
                )
            }
            .frame(height: 80)
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }
}

// MARK: - Save/Load Sheets

struct SaveTwistCaneSheet: View {
    @Binding var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Cane Name", text: $name)
                }
            }
            .navigationTitle("Save Cane")
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

struct LoadTwistCaneSheet: View {
    let onSelect: (TwistCaneModel, GlassPaletteModel) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @State private var canes: [TwistCaneModel] = []
    @State private var palettes: [UUID: GlassPaletteModel] = [:]
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if canes.isEmpty {
                    ContentUnavailableView(
                        "No Saved Canes",
                        systemImage: "cylinder",
                        description: Text("Save a twist cane to see it here.")
                    )
                } else {
                    List(canes) { cane in
                        Button {
                            if let palette = palettes[cane.glassPaletteId] {
                                onSelect(cane, palette)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cane.name)
                                    .font(DesignSystem.Typography.formValue)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                HStack(spacing: 8) {
                                    Text(String(format: "%.1f twist", cane.twist))
                                    Text("•")
                                    Text(String(format: "%.0f%% width", cane.width * 100))
                                }
                                .font(DesignSystem.Typography.listItemCaption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Load Cane")
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
                canes = try await dependencies.twistCaneRepository.getAllSortedByDate()
                // Load all referenced palettes
                for cane in canes {
                    if let palette = try await dependencies.glassPaletteRepository.get(id: cane.glassPaletteId) {
                        palettes[cane.glassPaletteId] = palette
                    }
                }
            } catch {
                print("Error loading canes: \(error)")
            }
            isLoading = false
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    CaneBuilderView()
}

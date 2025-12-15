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
    @State private var showingCatalogSearch = false
    @State private var catalogItems: [UnifiedCatalogItem] = []
    @State private var isLoadingCatalog = false

    private let catalogService = AppDependencies.shared.catalogService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Color list - the primary way to build the cane
                    colorListSection

                    // Color palette for adding colors
                    colorPaletteSection

                    // Side view (twisted stripe visualization)
                    sideViewSection

                    // Twist and stretch controls
                    twistControlSection
                    stretchControlSection
                }
                .padding(DesignSystem.Padding.generous)
            }
            .navigationTitle("Twist")
            .background(DesignSystem.Colors.background)
            .sheet(isPresented: $showingCatalogSearch) {
                CatalogColorPickerSheet(
                    catalogItems: $catalogItems,
                    isLoading: $isLoadingCatalog,
                    onSelect: { item in
                        addCatalogItem(item)
                        showingCatalogSearch = false
                    }
                )
            }
            .task {
                await loadCatalogItems()
            }
        }
    }

    private func loadCatalogItems() async {
        guard catalogItems.isEmpty else { return }
        isLoadingCatalog = true
        print("DEBUG: Starting catalog load...")
        do {
            catalogItems = try await catalogService.getAllCatalogItemsLightweight()
            print("DEBUG: Loaded \(catalogItems.count) catalog items")
        } catch {
            print("DEBUG ERROR loading catalog items: \(error)")
        }
        isLoadingCatalog = false
    }

    private func addCatalogItem(_ item: UnifiedCatalogItem) {
        let segment = CaneSegment.fromCatalogItem(item)
        withAnimation {
            if let index = selectedSegmentIndex {
                // Replace selected segment
                design.segments[index] = CaneSegment(
                    id: design.segments[index].id,  // Keep the same ID
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

    // MARK: - Color Palette Section

    private var colorPaletteSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Add Color")
                    .font(DesignSystem.Typography.subsectionTitle)
                    .fontWeight(DesignSystem.FontWeight.semibold)

                Spacer()

                if selectedSegmentIndex != nil {
                    Button {
                        withAnimation {
                            selectedSegmentIndex = nil
                        }
                    } label: {
                        Text("Deselect")
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundStyle(DesignSystem.Colors.accentPrimary)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: DesignSystem.Spacing.md) {
                // "+" button to search catalog
                Button {
                    showingCatalogSearch = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.backgroundTertiary)
                            .frame(width: 44, height: 44)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.accentPrimary)
                    }
                    .overlay {
                        Circle()
                            .stroke(DesignSystem.Colors.accentPrimary, lineWidth: 2)
                    }
                }
                .accessibilityLabel("Search catalog for glass color")

                // Preset colors
                ForEach(GlassColor.allCases, id: \.name) { glassColor in
                    colorButton(for: glassColor)
                }
            }

            if selectedSegmentIndex != nil {
                Text("Tap a color to change the selected segment")
                    .font(DesignSystem.Typography.listItemCaptionSmall)
                    .foregroundStyle(DesignSystem.Colors.accentPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    private func colorButton(for glassColor: GlassColor) -> some View {
        Button {
            withAnimation {
                if let index = selectedSegmentIndex {
                    // Change the selected segment's color
                    design.segments[index].color = glassColor.color
                    selectedSegmentIndex = nil  // Deselect after changing
                } else {
                    // Add a new segment
                    design.addSegment(color: glassColor.color)
                }
            }
        } label: {
            Circle()
                .fill(glassColor.color)
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .stroke(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                }
        }
        .accessibilityLabel(glassColor.name)
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

            HStack {
                Text("No twist")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                Spacer()
                Text("Tight twist")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Stretch Control Section

    private var stretchControlSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Stretch")
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

            HStack {
                Text("Stretched thin")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                Spacer()
                Text("Original")
                    .font(DesignSystem.Typography.listItemCaption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
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

#Preview {
    CaneBuilderView()
}

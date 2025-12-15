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

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // End view - the main visualization
                endViewSection

                // Twist history visualization
                twistHistorySection

                Spacer()
            }
            .padding(DesignSystem.Padding.generous)
            .navigationTitle("Wig Wag")
            .background(DesignSystem.Colors.background)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        withAnimation {
                            design.reset()
                        }
                    }
                }
            }
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

    /// Number of rings to render for smooth appearance
    private let renderRingCount = 200

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 4
            let ringWidth = maxRadius / CGFloat(renderRingCount)

            // Build the full twist data including current position
            let allTwists = design.twistHistory + [design.currentTwist]

            // Draw from outside in with interpolated twist values
            for ringIndex in 0..<renderRingCount {
                let outerRadius = maxRadius - CGFloat(ringIndex) * ringWidth
                let innerRadius = outerRadius - ringWidth

                // Map ring index to position in twist history (0 = oldest/outer, 1 = newest/inner)
                let t = Double(ringIndex) / Double(renderRingCount - 1)
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

#Preview {
    WigWagBuilderView()
}

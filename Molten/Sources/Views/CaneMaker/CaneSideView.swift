//
//  CaneSideView.swift
//  Molten
//
//  Side view of a twisted cane showing helical stripe patterns.
//
//  For a side view, we're seeing the front-facing surface of the cylinder.
//  Each segment boundary traces a curved path as it rotates along the length.
//  The path follows: y = r × sin(θ + twist × x)
//  where θ is the starting angle of the boundary.
//

import SwiftUI

/// Displays the side view of a twisted cane with helical stripe patterns
struct CaneSideView: View {
    let design: CaneDesign
    let width: CGFloat
    let height: CGFloat

    /// The effective height after applying stretch factor
    private var stretchedHeight: CGFloat {
        height * CGFloat(design.stretchFactor)
    }

    var body: some View {
        Canvas { context, size in
            drawCane(context: context, size: size)
        }
        .frame(width: width, height: stretchedHeight)
        .frame(height: height)  // Keep the container height constant
        .clipShape(Capsule())
    }

    private func drawCane(context: GraphicsContext, size: CGSize) {
        let radius = size.height / 2
        let centerY = size.height / 2

        // Draw background
        let bgRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.fill(Capsule().path(in: bgRect), with: .color(DesignSystem.Colors.backgroundTertiary))

        guard !design.segments.isEmpty else { return }

        let twistPerPixel = design.totalTwistRadians / Double(size.width)

        // For each segment, we need to draw it multiple times offset by 2π
        // A segment becomes visible each time it rotates into the front-facing range [-π/2, π/2]
        // This happens once per full rotation (2π) of twist.
        //
        // At position x, the twist is: twistPerPixel * x
        // A segment at base angle θ appears at angle: θ + twistPerPixel * x
        // It's visible when this angle (mod 2π) is in [-π/2, π/2]
        //
        // To cover the full length, we need copies for each time the segment
        // rotates through the visible range. With N rotations of twist,
        // each segment appears N times.

        for (index, segment) in design.segments.enumerated() {
            let baseStartAngle = design.startAngle(for: index)
            let baseEndAngle = design.endAngle(for: index)

            // Draw this segment for each "pass" through the visible window
            // We need enough passes to cover the full twist range
            let totalPasses = Int(ceil(design.twistRotations)) + 2

            for pass in -1...totalPasses {
                // Offset the angles by full rotations
                let offsetAngle = Double(pass) * 2 * .pi

                drawStripePass(
                    context: context,
                    size: size,
                    startAngle: baseStartAngle - offsetAngle,
                    endAngle: baseEndAngle - offsetAngle,
                    color: segment.color,
                    radius: radius,
                    centerY: centerY,
                    twistPerPixel: twistPerPixel
                )
            }
        }

        // Subtle outline
        context.stroke(
            Capsule().path(in: bgRect),
            with: .color(DesignSystem.Colors.textTertiary.opacity(0.3)),
            lineWidth: 1
        )
    }

    /// Draw one pass of a stripe (one time it crosses through visibility)
    private func drawStripePass(
        context: GraphicsContext,
        size: CGSize,
        startAngle: Double,
        endAngle: Double,
        color: Color,
        radius: CGFloat,
        centerY: CGFloat,
        twistPerPixel: Double
    ) {
        // Find the x range where this segment is visible
        // Segment is visible when angle + twist is in [-π/2, π/2]
        // angle + twistPerPixel * x ∈ [-π/2, π/2]
        // x ∈ [(-π/2 - angle) / twistPerPixel, (π/2 - angle) / twistPerPixel]

        guard twistPerPixel > 0.0001 else {
            // No twist - just draw based on whether angles are in visible range
            drawStaticStripe(context: context, size: size, startAngle: startAngle, endAngle: endAngle,
                           color: color, radius: radius, centerY: centerY)
            return
        }

        // Find x range where the segment edges are in visible range
        // For startAngle: visible when startAngle + twist ∈ [-π/2, π/2]
        let xEnterStart = (-.pi / 2 - startAngle) / twistPerPixel
        let xExitStart = (.pi / 2 - startAngle) / twistPerPixel

        let xEnterEnd = (-.pi / 2 - endAngle) / twistPerPixel
        let xExitEnd = (.pi / 2 - endAngle) / twistPerPixel

        // The segment is at least partially visible from when the first edge enters
        // to when the last edge exits
        let xMin = max(0, min(xEnterStart, xEnterEnd, xExitStart, xExitEnd))
        let xMax = min(Double(size.width), max(xEnterStart, xEnterEnd, xExitStart, xExitEnd))

        guard xMax > xMin else { return }

        // Sample points along this visible range
        let sampleCount = max(50, Int(xMax - xMin))

        var topEdge: [CGPoint] = []
        var bottomEdge: [CGPoint] = []

        for i in 0...sampleCount {
            let x = xMin + (Double(i) / Double(sampleCount)) * (xMax - xMin)
            let twist = twistPerPixel * x

            let angle1 = startAngle + twist
            let angle2 = endAngle + twist

            // Clamp to visible range
            let visibleStart = max(angle1, -.pi / 2)
            let visibleEnd = min(angle2, .pi / 2)

            if visibleStart < visibleEnd {
                let y1 = centerY - radius * CGFloat(sin(visibleStart))
                let y2 = centerY - radius * CGFloat(sin(visibleEnd))

                topEdge.append(CGPoint(x: x, y: min(y1, y2)))
                bottomEdge.append(CGPoint(x: x, y: max(y1, y2)))
            }
        }

        drawStripePath(context: context, topEdge: topEdge, bottomEdge: bottomEdge, color: color, size: size, radius: radius)
    }

    /// Draw a stripe with no twist (static horizontal bands)
    private func drawStaticStripe(
        context: GraphicsContext,
        size: CGSize,
        startAngle: Double,
        endAngle: Double,
        color: Color,
        radius: CGFloat,
        centerY: CGFloat
    ) {
        let visibleStart = max(startAngle, -.pi / 2)
        let visibleEnd = min(endAngle, .pi / 2)

        guard visibleStart < visibleEnd else { return }

        let y1 = centerY - radius * CGFloat(sin(visibleStart))
        let y2 = centerY - radius * CGFloat(sin(visibleEnd))

        let minY = min(y1, y2)
        let maxY = max(y1, y2)

        var path = Path()
        path.addRect(CGRect(x: 0, y: minY, width: size.width, height: maxY - minY))

        var clippedContext = context
        let clipRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        clippedContext.clip(to: Capsule().path(in: clipRect))
        clippedContext.fill(path, with: .color(color))
    }

    private func drawStripePath(
        context: GraphicsContext,
        topEdge: [CGPoint],
        bottomEdge: [CGPoint],
        color: Color,
        size: CGSize,
        radius: CGFloat
    ) {
        guard topEdge.count >= 2 else { return }

        var path = Path()
        path.move(to: topEdge[0])

        // Draw top edge
        for point in topEdge.dropFirst() {
            path.addLine(to: point)
        }

        // Draw bottom edge in reverse
        for point in bottomEdge.reversed() {
            path.addLine(to: point)
        }

        path.closeSubpath()

        // Clip to capsule shape and fill
        var clippedContext = context
        let clipRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        clippedContext.clip(to: Capsule().path(in: clipRect))
        clippedContext.fill(path, with: .color(color))
    }
}

#Preview("No Twist") {
    CaneSideView(
        design: {
            let d = CaneDesign()
            d.twistRotations = 0
            return d
        }(),
        width: 300,
        height: 60
    )
    .padding()
}

#Preview("1 Rotation") {
    CaneSideView(
        design: CaneDesign(),
        width: 300,
        height: 60
    )
    .padding()
}

#Preview("High Twist") {
    CaneSideView(
        design: {
            let d = CaneDesign()
            d.twistRotations = 15
            return d
        }(),
        width: 300,
        height: 60
    )
    .padding()
}

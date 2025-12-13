//
//  CaneEndView.swift
//  Molten
//
//  Circular "end-on" view of the cane showing color segments around the circumference.
//

import SwiftUI

/// Displays the end-on view of a cane as a circle divided into color segments
struct CaneEndView: View {
    let design: CaneDesign
    let size: CGFloat
    var onSegmentTapped: ((Int) -> Void)?

    var body: some View {
        ZStack {
            // Draw each segment as a pie slice
            ForEach(Array(design.segments.enumerated()), id: \.element.id) { index, segment in
                PieSlice(
                    startAngle: Angle(radians: design.startAngle(for: index) - .pi / 2),
                    endAngle: Angle(radians: design.endAngle(for: index) - .pi / 2)
                )
                .fill(segment.color)
                .onTapGesture {
                    onSegmentTapped?(index)
                }
            }

            // Center circle (represents the core/mandrel hole)
            Circle()
                .fill(DesignSystem.Colors.backgroundSecondary)
                .frame(width: size * 0.15, height: size * 0.15)

            // Subtle border
            Circle()
                .stroke(DesignSystem.Colors.textTertiary.opacity(0.3), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

/// A pie slice shape for drawing cane segments
struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    CaneEndView(
        design: CaneDesign(),
        size: 200
    )
    .padding()
}

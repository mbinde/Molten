//
//  LabelShapes.swift
//  Molten
//
//  Extracted from LabelPreviewView.swift
//  Shape definitions for cable/wire label formats
//

import SwiftUI

#if os(iOS)

// MARK: - Barbell/Cable Label Shapes

/// Shape for symmetric barbell/flag labels (two rectangles connected by narrow strip)
/// Used for standard cable labels like Avery 94749
struct BarbellShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalWidth = rect.width
        let totalHeight = rect.height
        let wrapWidth = totalWidth - (2 * flagWidth)
        let wrapY = (totalHeight - wrapHeight) / 2

        // Left flag (full height rectangle on left)
        path.addRect(CGRect(x: 0, y: 0, width: flagWidth, height: totalHeight))

        // Narrow wrap section in middle
        path.addRect(CGRect(x: flagWidth, y: wrapY, width: wrapWidth, height: wrapHeight))

        // Right flag (full height rectangle on right)
        path.addRect(CGRect(x: totalWidth - flagWidth, y: 0, width: flagWidth, height: totalHeight))

        return path
    }
}

/// Shape for T-style cable labels (single flag with narrow tail)
/// Like Avery 61539 - one printable flag area, with narrow wrap extending from one end
struct TStyleShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalWidth = rect.width
        let totalHeight = rect.height
        let wrapWidth = totalWidth - flagWidth
        let wrapY = (totalHeight - wrapHeight) / 2

        // Flag area on left (full height)
        path.addRect(CGRect(x: 0, y: 0, width: flagWidth, height: totalHeight))

        // Narrow wrap tail extending to the right
        path.addRect(CGRect(x: flagWidth, y: wrapY, width: wrapWidth, height: wrapHeight))

        return path
    }
}

/// Shape for P-style cable labels (flag with curved loop tail)
/// Like Avery 61540 - one printable flag with a curved/tapered tail for wrapping
struct PStyleShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalWidth = rect.width
        let totalHeight = rect.height
        let wrapY = (totalHeight - wrapHeight) / 2

        // Flag area on left (full height)
        path.addRect(CGRect(x: 0, y: 0, width: flagWidth, height: totalHeight))

        // Curved wrap section - tapers from flag to a narrower tail
        let startY = wrapY
        let endY = wrapY + wrapHeight
        let taperAmount = wrapHeight * 0.3

        path.move(to: CGPoint(x: flagWidth, y: startY))
        path.addLine(to: CGPoint(x: totalWidth, y: startY + taperAmount))
        path.addLine(to: CGPoint(x: totalWidth, y: endY - taperAmount))
        path.addLine(to: CGPoint(x: flagWidth, y: endY))
        path.closeSubpath()

        return path
    }
}

/// Shape for P-style folded cable labels (flag with wrap stub on right)
/// Like Mr-Label - shows flag split horizontally with wrap tail indicator
/// P-style = stub at TOP right (like letter P)
struct PStyleFoldedShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalHeight = rect.height
        let wrapY: CGFloat = 0  // P-style: stub at TOP

        // Flag area on left (full height)
        path.addRect(CGRect(x: 0, y: 0, width: flagWidth, height: totalHeight))

        // Wrap stub on right at TOP
        let stubLength = flagWidth * 0.5
        let taperAmount = wrapHeight * 0.15

        path.move(to: CGPoint(x: flagWidth, y: wrapY))
        path.addLine(to: CGPoint(x: flagWidth + stubLength, y: wrapY + taperAmount))
        path.addLine(to: CGPoint(x: flagWidth + stubLength, y: wrapY + wrapHeight - taperAmount))
        path.addLine(to: CGPoint(x: flagWidth, y: wrapY + wrapHeight))
        path.closeSubpath()

        return path
    }
}

/// Shape for just the wrap stub portion (for overlay effects)
/// P-style = stub at TOP right
struct PStyleFoldedStubShape: Shape {
    let flagWidth: CGFloat
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let wrapY: CGFloat = 0
        let stubLength = flagWidth * 0.5
        let taperAmount = wrapHeight * 0.15

        path.move(to: CGPoint(x: flagWidth, y: wrapY))
        path.addLine(to: CGPoint(x: flagWidth + stubLength, y: wrapY + taperAmount))
        path.addLine(to: CGPoint(x: flagWidth + stubLength, y: wrapY + wrapHeight - taperAmount))
        path.addLine(to: CGPoint(x: flagWidth, y: wrapY + wrapHeight))
        path.closeSubpath()

        return path
    }
}

/// Shape for self-laminating wrap labels (simple strip, no flags)
/// The entire label wraps around the cable with a clear overlay
struct WrapShape: Shape {
    let wrapHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let totalWidth = rect.width
        let totalHeight = rect.height
        let wrapY = (totalHeight - wrapHeight) / 2

        path.addRect(CGRect(x: 0, y: wrapY, width: totalWidth, height: wrapHeight))

        return path
    }
}

#endif

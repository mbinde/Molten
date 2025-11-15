//
//  SuccessToast.swift
//  Flameworker
//
//  Reusable toast notification component with configurable styles
//

import SwiftUI

// MARK: - Toast Style

/// Visual style for toast notifications
enum ToastStyle {
    case success
    case info
    case warning
    case error

    var color: Color {
        switch self {
        case .success:
            return .green
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Toast Placement

/// Placement position for toast notifications
enum ToastPlacement {
    case top
    case bottom

    var edge: Edge {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    var alignment: Alignment {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}

// MARK: - Toast Component

/// A reusable toast notification that appears on screen and automatically dismisses
struct Toast: View {
    let message: String
    let style: ToastStyle
    let placement: ToastPlacement
    let duration: TimeInterval
    @Binding var isShowing: Bool

    init(
        message: String,
        style: ToastStyle = .success,
        placement: ToastPlacement = .top,
        duration: TimeInterval = 2.0,
        isShowing: Binding<Bool>
    ) {
        self.message = message
        self.style = style
        self.placement = placement
        self.duration = duration
        self._isShowing = isShowing
    }

    var body: some View {
        if isShowing {
            VStack {
                if placement == .bottom {
                    Spacer()
                }

                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: style.icon)
                        .foregroundColor(.white)
                        .font(DesignSystem.Typography.body)

                    Text(message)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(DesignSystem.FontWeight.medium)
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Padding.standard)
                .padding(.vertical, DesignSystem.Padding.compact)
                .background(style.color)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(radius: 4)
                .padding(.horizontal, DesignSystem.Padding.standard)
                .padding(placement == .top ? .top : .bottom, DesignSystem.Padding.standard)

                if placement == .top {
                    Spacer()
                }
            }
            .transition(.move(edge: placement.edge).combined(with: .opacity))
            .zIndex(999) // Ensure it appears above other content
            .onAppear {
                // Auto-dismiss after specified duration
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// MARK: - Backward Compatibility

/// Legacy SuccessToast component - redirects to Toast with success style
@available(*, deprecated, message: "Use Toast with .success style instead")
struct SuccessToast: View {
    let message: String
    @Binding var isShowing: Bool

    var body: some View {
        Toast(message: message, style: .success, isShowing: $isShowing)
    }
}

// MARK: - View Extensions

extension View {
    /// Display a toast notification with custom style and placement
    /// - Parameters:
    ///   - message: The message to display
    ///   - style: Visual style (success, info, warning, error)
    ///   - placement: Position on screen (top or bottom)
    ///   - duration: How long to show the toast before auto-dismissing
    ///   - isShowing: Binding to control toast visibility
    func toast(
        message: String,
        style: ToastStyle = .success,
        placement: ToastPlacement = .top,
        duration: TimeInterval = 2.0,
        isShowing: Binding<Bool>
    ) -> some View {
        self.overlay(
            Toast(
                message: message,
                style: style,
                placement: placement,
                duration: duration,
                isShowing: isShowing
            ),
            alignment: placement.alignment
        )
    }

    /// Display a success toast (convenience method for backward compatibility)
    /// - Parameters:
    ///   - message: The success message to display
    ///   - isShowing: Binding to control toast visibility
    func successToast(message: String, isShowing: Binding<Bool>) -> some View {
        self.toast(message: message, style: .success, duration: 2.0, isShowing: isShowing)
    }
}

// MARK: - Previews

#Preview("Toast Styles") {
    @Previewable @State var showSuccess = false
    @Previewable @State var showInfo = false
    @Previewable @State var showWarning = false
    @Previewable @State var showError = false

    return ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Button("Show Success") {
                withAnimation { showSuccess = true }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Button("Show Info") {
                withAnimation { showInfo = true }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Button("Show Warning") {
                withAnimation { showWarning = true }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Button("Show Error") {
                withAnimation { showError = true }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
    .toast(message: "Operation successful!", style: .success, isShowing: $showSuccess)
    .toast(message: "Catalog updated to v3", style: .info, duration: 3.0, isShowing: $showInfo)
    .toast(message: "Low disk space", style: .warning, isShowing: $showWarning)
    .toast(message: "Failed to save", style: .error, isShowing: $showError)
}

#Preview("Bottom Placement") {
    @Previewable @State var isShowing = false

    return ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack {
            Button("Show Toast at Bottom") {
                withAnimation { isShowing = true }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    .toast(message: "Item removed from inventory", style: .success, placement: .bottom, isShowing: $isShowing)
}

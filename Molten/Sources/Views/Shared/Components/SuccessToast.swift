//
//  SuccessToast.swift
//  Flameworker
//
//  Simple success toast notification component
//

import SwiftUI

/// A reusable success toast notification that appears at the top of the screen
/// and automatically dismisses after a short duration
struct SuccessToast: View {
    let message: String
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
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
                .background(Color.green)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .shadow(radius: 4)
                .padding(.horizontal, DesignSystem.Padding.standard)
                .padding(.top, DesignSystem.Padding.standard)

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(999) // Ensure it appears above other content
            .onAppear {
                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

/// View modifier to easily add success toast to any view
extension View {
    func successToast(message: String, isShowing: Binding<Bool>) -> some View {
        self.overlay(
            SuccessToast(message: message, isShowing: isShowing)
        )
    }
}

// MARK: - Preview

#Preview("Success Toast") {
    @Previewable @State var isShowing = true

    return ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack {
            Button("Show Toast") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowing = true
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    .successToast(message: "Item added to shopping list", isShowing: $isShowing)
}

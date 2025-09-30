//
//  UnifiedButtonComponents.swift
//  Flameworker
//
//  Created by Assistant on 9/30/25.
//

import SwiftUI

// MARK: - Button Style Configuration

struct ButtonConfig {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let style: ButtonAppearance
    let hapticPattern: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        style: ButtonAppearance = .primary,
        hapticPattern: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.style = style
        self.hapticPattern = hapticPattern
    }
}

enum ButtonAppearance {
    case primary, secondary, destructive, subtle
    
    var backgroundColor: Color {
        switch self {
        case .primary: return .blue
        case .secondary: return .gray
        case .destructive: return .red
        case .subtle: return .clear
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return .white
        case .destructive: return .white
        case .subtle: return .primary
        }
    }
}

// MARK: - Unified Button Component

struct UnifiedButton: View {
    let config: ButtonConfig
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Play haptic if specified
            if let hapticPattern = config.hapticPattern {
                HapticService.shared.playPattern(named: hapticPattern)
            }
            action()
        }) {
            buttonContent
        }
        .buttonStyle(.plain)
        .background(buttonBackground)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: 12) {
            if let systemImage = config.systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(config.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                
                if let subtitle = config.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.8)
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
        }
        .foregroundColor(config.style.foregroundColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isPressed ? config.style.backgroundColor.opacity(0.8) : config.style.backgroundColor)
            .shadow(color: config.style.backgroundColor.opacity(0.3), radius: isPressed ? 2 : 4, x: 0, y: 2)
    }
}

// MARK: - Specialized Button Types

struct ActionButton: View {
    let title: String
    let systemImage: String?
    let style: ButtonAppearance
    let action: () -> Void
    
    init(
        _ title: String,
        systemImage: String? = nil,
        style: ButtonAppearance = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }
    
    var body: some View {
        UnifiedButton(
            config: ButtonConfig(
                title: title,
                systemImage: systemImage,
                style: style
            ),
            action: action
        )
    }
}

struct HapticButton: View {
    let title: String
    let description: String
    let pattern: String
    
    var body: some View {
        UnifiedButton(
            config: ButtonConfig(
                title: title,
                subtitle: description,
                systemImage: "hand.tap",
                style: .subtle,
                hapticPattern: pattern
            ),
            action: {
                print("🎯 Testing pattern: \(pattern)")
            }
        )
    }
}

// MARK: - Common Button Configurations

extension ButtonConfig {
    static func save(action: @escaping () -> Void) -> (ButtonConfig, () -> Void) {
        return (ButtonConfig(
            title: "Save",
            systemImage: "checkmark.circle.fill",
            style: .primary
        ), action)
    }
    
    static func cancel(action: @escaping () -> Void) -> (ButtonConfig, () -> Void) {
        return (ButtonConfig(
            title: "Cancel",
            systemImage: "xmark.circle",
            style: .secondary
        ), action)
    }
    
    static func delete(action: @escaping () -> Void) -> (ButtonConfig, () -> Void) {
        return (ButtonConfig(
            title: "Delete",
            systemImage: "trash.fill",
            style: .destructive,
            hapticPattern: "errorFeedback"
        ), action)
    }
}

// MARK: - Preview

#Preview("Button Styles") {
    VStack(spacing: 16) {
        let (saveConfig, saveAction) = ButtonConfig.save { print("Save tapped") }
        UnifiedButton(config: saveConfig, action: saveAction)
        
        let (cancelConfig, cancelAction) = ButtonConfig.cancel { print("Cancel tapped") }
        UnifiedButton(config: cancelConfig, action: cancelAction)
        
        let (deleteConfig, deleteAction) = ButtonConfig.delete { print("Delete tapped") }
        UnifiedButton(config: deleteConfig, action: deleteAction)
        
        HapticButton(
            title: "Test Haptic",
            description: "Gentle tap feedback",
            pattern: "lightTap"
        )
    }
    .padding()
}
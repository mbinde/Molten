//
//  HapticDemoView.swift
//  Flameworker
//
//  Created by Assistant on 9/28/25.
//

import SwiftUI

struct HapticDemoView: View {
    @State private var showingPatternList = false
    @State private var selectedPattern = "lightTap"
    @State private var hapticTrigger = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Basic Haptics")) {
                    HapticButton(title: "Light Impact", 
                               description: "Gentle tap feedback",
                               pattern: "lightTap")
                    
                    HapticButton(title: "Medium Impact", 
                               description: "Standard tap feedback", 
                               pattern: "mediumTap")
                    
                    HapticButton(title: "Heavy Impact", 
                               description: "Strong tap feedback", 
                               pattern: "heavyTap")
                }
                
                Section(header: Text("Notification Haptics")) {
                    HapticButton(title: "Success", 
                               description: "Task completed successfully", 
                               pattern: "successFeedback")
                    
                    HapticButton(title: "Warning", 
                               description: "Attention needed", 
                               pattern: "warningFeedback")
                    
                    HapticButton(title: "Error", 
                               description: "Something went wrong", 
                               pattern: "errorFeedback")
                }
                
                Section(header: Text("Interaction Haptics")) {
                    HapticButton(title: "Selection", 
                               description: "Item selection or focus change", 
                               pattern: "selectionFeedback")
                }
                
                Section(header: Text("Custom Patterns")) {
                    HapticButton(title: "Delete Pattern", 
                               description: "Double-tap pattern for destructive actions", 
                               pattern: "customDeletePattern")
                    
                    HapticButton(title: "Refresh Pattern", 
                               description: "Progressive intensity for refresh actions", 
                               pattern: "refreshPattern")
                }
                
                Section(header: Text("Pattern Library Info")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Patterns: \(HapticService.shared.availablePatterns.count)")
                            .font(.headline)
                        
                        ForEach(HapticService.shared.availablePatterns, id: \.self) { pattern in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pattern)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let description = HapticService.shared.description(for: pattern) {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Haptic Patterns")
            .toolbar {
                ToolbarItem {
                    Button("Test All") {
                        testAllPatterns()
                    }
                }
            }
        }
    }
    
    private func testAllPatterns() {
        let patterns = HapticService.shared.availablePatterns
        
        for (index, pattern) in patterns.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                print("🎯 Testing pattern: \(pattern)")
                HapticService.shared.playPattern(named: pattern)
            }
        }
    }
}

struct HapticButton: View {
    let title: String
    let description: String
    let pattern: String
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticService.shared.playPattern(named: pattern)
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isPressed ? Color.gray.opacity(0.2) : Color.clear)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct HapticDemoView_Previews: PreviewProvider {
    static var previews: some View {
        HapticDemoView()
    }
}
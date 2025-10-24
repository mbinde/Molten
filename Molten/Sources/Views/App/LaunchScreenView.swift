//
//  LaunchScreenView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LaunchScreenView: View {
    @State private var isAnimating = false

    var body: some View {
        print("⏱️ [STARTUP] LaunchScreenView.body evaluated at \(Date())")
        return ZStack {
            // Background color
            Color.black
                .ignoresSafeArea()
            
            // Main content - try to load image from bundle
            Image("Molten")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            // Loading indicator overlay (appears on both image and fallback)
            VStack {
                Spacer()
                
                // Loading indicator at bottom of screen
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(0.8)
                    
                    Text("Loading catalog data...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 60) // Safe distance from bottom
            }
        }
        .scaleEffect(isAnimating ? 1.0 : 0.6)
        .opacity(isAnimating ? 1.0 : 0.0)
        .animation(.easeOut(duration: 0.8), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    LaunchScreenView()
}
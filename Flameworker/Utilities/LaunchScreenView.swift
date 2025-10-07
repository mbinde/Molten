//
//  LaunchScreenView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background color
            Color.black
                .ignoresSafeArea()
            
            // Main content (image or fallback)
            if let _ = UIImage(named: "Flameworker") {
                // Your custom Flameworker logo (full screen as original)
                Image("Flameworker")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // Fallback to system image with app name
                VStack(spacing: 24) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.orange)
                    
                    Text("Flameworker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
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
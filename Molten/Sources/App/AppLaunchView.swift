//
//  AppLaunchView.swift
//  Flameworker
//
//  Created by Assistant on 10/6/25.
//

import SwiftUI

struct MoltenSplashView: View {
    @State private var animateGlow = false
    @State private var animateRotation = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.background,
                    DesignSystem.Colors.backgroundInputLight.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // App icon/logo area
                VStack(spacing: 20) {
                    // Main icon - using eyedropper as the app icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(animateGlow ? 1.1 : 1.0)
                            .opacity(animateGlow ? 0.8 : 1.0)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: animateGlow
                            )
                        
                        Image(systemName: "eyedropper.halffull")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(animateRotation ? 360 : 0))
                            .animation(
                                .linear(duration: 8.0).repeatForever(autoreverses: false),
                                value: animateRotation
                            )
                    }
                    
                    // App name
                    Text("Molten")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Glass Color Catalog")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Loading section
                VStack(spacing: 16) {
                    // Loading indicator
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Loading catalog data...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Animated loading dots
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(.secondary)
                                .frame(width: 8, height: 8)
                                .scaleEffect(animateGlow ? 1.2 : 0.8)
                                .opacity(animateGlow ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.2),
                                    value: animateGlow
                                )
                        }
                    }
                }
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Start animations
            animateGlow = true
            animateRotation = true
        }
    }
}

#Preview {
    MoltenSplashView()
}

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
            
            // Temporary: Use system image until you add your custom image
            // Replace this with Image("Flameworker") once you add the image properly
            if let _ = UIImage(named: "Flameworker") {
                // Your custom Flameworker logo (if it exists)
                Image("Flameworker")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped() // Prevents image from extending beyond bounds
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
# ML Image Generation Integration

This document describes how to integrate AI-generated color palette images into the Molten iOS app.

## Overview

The molten-website now includes an API endpoint that generates abstract background images from glass color palettes using Cloudflare Workers AI (Stable Diffusion XL).

## API Endpoint

**URL:** `https://molten.glass/api/v1/generate-color-image`

**See full documentation:** `/Users/binde/molten-website/COLOR-IMAGE-GENERATION.md`

## Quick Integration

### 1. Create the Service

Add to `Molten/Sources/Services/ColorImageService.swift`:

```swift
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

protocol ColorImageServiceProtocol: Sendable {
    func generateImage(from colors: [(hex: String, weight: Double)], style: [String]) async throws -> Data
}

struct ColorImageService: ColorImageServiceProtocol {
    private let baseURL = "https://molten.glass"

    func generateImage(from colors: [(hex: String, weight: Double)], style: [String] = []) async throws -> Data {
        let endpoint = URL(string: "\(baseURL)/api/v1/generate-color-image")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "colors": colors.map { ["hex": $0.hex, "weight": $0.weight] },
            "style": style,
            "width": 512,
            "height": 512
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return data
    }
}
```

### 2. Add to AppDependencies

In `Molten/Sources/App/AppDependencies.swift`:

```swift
extension AppDependencies {
    var colorImageService: ColorImageServiceProtocol {
        ColorImageService()
    }
}
```

### 3. Use in a View

Example: Generate a background for a project based on its glass colors:

```swift
import SwiftUI

struct ProjectBackgroundView: View {
    @State private var backgroundImage: Image?
    @State private var isGenerating = false

    let projectColors: [String] // Hex codes from inventory
    let style: [String] // ["modern", "minimalist"]

    private let imageService = AppDependencies.shared.colorImageService

    var body: some View {
        ZStack {
            if let backgroundImage {
                backgroundImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                Color.gray.opacity(0.2)
            }

            if isGenerating {
                ProgressView("Generating background...")
            }
        }
        .task {
            await generateBackground()
        }
    }

    private func generateBackground() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            // Convert colors to weighted format
            let weightedColors = projectColors.enumerated().map { index, hex in
                let weight = 1.0 / Double(index + 1) // First color gets highest weight
                return (hex: hex, weight: weight)
            }

            let imageData = try await imageService.generateImage(
                from: weightedColors,
                style: style
            )

            #if canImport(UIKit)
            if let uiImage = UIImage(data: imageData) {
                backgroundImage = Image(uiImage: uiImage)
            }
            #elseif canImport(AppKit)
            if let nsImage = NSImage(data: imageData) {
                backgroundImage = Image(nsImage: nsImage)
            }
            #endif

        } catch {
            print("Failed to generate background: \(error)")
        }
    }
}
```

## Use Cases

### 1. Project View Backgrounds
Generate unique backgrounds for each project based on the glass colors used:

```swift
let projectColors = ["#4A90E2", "#F5A623", "#7ED321"] // From inventory
ProjectBackgroundView(projectColors: projectColors, style: ["modern"])
```

### 2. Seasonal Shopping Lists
Create themed shopping list backgrounds:

```swift
// Halloween shopping list
generateImage(colors: [
    ("#FF8C00", 0.4),
    ("#800080", 0.3),
    ("#000000", 0.3)
], style: ["spooky", "dark"])

// Christmas shopping list
generateImage(colors: [
    ("#DC143C", 0.4),
    ("#006400", 0.4),
    ("#FFD700", 0.2)
], style: ["festive", "christmas"])
```

### 3. Inventory Color Visualization
Show all colors in your inventory as an abstract composition:

```swift
// Get all unique colors from inventory
let inventoryColors = await inventoryService.getAllColors()
let weightedByQuantity = inventoryColors.map { color in
    (hex: color.hex, weight: Double(color.quantity) / totalQuantity)
}
generateImage(from: weightedByQuantity, style: ["vibrant", "artistic"])
```

## Cost & Performance

- **Free tier:** 200-1000 images/day (Cloudflare Workers AI)
- **Generation time:** 3-10 seconds
- **Caching:** 24 hours (subsequent requests are instant)
- **Image size:** 512x512 recommended (fast), max 2048x2048

## Testing Locally

Before integrating into the iOS app, test the API:

```bash
cd /Users/binde/molten-website
./test-color-image.sh
```

This generates three test images to verify everything works.

## Deployment

The API deploys automatically when you push to git:

```bash
cd /Users/binde/molten-website
git push origin ml-image
```

Once merged to main, it's available at `https://molten.glass/api/v1/generate-color-image`

## Limitations

1. **Not color-accurate**: Colors are interpreted through text (e.g., "#4A90E2" → "cerulean blue"), so expect approximations
2. **Non-deterministic**: Same prompt may generate different images each time
3. **Requires network**: Can't generate offline
4. **Generation time**: 3-10 seconds per image

This makes it perfect for **decorative backgrounds**, but not for color-accurate mockups.

## Next Steps

1. Test the API endpoint (run `test-color-image.sh` in molten-website)
2. Create `ColorImageService.swift` in the Molten app
3. Add to `AppDependencies.swift`
4. Build a simple test view to try it out
5. Consider adding to Project views or Shopping lists

See `/Users/binde/molten-website/COLOR-IMAGE-GENERATION.md` for complete API documentation.

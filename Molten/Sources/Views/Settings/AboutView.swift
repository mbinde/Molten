//
//  AboutView.swift
//  Flameworker
//
//  Created by Assistant on 10/5/25.
//

import SwiftUI

struct AboutView: View {
    
    // Helper function to create bullet point list
    private func makeBulletPointList(_ items: [String]) -> String {
        return items.map { "• \($0)" }.joined(separator: "\n")
    }
    
    // Properties to provide access to information (for testing)
    var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildVersion: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var coreDataModelVersion: String? {
        CoreDataVersionInfo.shared.displayVersion
    }
    
    var modelHash: String? {
        CoreDataVersionInfo.shared.currentModelHash
    }
    
    let emailAddress = "info@moltenglass.app"
    let emailSubject = "Feedback on Molten"
    
    var body: some View {
        List {
            Section("About Molten") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hi! 👋")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("By day, I work in tech. By night (and weekends, and any spare moment really), I'm all about making things—quilts, drawings, fused glass, pen turning, you name it. For those crafts, tracking everything in a spreadsheet worked just fine.")
                    Spacer()
                    Text("But then I discovered flameworking, and everything changed! 🔥")
                    Spacer()
                    Text("Suddenly I needed something totally different. I didn't want my laptop anywhere near the torch, but I still needed quick access to glass details, inventory tracking, and project ideas. So... I built Molten!")
                    Spacer()
                    Text("What's coming next? I'm already working on:")
                        .fontWeight(.semibold)
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(["Adding your own custom items (think murrini, special finds, etc.)", "Purchase tracking with printable labels for new rods", "Tool inventory and wishlists (because we all have a wishlist, right?)", "Project logging with image text recognition and glass tracking", "Tutorial library to save your favorites and link them to your projects"], id: \.self) { item in
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(item)
                                Spacer()
                            }
                        }
                    }
                    Spacer()
                    Text("Got ideas for features you'd love to see? I'd love to hear from you! Drop me a line at ") +
                    Text("[\(emailAddress)](mailto:\(emailAddress)?subject=\(emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))")
                }
            }

            Section("Image Rights") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A huge thank you to these awesome folks who've generously shared their product images:")
                        .font(.subheadline)

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Frantz Art Glass & Supply (Effetre/Moretti/Vetrofond)")
                            Spacer()
                        }
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Double Helix Glassworks")
                            Spacer()
                        }
                    }

                    Spacer()

                    Text("I'm still hunting for great product photos of Creation is Messy glass! And if you're a glass manufacturer who'd like to see your products in Molten, I'd love to chat—reach out at ") +
                    Text("[info@moltenglassapp.com](mailto:info@moltenglassapp.com?subject=Product%20Images%20for%20Molten)")
                }
            }

            Section("Application") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text(buildVersion ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Core Data") {
                HStack {
                    Text("Model Version")
                    Spacer()
                    Text(coreDataModelVersion ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Model Hash")
                    Spacer()
                    Text(modelHash ?? "Unknown")
                        .foregroundColor(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .navigationTitle("About")
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

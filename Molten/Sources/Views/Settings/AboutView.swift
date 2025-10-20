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
                    Text("Hi there.")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("By day, I work in tech. In my spare time, I make things—quilts, drawings, fused glass, pen turning, and more. For those crafts, tracking everything in a spreadsheet worked fine.")
                    Spacer()
                    Text("But flameworking was different. I needed quick access to glass details, inventory tracking, and project ideas—all without bringing my laptop near the torch. That's why I built Molten.")
                    Spacer()
                    Text("Currently in development:")
                        .fontWeight(.semibold)
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(["Custom items (murrini, special finds, and more)", "Purchase tracking with printable labels", "Tool inventory and wishlists", "Project logging with image recognition and glass tracking", "Tutorial library with project linking"], id: \.self) { item in
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(item)
                                Spacer()
                            }
                        }
                    }
                    Spacer()
                    Text("Have feature suggestions or feedback? Reach out at ") +
                    Text("[\(emailAddress)](mailto:\(emailAddress)?subject=\(emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))")
                }
            }

            Section("Image Rights") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thank you to these manufacturers for providing product images:")
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

                    Text("Looking for product photos of Creation is Messy glass. Glass manufacturers interested in being featured in Molten can reach out at ") +
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

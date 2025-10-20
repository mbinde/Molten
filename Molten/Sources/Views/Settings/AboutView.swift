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
            Section("") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By day, I work in tech. In my spare time, I make things. In the past, tracking my inventory and projects on my laptop was a perfect solution.")
                    Spacer()
                    Text("But hot glass was different: I needed quick access to glass details, inventory tracking, and project ideas—all without bringing my laptop near an open flame. That's why I built Molten.")
                    Spacer()
                    Text("Have feature suggestions or feedback? Reach out at ") +
                    Text("[\(emailAddress)](mailto:\(emailAddress)?subject=\(emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))")
                }
            }

            Section("Image Rights") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thank you to these individuals, sites, and manufacturers for providing their permission for product images and descriptions:")
                        .font(.subheadline)

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Bullseye Glass")
                            Spacer()
                        }
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Double Helix Glassworks")
                            Spacer()
                        }
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Frantz Art Glass (Effetre/Moretti/Vetrofond)")
                            Spacer()
                        }
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Glass Alchemy")
                            Spacer()
                        }
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Greasy Color")
                            Spacer()
                        }
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Youghiogheny Glass")
                            Spacer()
                        }
                    }

                    Spacer()

                    Text("I'm looking for product photos of Creation is Messy glass in particular, as I do not have access to any photos I can use with permission yet.")
                    Spacer()
                    Text("If you have the rights to CiM images, or any other glass images, and are interested in having them included in Molten, please reach out at ") +
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

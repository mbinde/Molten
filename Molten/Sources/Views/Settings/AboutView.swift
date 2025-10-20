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
                    Text("My day job is in the tech industry, but my side gig has always been some form of art or craft. When that work has been more self-contained, such as quilting, drawing, glass fusing, or turning pens on a lathe, it's been much more doable to track my inventory, tools, projects, plans, and ideas on a laptop.")
                    Spacer()
                    Text("After starting flameworking however, I realized I would need a very different solution than another  mega-spreadsheet, because I didn't want to have my laptop near the torch, but still wanted to be able to easily see details on unfamiliar glass, track when I needed to buy more of a particular color, and remember what I wanted to work on next.")
                    Spacer()
                    Text("Currently this app is very basic, but I already have several other features mostly completed:")
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(["Adding your own catalog items (e.g. murrini)", "Recording purchases, and printing labels for rods based on everything added past a particular date", "Tool inventory and wishlists", "Project log, including text recognition within the images, and tracking which glass you used for each project", "Tutorial/instructions, whether yours or others, and linking projects to them"], id: \.self) { item in
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(item)
                                Spacer()
                            }
                        }
                    }
                    Spacer()
                    Text("If there are other features you would find useful, please reach out to me at ") +
                    Text("[\(emailAddress)](mailto:\(emailAddress)?subject=\(emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))")
                }
            }

            Section("Image Rights") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Product imagery displayed within this application is used with express written permission from the following sources:")
                        .font(.subheadline)

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Effetre/Moretti/Vetrofond glass imagery courtesy of Frantz Art Glass & Supply")
                            Spacer()
                        }
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("Double Helix glass imagery courtesy of Double Helix Glassworks")
                            Spacer()
                        }
                    }

                    Spacer()

                    Text("We are actively seeking high-quality product images for Creation is Messy glass. Additionally, glass manufacturers interested in having their products included in this application are encouraged to contact us at ") +
                    Text("[info@moltenglassapp.com](mailto:info@moltenglassapp.com?subject=Product%20Images%20for%20Flameworker)")
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

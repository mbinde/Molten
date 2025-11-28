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

    var buildVersion: String {
        BuildInfo.fullBuildString
    }
    
    var coreDataModelVersion: String? {
        CoreDataVersionInfo.shared.displayVersion
    }

    var modelHash: String? {
        CoreDataVersionInfo.shared.currentModelHash
    }

    /// Combined Core Data version string (e.g., "27 (abc1234)")
    var coreDataVersionString: String {
        let version = coreDataModelVersion ?? "Unknown"
        if let hash = modelHash {
            let shortHash = String(hash.prefix(8))
            return "\(version) (\(shortHash))"
        }
        return version
    }
    
    let emailAddress = "info@moltenglass.app"
    let emailSubject = "Feedback on Molten"

    /// List of manufacturers who have granted image permission, sorted alphabetically by display name
    private var manufacturersWithPermission: [String] {
        // Get all codes with permission, excluding duplicates like MOR (same as EF)
        let codesWithPermission = GlassManufacturers.productImagePermissions
            .filter { $0.value == true && $0.key != "MOR" }  // Exclude MOR (duplicate of Effetre)
            .map { $0.key }

        // Convert to full names
        var names = codesWithPermission.compactMap { code -> String? in
            // Special case: group Effetre/Moretti/Vetrofond under Frantz Art Glass
            if code == "EF" || code == "VF" {
                return nil  // Handle separately
            }
            return GlassManufacturers.fullName(for: code)
        }

        // Add grouped entry for Frantz Art Glass
        names.append("Frantz Art Glass (Effetre/Moretti/Vetrofond)")

        // Sort all names alphabetically
        return names.sorted()
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("By day, I work in tech. In my spare time, I make things. With hot glass, I needed quick access to glass details, inventory tracking, and project ideas—all without bringing my laptop near an open flame. That's why I built Molten.")
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Have feature suggestions or feedback? Reach out at [\(emailAddress)](mailto:\(emailAddress)?subject=\(emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))")
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .tint(DesignSystem.Colors.moltenTeal)
                }
            }

            Section("Image Rights") {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Thank you to these individuals, sites, and manufacturers for providing their permission for product images and descriptions:")
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        ForEach(manufacturersWithPermission, id: \.self) { name in
                            contributorRow(name)
                        }
                    }

                    Text("If you have the rights to images of glass or coatings and are interested in having them included in Molten, please reach out at [info@moltenglassapp.com](mailto:info@moltenglassapp.com?subject=Product%20Images%20for%20Molten)")
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .tint(DesignSystem.Colors.moltenTeal)
                }
            }

            Section("Application") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion ?? "Unknown")
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                copyableRow(label: "Build", value: buildVersion)
            }

            Section("Core Data") {
                copyableRow(label: "Model", value: coreDataVersionString)
            }
        }
        .navigationTitle("About")
    }

    // MARK: - Helper Views

    private func contributorRow(_ name: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "flame.fill")
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.moltenOrange)
            Text(name)
                .font(DesignSystem.Typography.listItemSubtitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Spacer()
        }
    }

    @State private var copiedValue: String?

    private func copyableRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.listItemSubtitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Button {
                UIPasteboard.general.string = value
                copiedValue = value
                // Reset after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if copiedValue == value {
                        copiedValue = nil
                    }
                }
            } label: {
                Image(systemName: copiedValue == value ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(copiedValue == value ? DesignSystem.Colors.moltenTeal : DesignSystem.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

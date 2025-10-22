//
//  AuthorInclusionSection.swift
//  Molten
//
//  Reusable section for including author information in exports
//

import SwiftUI

/// Reusable section for toggling author inclusion in exports (PDF, .moltenplan)
/// Shows three states:
/// 1. Plan already has author (read-only)
/// 2. User has author info (toggle + preview + edit)
/// 3. No author info (prompt to create)
struct AuthorInclusionSection: View {
    let plan: ProjectPlanModel
    @Binding var includeAuthor: Bool
    @Binding var showingAuthorSettings: Bool

    @StateObject private var authorSettings = AuthorSettings.shared

    var body: some View {
        // If plan already has an author (imported from someone else), show it as read-only
        if let existingAuthor = plan.author {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This plan includes author information from the original creator:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    AuthorCardView(author: existingAuthor)
                }
            } header: {
                Text("Original Author")
            } footer: {
                Text("The original author information will be included in the export.")
            }
        }
        // If user has author info and plan doesn't have an author, show with toggle
        else if authorSettings.hasAuthorInfo, let authorModel = authorSettings.createAuthorModel() {
            Section {
                Toggle("Include My Author Information", isOn: $includeAuthor)
                    .font(.headline)

                if includeAuthor {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Preview:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(action: {
                                showingAuthorSettings = true
                            }) {
                                Label("Edit", systemImage: "pencil")
                                    .font(.caption)
                            }
                        }

                        AuthorCardView(author: authorModel)
                    }
                    .padding(.top, 8)
                }
            } header: {
                Text("Author Information")
            } footer: {
                if includeAuthor {
                    Text("Your author information will be included in the export, letting others know who created it.")
                } else {
                    Text("Enable to include your author information in the export.")
                }
            }
        }
        // User has no author info - suggest creating one
        else {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optionally include your name and contact information in the export")
                        .font(.subheadline)

                    Button(action: {
                        showingAuthorSettings = true
                    }) {
                        Label("Set Up Author Profile", systemImage: "person.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Author Information")
            } footer: {
                Text("Adding author information is optional, but helps others know who created the plan.")
            }
        }
    }
}

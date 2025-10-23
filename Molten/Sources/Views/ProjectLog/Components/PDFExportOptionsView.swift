//
//  PDFExportOptionsView.swift
//  Molten
//
//  View for selecting PDF export options including author information
//

import SwiftUI

struct PDFExportOptionsView: View {
    let plan: ProjectModel
    let onExport: (Bool) -> Void  // Callback with includeAuthor parameter
    @Environment(\.dismiss) private var dismiss

    @State private var includeAuthor = true
    @State private var showingAuthorSettings = false
    @StateObject private var authorSettings = AuthorSettings.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                        if let summary = plan.summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Author Section
                AuthorInclusionSection(
                    plan: plan,
                    includeAuthor: $includeAuthor,
                    showingAuthorSettings: $showingAuthorSettings
                )
            }
            .navigationTitle("Export PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        let shouldIncludeAuthor = plan.author == nil && includeAuthor && authorSettings.hasAuthorInfo
                        onExport(shouldIncludeAuthor)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAuthorSettings) {
                NavigationStack {
                    AuthorSettingsView()
                }
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var authorSection: some View {
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
                Text("The original author information will be included in the PDF.")
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
                    Text("Your author information will be included in the PDF, appearing after the plan details.")
                } else {
                    Text("Enable to include your author information in the PDF.")
                }
            }
        }
        // User has no author info - suggest creating one
        else {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Optionally include your name and contact information in the PDF")
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

#Preview {
    PDFExportOptionsView(
        plan: ProjectModel(
            title: "Sample Plan",
            type: .recipe,
            coe: "96",
            summary: "A sample project plan for preview"
        ),
        onExport: { _ in }
    )
}

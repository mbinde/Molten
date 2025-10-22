//
//  AuthorSettingsView.swift
//  Molten
//
//  View for managing user's author profile information
//

import SwiftUI

struct AuthorSettingsView: View {
    @StateObject private var authorSettings = AuthorSettings.shared
    @State private var showingClearConfirmation = false
    @Environment(\.dismiss) private var dismiss

    // Store original values for cancel functionality
    @State private var originalName = ""
    @State private var originalEmail = ""
    @State private var originalWebsite = ""
    @State private var originalInstagram = ""
    @State private var originalFacebook = ""
    @State private var originalYouTube = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your author information will be included when you export project plans, helping others know who created them.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Personal Information") {
                TextField("Name", text: $authorSettings.name)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif

                TextField("Email (optional)", text: $authorSettings.email)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    #if canImport(UIKit)
                    .keyboardType(.emailAddress)
                    #endif
            }

            Section("Online Presence") {
                TextField("Website (optional)", text: $authorSettings.website)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    #if canImport(UIKit)
                    .keyboardType(.URL)
                    #endif

                TextField("Instagram Username (optional)", text: $authorSettings.instagram)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                TextField("Facebook Page (optional)", text: $authorSettings.facebook)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()

                TextField("YouTube Handle (optional)", text: $authorSettings.youtube)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }

            // Preview section
            if authorSettings.hasAuthorInfo {
                Section("Preview") {
                    if let authorModel = authorSettings.createAuthorModel() {
                        AuthorCardView(author: authorModel)
                    }
                }

                Section {
                    Button("Clear All Information") {
                        showingClearConfirmation = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Author Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Revert all changes") {
                    cancelChanges()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            storeOriginalValues()
        }
        .alert("Clear Author Information?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                authorSettings.clear()
            }
        } message: {
            Text("This will remove all your author information. You can add it again later.")
        }
    }

    private func storeOriginalValues() {
        originalName = authorSettings.name
        originalEmail = authorSettings.email
        originalWebsite = authorSettings.website
        originalInstagram = authorSettings.instagram
        originalFacebook = authorSettings.facebook
        originalYouTube = authorSettings.youtube
    }

    private func cancelChanges() {
        authorSettings.name = originalName
        authorSettings.email = originalEmail
        authorSettings.website = originalWebsite
        authorSettings.instagram = originalInstagram
        authorSettings.facebook = originalFacebook
        authorSettings.youtube = originalYouTube
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AuthorSettingsView()
    }
}

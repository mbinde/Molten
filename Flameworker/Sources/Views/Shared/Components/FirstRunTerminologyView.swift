//
//  FirstRunTerminologyView.swift
//  Flameworker
//
//  First-run onboarding screen for selecting glass working terminology preferences.
//  Created by Assistant on 10/19/25.
//

import SwiftUI

struct FirstRunTerminologyView: View {

    @ObservedObject var settings = GlassTerminologySettings.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedHotShop = false
    @State private var selectedFlameworking = true  // Default for this app

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image("Flameworker")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)

                    Text("Welcome to Molten!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("What type of glass working do you do?")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                Spacer()

                // Terminology Options
                VStack(spacing: 20) {
                    TerminologyToggleCard(
                        isSelected: $selectedHotShop,
                        title: "Hot Shop / Glass Blowing",
                        icon: "fireplace.fill",
                        description: "Work primarily with large rods (12mm+)"
                    )

                    TerminologyToggleCard(
                        isSelected: $selectedFlameworking,
                        title: "Flameworking / Fusing",
                        icon: "flame",
                        description: "Work primarily with smaller rods (2-10mm+)"
                    )
                }
                .padding(.horizontal)

                // Explanation
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.headline)

                        Text(explanationText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    #if os(iOS)
                    .background(Color(.systemBackground))
                    #else
                    .background(Color(nsColor: .windowBackgroundColor))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            #if os(iOS)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                            #else
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            #endif
                    )
                }
                .padding(.horizontal)

                Spacer()

                // Continue Button
                VStack(spacing: 8) {
                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canProceed ? Color.accentColor : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canProceed)

                    Text("You can change this anytime in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        // Use default settings
                        settings.enableHotShop = false
                        settings.enableFlameworking = true
                        settings.hasCompletedOnboarding = true
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Skip") {
                        // Use default settings
                        settings.enableHotShop = false
                        settings.enableFlameworking = true
                        settings.hasCompletedOnboarding = true
                        dismiss()
                    }
                }
                #endif
            }
        }
    }

    // MARK: - Computed Properties

    private var canProceed: Bool {
        selectedHotShop || selectedFlameworking
    }

    private var explanationText: String {
        switch (selectedHotShop, selectedFlameworking) {
        case (true, true):
            return """
            Both terminologies enabled:
            • Large rods (12mm+) will be called "Rods"
            • Standard rods (1-10mm+) will be called "Cane"

            This keeps both types distinct.
            """

        case (true, false):
            return """
            "Rod" will mean hot shop rods (12mm+).
            Flameworking rods will be hidden.
            """

        case (false, true):
            return """
            "Rod" will mean flameworking rods (2-10mm+).
            Hot shop rods will be hidden.
            """

        case (false, false):
            return "Please select at least one option to continue."
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        settings.enableHotShop = selectedHotShop
        settings.enableFlameworking = selectedFlameworking
        settings.validateSettings()
        settings.hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Supporting Views

struct TerminologyToggleCard: View {
    @Binding var isSelected: Bool
    let title: String
    let icon: String
    let description: String

    var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            #if os(iOS)
                            .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                            #else
                            .fill(isSelected ? Color.accentColor : Color(nsColor: .separatorColor))
                            #endif
                    )

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .primary : .primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    #if os(iOS)
                    .fill(Color(.systemBackground))
                    #else
                    .fill(Color(nsColor: .windowBackgroundColor))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            #if os(iOS)
                            .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                            #else
                            .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
                            #endif
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FirstRunTerminologyView()
}

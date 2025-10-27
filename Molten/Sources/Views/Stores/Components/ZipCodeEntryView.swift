//
//  ZipCodeEntryView.swift
//  Molten
//
//  Created for Store Maps Feature on 10/27/25.
//

import SwiftUI

/// Sheet view for entering zip code to set manual location
///
/// Shown when user hasn't granted location permission.
/// Uses geocoding to convert zip code to coordinates.
struct ZipCodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: StoreListViewModel

    @State private var zipCode: String = ""
    @State private var isGeocoding: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Icon
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .padding(.top, DesignSystem.Spacing.xl)

                // Title and description
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Set Your Location")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enter your zip code to find nearby stores")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Zip code input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    TextField("Zip Code", text: $zipCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .disabled(isGeocoding)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)

                // Submit button
                Button(action: setLocation) {
                    if isGeocoding {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Set Location")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(zipCode.isEmpty || isGeocoding)

                Spacer()

                // Privacy note
                Text("We only use your zip code to show nearby stores. Your location is not stored or shared.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func setLocation() {
        errorMessage = nil
        isGeocoding = true

        Task {
            await viewModel.setLocationFromZipCode(zipCode)

            await MainActor.run {
                isGeocoding = false

                if viewModel.manualLocation != nil {
                    // Success!
                    dismiss()
                } else {
                    // Failed to geocode
                    errorMessage = "Could not find location for zip code \(zipCode)"
                }
            }
        }
    }
}

#Preview {
    ZipCodeEntryView(viewModel: StoreListViewModel())
}

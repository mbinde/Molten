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
                // Zip code input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Enter your zip code")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Zip Code", text: $zipCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Padding.compact)
                        .background(Color(.systemGray6))
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .disabled(isGeocoding)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Submit button
                Button(action: setLocation) {
                    if isGeocoding {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Set Location")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(!zipCode.isEmpty && !isGeocoding ? Color.accentColor : Color(.systemGray4))
                .foregroundStyle(.white)
                .cornerRadius(DesignSystem.CornerRadius.medium)
                .disabled(zipCode.isEmpty || isGeocoding)
                .accessibilityIdentifier("zip_code_set_location")

                Spacer()
            }
            .padding(DesignSystem.Padding.standard)
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("zip_code_cancel")
                }
            }
        }
        .presentationDetents([.height(220)])
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

//
//  LocationPickerSheet.swift
//  Molten
//
//  Simple sheet for entering a zip code or city to center the map
//

import SwiftUI
import CoreLocation

struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isGeocoding = false
    @State private var errorMessage: String?

    let onLocationSelected: (CLLocationCoordinate2D) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Text("Enter a location to center the map")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DesignSystem.Padding.standard)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    TextField("City, State or Zip Code", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(DesignSystem.Padding.standard)
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(DesignSystem.CornerRadius.medium)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit {
                            geocodeLocation()
                        }

                    if let error = errorMessage {
                        Text(error)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, DesignSystem.Padding.standard)

                // Example suggestions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Examples:")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    ForEach(["Seattle, WA", "Portland, OR", "97202"], id: \.self) { example in
                        Button {
                            searchText = example
                            geocodeLocation()
                        } label: {
                            Text(example)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.accentPrimary)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Padding.standard)

                Spacer()
            }
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isGeocoding {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func geocodeLocation() {
        guard !searchText.isEmpty else { return }

        isGeocoding = true
        errorMessage = nil

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            isGeocoding = false

            if let error = error {
                errorMessage = "Could not find location. Try a different search term."
                return
            }

            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                errorMessage = "Could not find location. Try a different search term."
                return
            }

            // Success - return the coordinate
            onLocationSelected(location.coordinate)
        }
    }
}

#Preview {
    LocationPickerSheet { coordinate in
        print("Selected: \(coordinate)")
    }
}

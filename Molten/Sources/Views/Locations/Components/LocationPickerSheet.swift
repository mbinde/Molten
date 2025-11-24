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
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Title
            Text("Center the map")
                .font(.headline)
                .padding(.top, DesignSystem.Padding.standard)

            // Text field
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                TextField("City, State or Zip Code", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(DesignSystem.Padding.standard)
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.go)
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

            // Buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("location_picker_cancel")

                Button("Go") {
                    geocodeLocation()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(searchText.isEmpty)
                .accessibilityIdentifier("location_picker_go")
            }
            .padding(.horizontal, DesignSystem.Padding.standard)
            .padding(.bottom, DesignSystem.Padding.standard)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemBackground))
        .overlay {
            if isGeocoding {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }

    private func geocodeLocation() {
        guard !searchText.isEmpty else { return }

        isGeocoding = true
        errorMessage = nil

        let geocoder = CLGeocoder()

        Task {
            do {
                // Add timeout to prevent infinite spinning
                let placemarks = try await withTimeout(seconds: 10) {
                    try await geocoder.geocodeAddressString(searchText)
                }

                await MainActor.run {
                    isGeocoding = false

                    guard let placemark = placemarks.first,
                          let location = placemark.location else {
                        errorMessage = "Could not find location. Try a different search term."
                        return
                    }

                    // Success - return the coordinate
                    onLocationSelected(location.coordinate)
                }
            } catch is CancellationError {
                await MainActor.run {
                    isGeocoding = false
                    errorMessage = "Location lookup timed out. Check your network connection."
                }
            } catch {
                await MainActor.run {
                    isGeocoding = false
                    errorMessage = "Could not find location. Try a different search term."
                }
            }
        }
    }

    // Helper for timeout
    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

#Preview {
    LocationPickerSheet { coordinate in
        print("Selected: \(coordinate)")
    }
}

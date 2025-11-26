//
//  RatingSettingsView.swift
//  Molten
//
//  Settings view for managing rating system preferences
//

import SwiftUI

struct RatingSettingsView: View {
    @AppStorage("ratingsUpdateInterval") private var updateInterval: Int = 3600
    @State private var pendingCount: Int = 0
    @State private var isLoadingPending = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var deletedCount: Int?

    private let service: RatingService

    init(service: RatingService = AppDependencies.shared.ratingService) {
        self.service = service
    }

    var body: some View {
        List {
            Section {
                Picker("Update Frequency", selection: $updateInterval) {
                    Text("1 Hour").tag(3600)
                    Text("6 Hours").tag(21600)
                    Text("12 Hours").tag(43200)
                    Text("Daily").tag(86400)
                    Text("Weekly").tag(604800)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Cache Settings")
            } footer: {
                Text("How often to refresh community ratings from the server. Ratings are cached locally for better performance.")
            }

            Section {
                HStack {
                    Text("Pending Submissions")
                    Spacer()
                    if isLoadingPending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("\(pendingCount)")
                            .foregroundColor(.secondary)
                    }
                }

                if pendingCount > 0 {
                    Button {
                        processPendingSubmissions()
                    } label: {
                        Label("Upload Now", systemImage: "arrow.up.circle")
                    }
                    .disabled(isLoadingPending)
                    .accessibilityIdentifier("rating_settings_upload_now")
                }
            } header: {
                Text("Offline Queue")
            } footer: {
                Text("Ratings are queued when submitted offline and automatically uploaded when you're back online.")
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .controlSize(.small)
                            Text("Deleting...")
                        } else {
                            Label("Delete All My Ratings and Words", systemImage: "trash")
                        }
                    }
                }
                .disabled(isDeleting)
                .accessibilityIdentifier("rating_settings_delete_all")

                if let count = deletedCount {
                    Text("Successfully deleted \(count) rating\(count == 1 ? "" : "s") and words. It may take the server a few hours to rebuild its cache, but your individual ratings and words have been deleted completely.")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Permanently delete all your rating submissions and words from the server. This action cannot be undone and is GDPR-compliant.")
            }
        }
        .navigationTitle("Rating Settings")
        .task {
            await loadPendingCount()
        }
        .alert("Delete All Ratings and Words?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllRatings()
            }
        } message: {
            Text("This will permanently delete all your rating submissions and words from the server. This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func loadPendingCount() async {
        isLoadingPending = true
        defer { isLoadingPending = false }

        do {
            pendingCount = try await service.getPendingSubmissionCount()
        } catch {
            print("Failed to load pending count: \(error)")
        }
    }

    private func processPendingSubmissions() {
        Task {
            isLoadingPending = true
            defer { isLoadingPending = false }

            do {
                let successCount = try await service.processPendingSubmissions()
                await MainActor.run {
                    pendingCount = 0
                }
                print("Successfully uploaded \(successCount) pending ratings")
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to upload pending ratings: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func deleteAllRatings() {
        Task {
            isDeleting = true
            defer { isDeleting = false }

            do {
                let count = try await service.deleteAllRatings()

                // Force a fresh fetch of ratings from server (which are now empty)
                _ = try? await service.fetchAllRatingsBulk(forceRefresh: true)

                await MainActor.run {
                    deletedCount = count

                    // Trigger catalog/inventory refresh to update UI
                    NotificationCenter.default.post(name: .ratingSubmitted, object: nil)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete ratings: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RatingSettingsView()
    }
}

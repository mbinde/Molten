//
//  RatingSubmissionView.swift
//  Molten
//
//  View for submitting a rating (star rating + 5 words)
//

import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    static let ratingSubmitted = Notification.Name("ratingSubmitted")
}

struct RatingSubmissionView: View {
    // MARK: - Properties

    let itemStableId: String
    let itemName: String
    @Environment(\.dismiss) private var dismiss

    private let service: RatingService

    @State private var starRating: Int = 3
    @State private var word1: String = ""
    @State private var word2: String = ""
    @State private var word3: String = ""
    @State private var word4: String = ""
    @State private var word5: String = ""

    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Initialization

    init(
        itemStableId: String,
        itemName: String,
        service: RatingService = AppDependencies.shared.ratingService
    ) {
        self.itemStableId = itemStableId
        self.itemName = itemName
        self.service = service
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(itemName)
                        .font(.headline)
                }

                Section("Star Rating") {
                    HStack(spacing: 20) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                starRating = star
                            } label: {
                                Image(systemName: star <= starRating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundStyle(star <= starRating ? .yellow : .gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    VStack(spacing: 12) {
                        WordTextField(number: 1, text: $word1)
                        WordTextField(number: 2, text: $word2)
                        WordTextField(number: 3, text: $word3)
                        WordTextField(number: 4, text: $word4)
                        WordTextField(number: 5, text: $word5)
                    }
                } header: {
                    Text("Describe with Words (Optional)")
                } footer: {
                    Text("Add any number of words (up to 5) to help others understand your rating.")
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Section {
                    Button {
                        submitRating()
                    } label: {
                        if isSubmitting {
                            HStack {
                                ProgressView()
                                Text("Submitting...")
                            }
                        } else {
                            Text("Submit Rating")
                        }
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Rate Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            await loadExistingRating()
        }
    }

    // MARK: - Helpers

    private func loadExistingRating() async {
        // TODO: Load user's existing rating for this item (if any)
        // This would require:
        // 1. RatingService method to fetch user's own rating for an item
        // 2. Server endpoint to return user's rating (not just aggregated)
        // For now, users always start fresh
    }

    private var isFormValid: Bool {
        // Always valid - words are optional, any number from 0-5 is fine
        return true
    }

    private func submitRating() {
        Task {
            isSubmitting = true
            defer { isSubmitting = false }

            do {
                let submission = RatingSubmissionModel(
                    itemStableId: itemStableId,
                    starRating: starRating,
                    words: [word1, word2, word3, word4, word5]
                )

                print("🔍 [RatingSubmissionView] Submitting rating for stable_id: \(itemStableId)")
                try await service.submitRating(submission)
                print("✅ [RatingSubmissionView] Successfully submitted rating for \(itemStableId)")

                // Dismiss sheet FIRST, before notifying
                dismiss()

                // Small delay to ensure sheet is dismissed
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

                // THEN notify (triggers refresh + shows toast on parent view)
                await MainActor.run {
                    NotificationCenter.default.post(name: .ratingSubmitted, object: itemStableId)
                }

            } catch RatingServiceError.queuedForLater {
                // Queued for later - dismiss and notify
                dismiss()
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    NotificationCenter.default.post(name: .ratingSubmitted, object: itemStableId)
                }

            } catch RatingServiceError.profanityDetected {
                errorMessage = "Please use appropriate language in your words."
                showingError = true

            } catch RatingServiceError.validationFailed(let errors) {
                errorMessage = errors.joined(separator: "\n")
                showingError = true

            } catch RatingAPIError.rateLimitExceeded {
                errorMessage = "You've submitted too many ratings. Please try again later."
                showingError = true

            } catch {
                errorMessage = "Failed to submit rating: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

// MARK: - Word Text Field

private struct WordTextField: View {
    let number: Int
    @Binding var text: String

    var body: some View {
        HStack {
            Text("\(number).")
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)

            TextField("word", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Preview

#Preview {
    RatingSubmissionView(
        itemStableId: "bullseye-001-0",
        itemName: "Bullseye 001 Clear"
    )
}

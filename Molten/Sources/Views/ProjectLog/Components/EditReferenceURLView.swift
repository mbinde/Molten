//
//  EditReferenceURLView.swift
//  Molten
//
//  View for editing reference URLs in a project plan
//

import SwiftUI

struct EditReferenceURLView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectPlanModel
    let repository: ProjectPlanRepository
    let urlToEdit: ProjectReferenceUrl

    @State private var url: String
    @State private var title: String
    @State private var urlDescription: String
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var autoFetchTitle = false
    @State private var isFetchingTitle = false
    @State private var fetchedTitle: String?

    init(plan: ProjectPlanModel, repository: ProjectPlanRepository, urlToEdit: ProjectReferenceUrl) {
        self.plan = plan
        self.repository = repository
        self.urlToEdit = urlToEdit

        // Initialize state with existing values
        _url = State(initialValue: urlToEdit.url)
        _title = State(initialValue: urlToEdit.title ?? "")
        _urlDescription = State(initialValue: urlToEdit.description ?? "")
        // Default to manual mode since we already have data
        _autoFetchTitle = State(initialValue: false)
    }

    var body: some View {
        Form {
            Section("URL") {
                TextField("https://example.com", text: $url)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    #if canImport(UIKit)
                    .keyboardType(.URL)
                    #endif
            }

            Section("Title") {
                Picker("Title Source", selection: $autoFetchTitle) {
                    Text("Enter manually").tag(false)
                    Text("Auto-fetch from URL").tag(true)
                }
                .pickerStyle(.segmented)

                if autoFetchTitle {
                    Text("Title will be fetched automatically when you tap Save")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Title")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Tutorial video", text: $title)
                    }
                }
            }

            Section("Description (Optional)") {
                TextField("Add notes about this reference", text: $urlDescription, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Edit Reference URL")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isFetchingTitle)
            }

            ToolbarItem(placement: .confirmationAction) {
                if isFetchingTitle {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task {
                            await saveURL()
                        }
                    }
                    .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func fetchTitleFromURL(_ urlString: String) async {
        // Reset state
        await MainActor.run {
            isFetchingTitle = true
            fetchedTitle = nil
        }

        // Validate URL and upgrade HTTP to HTTPS to avoid ATS issues
        guard var url = URL(string: urlString) else {
            await MainActor.run {
                isFetchingTitle = false
            }
            return
        }

        // Upgrade HTTP to HTTPS to avoid App Transport Security blocking
        if url.scheme == "http" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let httpsURL = components?.url {
                url = httpsURL
            }
        }

        // Ensure we have a valid HTTP(S) URL
        guard let scheme = url.scheme, scheme.hasPrefix("http") else {
            await MainActor.run {
                isFetchingTitle = false
            }
            return
        }

        do {
            // Create a request with timeout
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0

            // Fetch HTML content
            let (data, _) = try await URLSession.shared.data(for: request)

            // Check if task was cancelled
            guard !Task.isCancelled else {
                await MainActor.run {
                    isFetchingTitle = false
                }
                return
            }

            // Convert to string
            guard let html = String(data: data, encoding: .utf8) else {
                await MainActor.run {
                    isFetchingTitle = false
                }
                return
            }

            // Extract title using regex
            let titlePattern = "<title>([^<]+)</title>"
            if let regex = try? NSRegularExpression(pattern: titlePattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               let titleRange = Range(match.range(at: 1), in: html) {
                let extractedTitle = String(html[titleRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")

                await MainActor.run {
                    fetchedTitle = extractedTitle
                    isFetchingTitle = false
                }
            } else {
                await MainActor.run {
                    isFetchingTitle = false
                }
            }
        } catch {
            // Silently fail - just stop showing loading state
            await MainActor.run {
                isFetchingTitle = false
            }
        }
    }

    private func saveURL() async {
        // Validate URL
        guard let _ = URL(string: url) else {
            errorMessage = "Please enter a valid URL"
            showingError = true
            return
        }

        // Fetch title if auto-fetch is enabled
        var finalTitle: String?
        if autoFetchTitle {
            await fetchTitleFromURL(url)
            finalTitle = fetchedTitle
        } else {
            finalTitle = title.isEmpty ? nil : title
        }

        // Create updated reference URL with same ID
        let updatedURL = ProjectReferenceUrl(
            id: urlToEdit.id,  // Keep the same ID
            url: url,
            title: finalTitle,
            description: urlDescription.isEmpty ? nil : urlDescription
        )

        // Replace the URL in the plan's reference URLs array
        var updatedURLs = plan.referenceUrls
        if let index = updatedURLs.firstIndex(where: { $0.id == urlToEdit.id }) {
            updatedURLs[index] = updatedURL
        }

        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: plan.title,
            planType: plan.planType,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            tags: plan.tags,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: updatedURLs,
            author: plan.author,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updatePlan(updatedPlan)
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to save URL: \(error.localizedDescription)"
            showingError = true
        }
    }
}

//
//  ExportPlanView.swift
//  Molten
//
//  View for exporting a project plan with quality options
//

import SwiftUI

struct ExportPlanView: View {
    let plan: ProjectModel
    let onExportComplete: ((URL) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedQuality: ExportQuality = .optimized
    @State private var isExporting = false
    @State private var estimatedSizes: [ExportQuality: (bytes: Int64, formatted: String)] = [:]
    @State private var includeAuthor = true
    @State private var showingAuthorSettings = false

    @StateObject private var authorSettings = AuthorSettings.shared
    private let exportService: ProjectExportService

    init(plan: ProjectModel, onExportComplete: ((URL) -> Void)? = nil) {
        self.plan = plan
        self.onExportComplete = onExportComplete
        self.exportService = ProjectExportService(
            userImageRepository: RepositoryFactory.createUserImageRepository()
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // Plan Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                        if let summary = plan.summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Label("\(plan.images.count)", systemImage: "photo")
                            if !plan.steps.isEmpty {
                                Text("•")
                                Label("\(plan.steps.count)", systemImage: "list.number")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Quality Options
                Section {
                    ForEach(ExportQuality.allCases) { quality in
                        qualityOption(quality)
                    }
                } header: {
                    Text("Export Quality")
                } footer: {
                    sharingMethodsFooter
                }

                // Author Section
                AuthorInclusionSection(
                    plan: plan,
                    includeAuthor: $includeAuthor,
                    showingAuthorSettings: $showingAuthorSettings
                )

            }
            .navigationTitle("Export Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        checkAuthorInfoBeforeExport()
                    }
                    .disabled(isExporting)
                }
            }
            .task {
                await updateAllEstimatedSizes()
            }
            .sheet(isPresented: $showingAuthorSettings) {
                NavigationStack {
                    AuthorSettingsView()
                }
            }
        }
    }

    // MARK: - Views

    private func qualityOption(_ quality: ExportQuality) -> some View {
        Button {
            selectedQuality = quality
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quality.rawValue)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(quality.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Sharing method compatibility
                    if let sizeInfo = estimatedSizes[quality] {
                        HStack(spacing: 4) {
                            Text(sizeInfo.formatted)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)

                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(sharingMethodHint(for: sizeInfo.bytes))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                if selectedQuality == quality {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(selectedQuality == quality ? Color.blue.opacity(0.12) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sharingMethodsFooter: Text {
        let imageCount = plan.images.count

        if imageCount == 0 {
            return Text("This plan has no images, so the file will be very small and work with all sharing methods.")
        } else {
            return Text("AirDrop works for all file sizes. Email may have limits around 10-25 MB depending on your provider.")
        }
    }

    /// Get a hint about which sharing methods work well for this file size
    private func sharingMethodHint(for bytes: Int64) -> String {
        let mb = Double(bytes) / 1_000_000.0

        if mb < 10 {
            return "All methods"
        } else if mb < 25 {
            return "AirDrop, Messages, most email"
        } else if mb < 100 {
            return "AirDrop, Messages"
        } else {
            return "AirDrop only"
        }
    }

    // MARK: - Actions

    private func updateAllEstimatedSizes() async {
        var sizes: [ExportQuality: (bytes: Int64, formatted: String)] = [:]

        for quality in ExportQuality.allCases {
            let bytes = await exportService.estimateExportSize(plan, quality: quality)
            let formatted = await exportService.formattedEstimatedSize(plan, quality: quality)
            sizes[quality] = (bytes, formatted)
        }

        await MainActor.run {
            estimatedSizes = sizes
        }
    }

    /// Export with author information based on user's toggle selection
    private func checkAuthorInfoBeforeExport() {
        Task {
            // If plan already has an author (from import), preserve it
            // If user toggled includeAuthor and has author info, add it
            let shouldAddAuthor = plan.author == nil && includeAuthor && authorSettings.hasAuthorInfo
            await exportPlan(addAuthor: shouldAddAuthor)
        }
    }

    private func exportPlan(addAuthor: Bool) async {
        await MainActor.run {
            isExporting = true
        }

        do {
            // Create plan with author info if requested
            var planToExport = plan

            if addAuthor, let authorModel = await MainActor.run(body: { authorSettings.createAuthorModel() }) {
                // Add current user's author info
                planToExport = ProjectModel(
                    id: plan.id,
                    title: plan.title,
                    type: plan.type,
                    dateCreated: plan.dateCreated,
                    dateModified: plan.dateModified,
                    isArchived: plan.isArchived,
                    coe: plan.coe,
                    summary: plan.summary,
                    steps: plan.steps,
                    estimatedTime: plan.estimatedTime,
                    difficultyLevel: plan.difficultyLevel,
                    proposedPriceRange: plan.proposedPriceRange,
                    images: plan.images,
                    heroImageId: plan.heroImageId,
                    glassItems: plan.glassItems,
                    referenceUrls: plan.referenceUrls,
                    author: authorModel,
                    timesUsed: plan.timesUsed,
                    lastUsedDate: plan.lastUsedDate
                )
            }

            let fileURL = try await exportService.exportPlan(planToExport, quality: selectedQuality)

            await MainActor.run {
                isExporting = false

                // Call completion handler
                onExportComplete?(fileURL)

                // Dismiss the export view
                dismiss()
            }
        } catch {
            await MainActor.run {
                isExporting = false
                // TODO: Show error alert
                print("Export failed: \(error)")
            }
        }
    }
}

#Preview {
    ExportPlanView(plan: ProjectModel(
        title: "Bead Tutorial",
        type: .recipe,
        coe: "104",
        summary: "Create a simple round bead with beautiful colors"
    ))
}

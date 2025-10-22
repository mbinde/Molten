//
//  ImportPlanView.swift
//  Molten
//
//  View for importing a project plan from a .moltenplan file
//

import SwiftUI

struct ImportPlanView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var preview: ProjectPreview?
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var error: Error?
    @State private var importedPlan: ProjectModel?

    private let importService: ProjectImportService

    var onImportComplete: ((ProjectModel) -> Void)?

    init(fileURL: URL, onImportComplete: ((ProjectModel) -> Void)? = nil) {
        self.fileURL = fileURL
        self.onImportComplete = onImportComplete
        self.importService = ProjectImportService(
            userImageRepository: RepositoryFactory.createUserImageRepository(),
            projectPlanRepository: RepositoryFactory.createProjectRepository()
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Ensure we always have a background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                // Content
                Group {
                    if isLoading {
                        loadingView
                    } else if let error = error {
                        errorView(error)
                    } else if let preview = preview {
                        previewView(preview)
                    } else if importedPlan != nil {
                        successView
                    } else {
                        // Fallback view - should never reach here
                        Text("Unexpected state")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Import Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if preview != nil && error == nil && importedPlan == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            Task {
                                await importPlan()
                            }
                        }
                        .disabled(isImporting)
                    }
                }
            }
            .task {
                await loadPreview()
            }
            .onAppear {
                print("🎬 ImportPlanView: View appeared")
                print("🎬 ImportPlanView: File URL: \(fileURL.path)")
                print("🎬 ImportPlanView: isLoading: \(isLoading)")
            }
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
            Text("Reading plan file...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Import Failed")
                    .font(.headline)

                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Dismiss") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewView(_ preview: ProjectPreview) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(preview.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let summary = preview.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 16) {
                        Label("\(preview.stepCount)", systemImage: "list.number")
                        Label("\(preview.imageCount)", systemImage: "photo")
                        Label(preview.formattedFileSize, systemImage: "doc")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Details") {
                LabeledContent("Type", value: preview.type.displayName)
                LabeledContent("COE", value: preview.coe)

                if !preview.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(preview.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
            }

            Section("Contents") {
                if preview.stepCount > 0 {
                    HStack {
                        Text("Steps")
                        Spacer()
                        Text("\(preview.stepCount)")
                            .foregroundColor(.secondary)
                    }
                }

                if preview.imageCount > 0 {
                    HStack {
                        Text("Images")
                        Spacer()
                        Text("\(preview.imageCount)")
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("File Size")
                    Spacer()
                    Text(preview.formattedFileSize)
                        .foregroundColor(.secondary)
                }
            }

            if isImporting {
                Section {
                    HStack {
                        ProgressView()
                        Text("Importing plan and images...")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Import Successful")
                    .font(.headline)

                Text("The plan has been added to your library")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadPreview() async {
        print("📥 ImportPlanView: Starting preview load for \(fileURL.path)")
        do {
            let preview = try await importService.previewPlan(from: fileURL)
            print("✅ ImportPlanView: Preview loaded successfully - \(preview.title)")
            await MainActor.run {
                self.preview = preview
                self.isLoading = false
            }
        } catch {
            print("❌ ImportPlanView: Preview failed - \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func importPlan() async {
        await MainActor.run {
            isImporting = true
        }

        do {
            let plan = try await importService.importPlan(from: fileURL)

            await MainActor.run {
                self.importedPlan = plan
                self.isImporting = false

                // Notify callback
                onImportComplete?(plan)

                // Auto-dismiss after a moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isImporting = false
            }
        }
    }
}

#Preview {
    ImportPlanView(fileURL: URL(fileURLWithPath: "/tmp/test.moltenplan"))
}

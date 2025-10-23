//
//  AddLogbookEntryView.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

import SwiftUI
#if canImport(UIKit)
import PhotosUI
#endif

struct AddLogbookEntryView: View {
    @Environment(\.dismiss) private var dismiss

    // Repository dependencies
    private let logbookRepository: LogbookRepository?
    private let projectRepository: ProjectRepository
    private let userImageRepository: UserImageRepository

    // Form state
    @State private var title = ""
    @State private var selectedProjectIds: Set<UUID> = []
    @State private var projectSearchText = ""
    @State private var startDate: Date? = Date()
    @State private var completionDate: Date? = Date()
    @State private var notes = ""
    @State private var status: ProjectStatus = .completed
    @State private var tags: [String] = []
    @State private var coe: String = "96"  // Default to COE 96
    @State private var techniquesUsed: [String] = []
    @State private var hoursSpent = ""
    @State private var pricePoint = ""
    @State private var saleDate: Date?
    @State private var buyerInfo = ""

    // Image state
    @State private var images: [ProjectImageModel] = []
    @State private var loadedImages: [UUID: UIImage] = [:]
    @State private var heroImageId: UUID?

    #if canImport(UIKit)
    @State private var showingImagePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    #endif

    // UI state
    @State private var showingTagEditor = false
    @State private var showingProjectSearch = false
    @State private var availableProjects: [ProjectModel] = []
    @State private var isLoadingProjects = false
    @State private var isSaving = false

    init(
        logbookRepository: LogbookRepository? = nil,
        projectRepository: ProjectRepository? = nil,
        userImageRepository: UserImageRepository? = nil
    ) {
        self.logbookRepository = logbookRepository
        self.projectRepository = projectRepository ?? RepositoryFactory.createProjectRepository()
        self.userImageRepository = userImageRepository ?? RepositoryFactory.createUserImageRepository()
    }

    var body: some View {
        NavigationStack {
            Form {
                // Project association (optional - only show if projects available)
                if !availableProjects.isEmpty {
                    projectSection
                }

                // Basic info
                basicInfoSection

                // Images
                imagesSection

                // Details
                detailsSection

                // Business info (if sold or gifted)
                if status == .sold || status == .gifted {
                    businessSection
                }
            }
            .navigationTitle("New Logbook Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarContent
            }
            .task {
                await loadProjects()
            }
            .sheet(isPresented: $showingTagEditor) {
                TagEditorSheet(tags: $tags)
            }
            #if canImport(UIKit)
            .photosPicker(
                isPresented: $showingImagePicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images
            )
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    await loadSelectedImages(newItems)
                }
            }
            #endif
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var projectSection: some View {
        Section {
            // Show selected projects
            if !selectedProjectIds.isEmpty {
                ForEach(Array(selectedProjectIds), id: \.self) { projectId in
                    if let project = availableProjects.first(where: { $0.id == projectId }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.title)
                                    .font(.body)
                                if let summary = project.summary, !summary.isEmpty {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Button {
                                selectedProjectIds.remove(projectId)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Inline search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search projects to link...", text: $projectSearchText)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                if !projectSearchText.isEmpty {
                    Button {
                        projectSearchText = ""
                        showingProjectSearch = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .onChange(of: projectSearchText) { _, newValue in
                showingProjectSearch = !newValue.isEmpty
            }

            // Show filtered results when searching
            if showingProjectSearch && !projectSearchText.isEmpty {
                ForEach(filteredProjects.prefix(5)) { project in
                    Button {
                        if selectedProjectIds.contains(project.id) {
                            selectedProjectIds.remove(project.id)
                        } else {
                            selectedProjectIds.insert(project.id)
                        }
                        projectSearchText = ""
                        showingProjectSearch = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                if let summary = project.summary, !summary.isEmpty {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if selectedProjectIds.contains(project.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if filteredProjects.count > 5 {
                    Text("\(filteredProjects.count - 5) more...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Project Association")
        } footer: {
            Text("Search and select project plans you followed")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var basicInfoSection: some View {
        Section("Basic Information") {
            TextField("Title", text: $title)
                .font(.body)

            Picker("Status", selection: $status) {
                Text("In Progress").tag(ProjectStatus.inProgress)
                Text("Completed").tag(ProjectStatus.completed)
                Text("Sold").tag(ProjectStatus.sold)
                Text("Gifted").tag(ProjectStatus.gifted)
                Text("Kept").tag(ProjectStatus.kept)
                Text("Broken").tag(ProjectStatus.broken)
            }

            // Start Date (always shown)
            HStack {
                if let date = startDate {
                    DatePicker("Start Date", selection: Binding(
                        get: { date },
                        set: { startDate = $0 }
                    ), displayedComponents: .date)

                    Button {
                        startDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        startDate = Date()
                    } label: {
                        HStack {
                            Text("Start Date")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Not set")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Completion Date (only shown if status is not "in progress")
            if status != .inProgress {
                HStack {
                    if let date = completionDate {
                        DatePicker("Completion Date", selection: Binding(
                            get: { date },
                            set: { completionDate = $0 }
                        ), displayedComponents: .date)

                        Button {
                            completionDate = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            completionDate = Date()
                        } label: {
                            HStack {
                                Text("Completion Date")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Not set")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Sale/Gift Date (only shown if status is sold or gifted)
            if status == .sold || status == .gifted {
                HStack {
                    if let date = saleDate {
                        DatePicker(status == .sold ? "Sale Date" : "Gift Date", selection: Binding(
                            get: { date },
                            set: { saleDate = $0 }
                        ), displayedComponents: .date)

                        Button {
                            saleDate = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            saleDate = Date()
                        } label: {
                            HStack {
                                Text(status == .sold ? "Sale Date" : "Gift Date")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Not set")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Picker("Glass COE", selection: $coe) {
                Text("33").tag("33")
                Text("90").tag("90")
                Text("96").tag("96")
                Text("104").tag("104")
            }
        }
    }

    @ViewBuilder
    private var imagesSection: some View {
        #if canImport(UIKit)
        Section {
            PrimaryImageSelector(
                images: images,
                loadedImages: loadedImages,
                currentPrimaryImageId: heroImageId,
                onSelectPrimary: { newId in
                    heroImageId = newId
                },
                onAddImage: {
                    showingImagePicker = true
                }
            )
        } header: {
            Text("Images")
        } footer: {
            Text("Add images and select one as the primary image to display")
                .font(.caption)
        }
        #endif
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)

            // Tags
            Button {
                showingTagEditor = true
            } label: {
                HStack {
                    Text("Tags")
                    Spacer()
                    if tags.isEmpty {
                        Text("None")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(tags.count)")
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
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

            HStack {
                Text("Hours Spent")
                Spacer()
                TextField("0", text: $hoursSpent)
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
        }
    }

    @ViewBuilder
    private var businessSection: some View {
        Section(status == .sold ? "Sale Information" : "Gift Information") {
            HStack {
                Text("Sold for")
                Spacer()
                Text("$")
                TextField("0.00", text: $pricePoint)
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("Buyer Information (Optional)", text: $buyerInfo, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .disabled(isSaving)
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task {
                    await saveLogEntry()
                }
            }
            .disabled(title.isEmpty || isSaving)
        }
    }

    // MARK: - Helpers

    private var filteredProjects: [ProjectModel] {
        if projectSearchText.isEmpty {
            return availableProjects
        } else {
            return availableProjects.filter { project in
                project.title.localizedCaseInsensitiveContains(projectSearchText) ||
                (project.summary?.localizedCaseInsensitiveContains(projectSearchText) ?? false)
            }
        }
    }

    // MARK: - Data Loading

    private func loadProjects() async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }

        do {
            let projects = try await projectRepository.getActiveProjects()
            await MainActor.run {
                self.availableProjects = projects
            }
        } catch {
            print("Error loading projects: \(error)")
        }
    }

    #if canImport(UIKit)
    private func loadSelectedImages(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                continue
            }

            // Create image model
            let imageModel = ProjectImageModel(
                id: UUID(),
                projectId: UUID(), // Temporary, will be set when saving
                projectCategory: .log,
                fileExtension: "jpg",
                caption: nil
            )

            await MainActor.run {
                images.append(imageModel)
                loadedImages[imageModel.id] = image

                // Set as hero if it's the first image
                if heroImageId == nil {
                    heroImageId = imageModel.id
                }
            }
        }

        // Clear selection
        await MainActor.run {
            selectedPhotoItems = []
        }
    }
    #endif

    // MARK: - Save

    private func saveLogEntry() async {
        guard let repository = logbookRepository else {
            // Show placeholder alert
            await MainActor.run {
                dismiss()
            }
            return
        }

        isSaving = true
        defer { isSaving = false }

        // Parse hours
        let hours: Decimal? = {
            guard let value = Decimal(string: hoursSpent), value > 0 else { return nil }
            return value
        }()

        // Parse price
        let price: Decimal? = {
            guard !pricePoint.isEmpty, let value = Decimal(string: pricePoint), value > 0 else { return nil }
            return value
        }()

        // Create log entry
        let log = LogbookModel(
            title: title,
            startDate: startDate,
            completionDate: completionDate,
            basedOnProjectIds: Array(selectedProjectIds),
            tags: tags,
            coe: coe,
            notes: notes.isEmpty ? nil : notes,
            techniquesUsed: nil,  // Hidden from UI for now
            hoursSpent: hours,
            images: images,
            heroImageId: heroImageId,
            glassItems: [],
            pricePoint: price,
            saleDate: saleDate,
            buyerInfo: buyerInfo.isEmpty ? nil : buyerInfo,
            status: status
        )

        do {
            let createdLog = try await repository.createLog(log)

            #if canImport(UIKit)
            // Save images
            for imageModel in images {
                if let image = loadedImages[imageModel.id] {
                    let imageType: UserImageType = imageModel.id == heroImageId ? .primary : .alternate
                    try? await userImageRepository.saveImage(
                        image,
                        ownerType: .projectPlan,
                        ownerId: createdLog.id.uuidString,
                        type: imageType
                    )
                }
            }
            #endif

            await MainActor.run {
                dismiss()
            }
        } catch {
            print("Error saving log entry: \(error)")
            // TODO: Show error alert
        }
    }
}

// MARK: - Technique Editor Sheet

struct TechniqueEditorSheet: View {
    @Binding var techniques: [String]
    @State private var newTechnique: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Technique") {
                    HStack {
                        TextField("Enter technique name", text: $newTechnique)
                            #if os(iOS)
                            .textInputAutocapitalization(.words)
                            #endif

                        Button("Add") {
                            let trimmed = newTechnique.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !techniques.contains(trimmed) {
                                techniques.append(trimmed)
                                newTechnique = ""
                            }
                        }
                        .disabled(newTechnique.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if !techniques.isEmpty {
                    Section("Current Techniques") {
                        ForEach(techniques, id: \.self) { technique in
                            HStack {
                                Text(technique)
                                Spacer()
                                Button(action: {
                                    techniques.removeAll { $0 == technique }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Techniques")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddLogbookEntryView()
}

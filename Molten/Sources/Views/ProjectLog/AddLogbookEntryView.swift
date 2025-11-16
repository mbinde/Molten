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
    @Environment(EntitlementService.self) private var entitlementService

    // ViewModel
    private let viewModel: AddLogbookEntryViewModel

    // Repository dependencies (for image handling)
    private let logbookRepository: LogbookRepository?
    private let userImageRepository: UserImageRepository
    private let kilnScheduleService: KilnScheduleService

    // Image state (kept in view since it's UIKit-specific)
    @State private var loadedImages: [UUID: UIImage] = [:]

    #if canImport(PhotosUI)
    @State private var showingImagePicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    #endif

    // UI state (kept in view since it's presentation-only)
    @State private var showingTagEditor = false
    @State private var showingProjectSearch = false

    // Subscription state
    @State private var showingUpgradePrompt = false
    @State private var logbookEntryCount = 0
    @State private var logbookEntryLimit = 0

    init(
        viewModel: AddLogbookEntryViewModel,
        logbookRepository: LogbookRepository? = nil,
        deps: AppDependencies = AppDependencies()
    ) {
        self.viewModel = viewModel
        self.logbookRepository = logbookRepository
        self.userImageRepository = deps.userImageRepository
        self.kilnScheduleService = deps.kilnScheduleService
    }

    // Convenience init for production use
    init(
        logbookRepository: LogbookRepository? = nil,
        deps: AppDependencies = AppDependencies()
    ) {
        self.viewModel = AddLogbookEntryViewModel(
            logbookRepository: logbookRepository ?? deps.logbookRepository,
            projectRepository: deps.projectRepository,
            kilnScheduleService: deps.kilnScheduleService
        )
        self.logbookRepository = logbookRepository
        self.userImageRepository = deps.userImageRepository
        self.kilnScheduleService = deps.kilnScheduleService
    }

    var body: some View {
        NavigationStack {
            Form {
                // Project association (optional - only show if projects available)
                if !viewModel.availableProjects.isEmpty {
                    projectSection
                }

                // Basic info
                basicInfoSection

                // Images
                imagesSection

                // Details
                detailsSection

                // Kiln Schedule
                kilnScheduleSection

                // Business info (if sold or gifted)
                if viewModel.showBusinessSection {
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
                await viewModel.loadProjects()
            }
            .sheet(isPresented: $showingTagEditor) {
                TagEditorSheet(tags: Binding(
                    get: { viewModel.tags },
                    set: { viewModel.tags = $0 }
                ))
            }
            .sheet(isPresented: $showingUpgradePrompt) {
                UpgradePromptView(
                    feature: "logbook",
                    currentCount: logbookEntryCount,
                    limit: logbookEntryLimit
                )
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
            if !viewModel.selectedProjectIds.isEmpty {
                ForEach(Array(viewModel.selectedProjectIds), id: \.self) { projectId in
                    if let project = viewModel.availableProjects.first(where: { $0.id == projectId }) {
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
                                viewModel.toggleProjectSelection(projectId)
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
                TextField("Search projects to link...", text: Binding(
                    get: { viewModel.projectSearchText },
                    set: { viewModel.projectSearchText = $0 }
                ))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                if !viewModel.projectSearchText.isEmpty {
                    Button {
                        viewModel.projectSearchText = ""
                        showingProjectSearch = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .onChange(of: viewModel.projectSearchText) { _, newValue in
                showingProjectSearch = !newValue.isEmpty
            }

            // Show filtered results when searching
            if showingProjectSearch && !viewModel.projectSearchText.isEmpty {
                ForEach(viewModel.filteredProjects.prefix(5)) { project in
                    Button {
                        viewModel.toggleProjectSelection(project.id)
                        viewModel.projectSearchText = ""
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

                            if viewModel.selectedProjectIds.contains(project.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.filteredProjects.count > 5 {
                    Text("\(viewModel.filteredProjects.count - 5) more...")
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
            TextField("Title", text: Binding(
                get: { viewModel.title },
                set: { viewModel.title = $0 }
            ))
                .font(.body)
                .accessibilityIdentifier("logbook.add.titleField")

            Picker("Status", selection: Binding(
                get: { viewModel.status },
                set: { viewModel.status = $0 }
            )) {
                Text("In Progress").tag(ProjectStatus.inProgress)
                Text("Completed").tag(ProjectStatus.completed)
                Text("Sold").tag(ProjectStatus.sold)
                Text("Gifted").tag(ProjectStatus.gifted)
                Text("Kept").tag(ProjectStatus.kept)
                Text("Broken").tag(ProjectStatus.broken)
            }
            .accessibilityIdentifier("logbook.add.statusPicker")

            // Start Date (always shown)
            HStack {
                if let date = viewModel.startDate {
                    DatePicker("Start Date", selection: Binding(
                        get: { date },
                        set: { viewModel.startDate = $0 }
                    ), displayedComponents: .date)

                    Button {
                        viewModel.clearStartDate()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        viewModel.setStartDateToNow()
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
            if viewModel.status != .inProgress {
                HStack {
                    if let date = viewModel.completionDate {
                        DatePicker("Completion Date", selection: Binding(
                            get: { date },
                            set: { viewModel.completionDate = $0 }
                        ), displayedComponents: .date)

                        Button {
                            viewModel.clearCompletionDate()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            viewModel.setCompletionDateToNow()
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
            if viewModel.status == .sold || viewModel.status == .gifted {
                HStack {
                    if let date = viewModel.saleDate {
                        DatePicker(viewModel.status == .sold ? "Sale Date" : "Gift Date", selection: Binding(
                            get: { date },
                            set: { viewModel.saleDate = $0 }
                        ), displayedComponents: .date)

                        Button {
                            viewModel.clearSaleDate()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            viewModel.setSaleDateToNow()
                        } label: {
                            HStack {
                                Text(viewModel.status == .sold ? "Sale Date" : "Gift Date")
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

            Picker("Glass COE", selection: Binding(
                get: { viewModel.coe },
                set: { viewModel.coe = $0 }
            )) {
                Text("33").tag("33")
                Text("90").tag("90")
                Text("96").tag("96")
                Text("104").tag("104")
            }
            .accessibilityIdentifier("logbook.add.coePicker")
        }
    }

    @ViewBuilder
    private var imagesSection: some View {
        #if canImport(PhotosUI)
        Section {
            PrimaryImageSelector(
                images: viewModel.images,
                loadedImages: loadedImages,
                currentPrimaryImageId: viewModel.heroImageId,
                onSelectPrimary: { newId in
                    viewModel.heroImageId = newId
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
            TextField("Notes", text: Binding(
                get: { viewModel.notes },
                set: { viewModel.notes = $0 }
            ), axis: .vertical)
                .lineLimit(3...6)
                .accessibilityIdentifier("logbook.add.notesField")

            // Tags
            Button {
                showingTagEditor = true
            } label: {
                HStack {
                    Text("Tags")
                    Spacer()
                    if viewModel.tags.isEmpty {
                        Text("None")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(viewModel.tags.count)")
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !viewModel.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(6)
                        }
                    }
                }
            }

            HStack {
                Text("Hours Spent")
                Spacer()
                TextField("0", text: Binding(
                    get: { viewModel.hoursSpent },
                    set: { viewModel.hoursSpent = $0 }
                ))
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
        }
    }

    @ViewBuilder
    private var kilnScheduleSection: some View {
        Section("Kiln Schedule") {
            KilnSchedulePickerView(
                selectedScheduleId: Binding(
                    get: { viewModel.kilnScheduleId },
                    set: { viewModel.kilnScheduleId = $0 }
                ),
                kilnScheduleService: kilnScheduleService
            )
        }
    }

    @ViewBuilder
    private var businessSection: some View {
        Section(viewModel.status == .sold ? "Sale Information" : "Gift Information") {
            HStack {
                Text("Sold for")
                Spacer()
                Text("$")
                TextField("0.00", text: Binding(
                    get: { viewModel.pricePoint },
                    set: { viewModel.pricePoint = $0 }
                ))
                    #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            TextField("Buyer Information (Optional)", text: Binding(
                get: { viewModel.buyerInfo },
                set: { viewModel.buyerInfo = $0 }
            ), axis: .vertical)
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
            .disabled(viewModel.isSaving)
            .accessibilityIdentifier("logbook.add.cancelButton")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                Task {
                    await saveLogEntry()
                }
            }
            .disabled(!viewModel.isValid || viewModel.isSaving)
            .accessibilityIdentifier("logbook.add.saveButton")
        }
    }

    // MARK: - Helpers
    // (filteredProjects and loadProjects now handled by ViewModel)

    #if canImport(PhotosUI)
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
                viewModel.images.append(imageModel)
                loadedImages[imageModel.id] = image

                // Set as hero if it's the first image
                if viewModel.heroImageId == nil {
                    viewModel.heroImageId = imageModel.id
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

        // Check subscription entitlement before creating logbook entry
        do {
            let allLogs = try await repository.getAllLogs()
            let currentLogCount = allLogs.count
            let canAdd = entitlementService.canAddLogbookEntry(currentCount: currentLogCount)

            if !canAdd {
                // Hit the limit - show upgrade prompt
                let limit = entitlementService.getLogbookEntriesLimit() ?? 0
                await MainActor.run {
                    logbookEntryCount = currentLogCount
                    logbookEntryLimit = limit
                    showingUpgradePrompt = true
                }
                return
            }
        } catch {
            // If we can't check the limit, allow the save to proceed
            print("⚠️ Failed to check logbook entry limit: \(error)")
        }

        // Use ViewModel's save method
        let success = await viewModel.save()

        if success {
            // Save images after successful log creation
            #if canImport(PhotosUI)
            // Note: We would need the created log's ID to save images
            // For now, keeping the images save in the view since it requires the logbookRepository
            if let repository = logbookRepository {
                // Get the last created log (this is a limitation - ideally save should return the ID)
                do {
                    let allLogs = try await repository.getAllLogs()
                    if let createdLog = allLogs.first(where: { $0.title == viewModel.title }) {
                        // Save images
                        for imageModel in viewModel.images {
                            if let image = loadedImages[imageModel.id] {
                                let imageType: UserImageType = imageModel.id == viewModel.heroImageId ? .primary : .alternate
                                try? await userImageRepository.saveImage(
                                    image,
                                    ownerType: .projectPlan,
                                    ownerId: createdLog.id.uuidString,
                                    type: imageType
                                )
                            }
                        }
                    }
                } catch {
                    print("Error saving images: \(error)")
                }
            }
            #endif

            await MainActor.run {
                dismiss()
            }
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

//
//  ShareViewController.swift
//  MoltenShareExtension
//
//  Share Extension for importing photos directly into Molten projects
//

import UIKit
import SwiftUI
import CoreData
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private var photosToImport: [UIImage] = []
    private var hostingController: UIHostingController<ShareExtensionView>?

    // Core Data container for extension
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Molten")

        // Use App Group container for shared storage
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.melissabinde.molten") {
            let storeURL = appGroupURL.appendingPathComponent("Molten.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                print("❌ ShareExtension: Failed to load Core Data: \(error)")
            } else {
                print("✅ ShareExtension: Core Data loaded from \(description.url?.path ?? "unknown")")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Extract photos from share context
        extractSharedPhotos()
    }

    private func extractSharedPhotos() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completeRequest(withError: ShareExtensionError.noPhotosFound)
            return
        }

        let imageType = UTType.image.identifier
        let validAttachments = attachments.filter { $0.hasItemConformingToTypeIdentifier(imageType) }

        guard !validAttachments.isEmpty else {
            completeRequest(withError: ShareExtensionError.noPhotosFound)
            return
        }

        // Load all images
        let group = DispatchGroup()
        var loadedImages: [UIImage] = []

        for attachment in validAttachments {
            group.enter()
            attachment.loadItem(forTypeIdentifier: imageType, options: nil) { (data, error) in
                defer { group.leave() }

                if let error = error {
                    print("❌ ShareExtension: Error loading attachment: \(error)")
                    return
                }

                // Handle different data types
                var image: UIImage?

                if let imageData = data as? Data {
                    image = UIImage(data: imageData)
                } else if let url = data as? URL {
                    if let imageData = try? Data(contentsOf: url) {
                        image = UIImage(data: imageData)
                    }
                }

                if let image = image {
                    loadedImages.append(image)
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            if loadedImages.isEmpty {
                self.completeRequest(withError: ShareExtensionError.failedToLoadPhotos)
                return
            }

            self.photosToImport = loadedImages
            self.showShareUI()
        }
    }

    private func showShareUI() {
        let shareView = ShareExtensionView(
            photos: photosToImport,
            persistentContainer: persistentContainer,
            onSave: { [weak self] title, notes, projectType, techniqueType, tags, existingProjectId in
                self?.saveProject(title: title, notes: notes, projectType: projectType, techniqueType: techniqueType, tags: tags, existingProjectId: existingProjectId)
            },
            onCancel: { [weak self] in
                self?.completeRequest(withError: nil)
            }
        )

        let hosting = UIHostingController(rootView: shareView)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)

        self.hostingController = hosting
    }

    private func saveProject(title: String, notes: String, projectType: String, techniqueType: String?, tags: [String], existingProjectId: UUID?) {
        // Create Project in Core Data with images
        let context = persistentContainer.viewContext

        context.perform {
            do {
                // Get or create Project entity
                let project: Project
                if let existingId = existingProjectId {
                    // Add to existing project
                    let fetchRequest = Project.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", existingId as CVarArg)

                    if let existingProject = try context.fetch(fetchRequest).first {
                        project = existingProject
                        project.date_modified = Date()
                    } else {
                        // Fallback to creating new if existing not found
                        project = Project(context: context)
                        project.id = UUID()
                        project.title = title
                        project.summary = notes.isEmpty ? nil : notes
                        project.date_created = Date()
                        project.date_modified = Date()
                        project.setValue(projectType, forKey: "project_type")
                        project.is_archived = false
                    }
                } else {
                    // Create new project
                    project = Project(context: context)
                    project.id = UUID()
                    project.title = title
                    project.summary = notes.isEmpty ? nil : notes
                    project.date_created = Date()
                    project.date_modified = Date()
                    project.setValue(projectType, forKey: "project_type")
                    project.setValue(techniqueType, forKey: "technique_type")
                    project.is_archived = false
                }

                // Create tags if provided
                if !tags.isEmpty {
                    for tagName in tags {
                        let projectTag = ProjectTag(context: context)
                        projectTag.setValue(UUID(), forKey: "id")
                        projectTag.setValue(tagName, forKey: "tag")
                        projectTag.setValue(project, forKey: "project")
                    }
                }

                // Create UserImage entities and ProjectImage metadata for each photo
                for (index, photo) in self.photosToImport.enumerated() {
                    guard let jpegData = photo.jpegData(compressionQuality: 0.85) else {
                        print("⚠️ ShareExtension: Failed to convert photo \(index) to JPEG")
                        continue
                    }

                    // Create UserImage (stores the actual image data)
                    let imageId = UUID()
                    let userImage = UserImage(context: context)
                    userImage.id = imageId
                    userImage.imageData = jpegData
                    userImage.dateCreated = Date()
                    userImage.dateModified = Date()
                    userImage.imageType = "primary"
                    userImage.ownerType = "projectPlan"
                    userImage.ownerId = project.id?.uuidString
                    userImage.fileExtension = "jpg"

                    // Create ProjectImage (metadata linking image to project)
                    let projectImage = ProjectImage(context: context)
                    projectImage.setValue(imageId, forKey: "id")
                    projectImage.setValue(Date(), forKey: "date_added")
                    projectImage.setValue("jpg", forKey: "file_extension")
                    projectImage.setValue(Int32(index), forKey: "order_index")
                    projectImage.setValue(project, forKey: "plan")

                    // Set first image as hero image
                    if index == 0 {
                        project.setValue(imageId, forKey: "hero_image_id")
                    }
                }

                // Save to Core Data
                try context.save()

                print("✅ ShareExtension: Created project '\(title)' with \(self.photosToImport.count) photo(s)")

                DispatchQueue.main.async {
                    self.completeRequest(withError: nil)
                }
            } catch {
                print("❌ ShareExtension: Failed to save to Core Data: \(error)")
                DispatchQueue.main.async {
                    self.completeRequest(withError: ShareExtensionError.failedToSave(error))
                }
            }
        }
    }

    private func completeRequest(withError error: Error?) {
        if let error = error {
            extensionContext?.cancelRequest(withError: error)
        } else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}

// MARK: - SwiftUI View

struct ShareExtensionView: View {
    let photos: [UIImage]
    let persistentContainer: NSPersistentContainer
    let onSave: (String, String, String, String?, [String], UUID?) -> Void
    let onCancel: () -> Void

    @AppStorage("lastProjectType", store: UserDefaults(suiteName: "group.com.melissabinde.molten"))
    private var lastProjectType: String = "idea"

    @State private var projectTitle = ""
    @State private var projectNotes = ""
    @State private var selectedProjectType: String
    @State private var selectedTechniqueType: String? = nil
    @State private var tags: [String] = []
    @State private var showingTagEditor = false
    @State private var saveMode: SaveMode = .newProject
    @State private var existingProjects: [ExistingProject] = []
    @State private var selectedExistingProject: ExistingProject?
    @FocusState private var titleFocused: Bool

    enum SaveMode: String, CaseIterable {
        case newProject = "New Project"
        case addToExisting = "Add to Existing"
    }

    struct ExistingProject: Identifiable, Hashable {
        let id: UUID
        let title: String
        let projectType: String
    }

    // Available project types
    private let projectTypes: [(value: String, displayName: String)] = [
        ("idea", "Idea"),
        ("recipe", "Instructions"),
        ("technique", "Technique"),
        ("tutorial", "Tutorial"),
        ("commission", "Commission")
    ]

    // Available technique types
    private let techniqueTypes: [(value: String, displayName: String)] = [
        ("glass_blowing", "Glass Blowing"),
        ("flameworking", "Flameworking"),
        ("fusing", "Fusing"),
        ("casting", "Casting"),
        ("other", "Other")
    ]

    init(photos: [UIImage], persistentContainer: NSPersistentContainer, onSave: @escaping (String, String, String, String?, [String], UUID?) -> Void, onCancel: @escaping () -> Void) {
        self.photos = photos
        self.persistentContainer = persistentContainer
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize selectedProjectType from UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.melissabinde.molten")
        let saved = defaults?.string(forKey: "lastProjectType") ?? "idea"
        _selectedProjectType = State(initialValue: saved)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Photo preview
                if photos.count == 1 {
                    Image(uiImage: photos[0])
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<photos.count, id: \.self) { index in
                                Image(uiImage: photos[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                                    .clipped()
                            }
                        }
                        .padding(.horizontal)
                    }

                    Text("\(photos.count) photos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Mode selector: New Project vs Add to Existing
                Picker("Save Mode", selection: $saveMode) {
                    ForEach(SaveMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // New Project fields
                if saveMode == .newProject {
                    // Project Type Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Project Type", selection: $selectedProjectType) {
                            ForEach(projectTypes, id: \.value) { type in
                                Text(type.displayName).tag(type.value)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal)

                    // Title field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Project name", text: $projectTitle)
                            .textFieldStyle(.roundedBorder)
                            .focused($titleFocused)
                    }
                    .padding(.horizontal)

                    // Notes field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextEditor(text: $projectNotes)
                            .frame(height: 100)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)

                    // Technique Type Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Technique Type (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Technique Type", selection: $selectedTechniqueType) {
                            Text("Not set").tag(nil as String?)
                            ForEach(techniqueTypes, id: \.value) { type in
                                Text(type.displayName).tag(type.value as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal)

                    // Tags field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack {
                            if tags.isEmpty {
                                Text("None")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(tags.count) tag\(tags.count == 1 ? "" : "s")")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                showingTagEditor = true
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

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
                    }
                    .padding(.horizontal)
                }

                // Add to Existing Project fields
                if saveMode == .addToExisting {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select Project")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if existingProjects.isEmpty {
                            Text("No existing projects found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            Picker("Project", selection: $selectedExistingProject) {
                                Text("Choose a project...").tag(nil as ExistingProject?)
                                ForEach(existingProjects) { project in
                                    Text(project.title).tag(project as ExistingProject?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
            .navigationTitle("Save to Molten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if saveMode == .newProject {
                            // Save selected type to UserDefaults for next time
                            lastProjectType = selectedProjectType

                            onSave(
                                projectTitle.isEmpty ? "Imported \(projectTypes.first(where: { $0.value == selectedProjectType })?.displayName ?? "Project") \(Date().formatted(date: .abbreviated, time: .shortened))" : projectTitle,
                                projectNotes,
                                selectedProjectType,
                                selectedTechniqueType,
                                tags,
                                nil
                            )
                        } else {
                            // Add to existing project
                            if let existingProject = selectedExistingProject {
                                onSave("", "", "", nil, [], existingProject.id)
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(saveMode == .addToExisting && selectedExistingProject == nil)
                }
            }
            .onAppear {
                // Load existing projects
                loadExistingProjects()

                // Auto-focus title field for new projects
                if saveMode == .newProject {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        titleFocused = true
                    }
                }
            }
            .sheet(isPresented: $showingTagEditor) {
                ShareTagEditorSheet(tags: $tags)
            }
        }
    }

    private func loadExistingProjects() {
        let context = persistentContainer.viewContext
        let fetchRequest = Project.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "is_archived == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_modified", ascending: false)]

        do {
            let projects = try context.fetch(fetchRequest)
            existingProjects = projects.compactMap { project in
                guard let id = project.id,
                      let title = project.title,
                      let projectType = project.value(forKey: "project_type") as? String else {
                    return nil
                }
                return ExistingProject(id: id, title: title, projectType: projectType)
            }
        } catch {
            print("❌ ShareExtension: Failed to load existing projects: \(error)")
        }
    }
}

// MARK: - Tag Editor Sheet

struct ShareTagEditorSheet: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Add Tag") {
                    HStack {
                        TextField("Enter tag name", text: $newTag)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif

                        Button("Add") {
                            let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            if !trimmed.isEmpty && !tags.contains(trimmed) {
                                tags.append(trimmed)
                                newTag = ""
                            }
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if !tags.isEmpty {
                    Section("Current Tags") {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button(action: {
                                    tags.removeAll { $0 == tag }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Tags")
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

// MARK: - Errors

enum ShareExtensionError: LocalizedError {
    case noPhotosFound
    case failedToLoadPhotos
    case failedToSave(Error)

    var errorDescription: String? {
        switch self {
        case .noPhotosFound:
            return "No photos found in share"
        case .failedToLoadPhotos:
            return "Failed to load photos"
        case .failedToSave(let error):
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}

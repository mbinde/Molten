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
            onSave: { [weak self] title, notes in
                self?.saveProject(title: title, notes: notes)
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

    private func saveProject(title: String, notes: String) {
        // Create Project in Core Data with images
        let context = persistentContainer.viewContext

        context.perform {
            do {
                // Create Project entity
                let project = Project(context: context)
                project.id = UUID()
                project.title = title
                project.summary = notes.isEmpty ? nil : notes
                project.date_created = Date()
                project.date_modified = Date()
                project.setValue("idea", forKey: "project_type")  // Mark as imported idea
                project.is_archived = false

                // Create UserImage entities for each photo
                for (index, photo) in self.photosToImport.enumerated() {
                    guard let jpegData = photo.jpegData(compressionQuality: 0.85) else {
                        print("⚠️ ShareExtension: Failed to convert photo \(index) to JPEG")
                        continue
                    }

                    let userImage = UserImage(context: context)
                    userImage.id = UUID()
                    userImage.imageData = jpegData
                    userImage.dateCreated = Date()
                    userImage.dateModified = Date()
                    userImage.imageType = "primary"
                    userImage.ownerType = "project"
                    userImage.ownerId = project.id?.uuidString
                    userImage.fileExtension = "jpg"
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
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var projectTitle = ""
    @State private var projectNotes = ""
    @FocusState private var titleFocused: Bool

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

                // Title field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("Project idea name", text: $projectTitle)
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
                        onSave(
                            projectTitle.isEmpty ? "Imported Idea \(Date().formatted(date: .abbreviated, time: .shortened))" : projectTitle,
                            projectNotes
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Auto-focus title field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    titleFocused = true
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

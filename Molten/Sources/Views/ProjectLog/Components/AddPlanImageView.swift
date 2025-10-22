//
//  AddPlanImageView.swift
//  Molten
//
//  View for adding images to a project plan
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
struct AddPlanImageView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectPlanModel
    let repository: ProjectPlanRepository
    private let userImageRepository: UserImageRepository
    private let projectImageRepository: ProjectImageRepository

    @State private var selectedImage: UIImage?
    @State private var caption: String = ""
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingError = false
    @State private var errorMessage = ""

    init(plan: ProjectPlanModel, repository: ProjectPlanRepository) {
        self.plan = plan
        self.repository = repository
        self.userImageRepository = RepositoryFactory.createUserImageRepository()
        self.projectImageRepository = RepositoryFactory.createProjectImageRepository()
    }

    var body: some View {
        Form {
            Section {
                if let image = selectedImage {
                    VStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(8)

                        Button("Choose Different Image") {
                            showingPhotoPicker = true
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Choose from Photos", systemImage: "photo")
                    }

                    #if !targetEnvironment(macCatalyst)
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    #endif
                }
            }

            if selectedImage != nil {
                Section("Caption (optional)") {
                    TextField("Add a caption for this image", text: $caption, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
        }
        .navigationTitle("Add Image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            if selectedImage != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveImage()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        #if !targetEnvironment(macCatalyst)
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        #endif
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func saveImage() async {
        guard let image = selectedImage else { return }

        do {
            // 1. Save image to UserImageRepository
            let userImageModel = try await userImageRepository.saveImage(
                image,
                ownerType: .projectPlan,
                ownerId: plan.id.uuidString,
                type: .primary
            )

            // 2. Create ProjectImageModel that references the saved image
            let newProjectImage = ProjectImageModel(
                id: userImageModel.id,  // Use same ID as UserImageModel
                projectId: plan.id,
                projectType: .plan,
                fileExtension: userImageModel.fileExtension,
                caption: caption.isEmpty ? nil : caption,
                order: plan.images.count
            )

            // 3. Save metadata to ProjectImageRepository
            _ = try await projectImageRepository.createImageMetadata(newProjectImage)

            // 4. Update plan with new image reference
            var updatedImages = plan.images
            updatedImages.append(newProjectImage)

            // Set as hero image if it's the first image
            let heroImageId = plan.heroImageId ?? newProjectImage.id

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
                images: updatedImages,
                heroImageId: heroImageId,
                glassItems: plan.glassItems,
                referenceUrls: plan.referenceUrls,
                author: plan.author,
                timesUsed: plan.timesUsed,
                lastUsedDate: plan.lastUsedDate
            )

            try await repository.updatePlan(updatedPlan)

            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save image: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}
#endif

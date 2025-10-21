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

    @State private var selectedImage: UIImage?
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingError = false
    @State private var errorMessage = ""

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

        // TODO: Save image to UserImageRepository or similar storage
        // For now, create a ProjectImageModel and add it to the plan's images array

        // Create new image model
        let newImage = ProjectImageModel(
            projectId: plan.id,
            projectType: .plan,
            fileExtension: "jpg",
            caption: nil,
            order: plan.images.count
        )

        // Create updated plan with new image
        var updatedImages = plan.images
        updatedImages.append(newImage)

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
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updatePlan(updatedPlan)
            await MainActor.run {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to save image: \(error.localizedDescription)"
            showingError = true
        }
    }
}
#endif

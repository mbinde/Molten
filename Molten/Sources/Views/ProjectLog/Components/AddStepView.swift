//
//  AddStepView.swift
//  Molten
//
//  View for adding steps to a project plan
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AddStepView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: ProjectPlanModel
    let repository: ProjectPlanRepository

    @State private var stepTitle = ""
    @State private var stepDescription = ""
    @State private var estimatedMinutes = ""
    @State private var stepImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false

    var body: some View {
        Form {
            Section("Step Details") {
                TextField("Title", text: $stepTitle)
                TextField("Description (optional)", text: $stepDescription, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Time Estimate") {
                HStack {
                    Text("Minutes")
                    Spacer()
                    TextField("0", text: $estimatedMinutes)
                        #if canImport(UIKit)
                        .keyboardType(.numberPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            // Images Section
            Section("Images (Optional)") {
                if stepImages.isEmpty {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Add Photos", systemImage: "photo")
                    }

                    #if canImport(UIKit) && !targetEnvironment(macCatalyst)
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    #endif
                } else {
                    // Show thumbnails of selected images
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(stepImages.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipped()
                                        .cornerRadius(8)

                                    // Remove button
                                    Button {
                                        stepImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                    }
                                    .offset(x: 5, y: -5)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Add More Photos", systemImage: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle("Add Step")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task { await saveStep() }
                }
                .disabled(stepTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: Binding(
                get: { nil },
                set: { newImage in
                    if let newImage = newImage {
                        stepImages.append(newImage)
                    }
                }
            ), sourceType: .photoLibrary)
        }
        #if !targetEnvironment(macCatalyst)
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: Binding(
                get: { nil },
                set: { newImage in
                    if let newImage = newImage {
                        stepImages.append(newImage)
                    }
                }
            ), sourceType: .camera)
        }
        #endif
        #endif
    }

    private func saveStep() async {
        // Create new step with next order number
        let newStep = ProjectStepModel(
            planId: plan.id,
            order: plan.steps.count,
            title: stepTitle,
            description: stepDescription.isEmpty ? nil : stepDescription,
            estimatedMinutes: Int(estimatedMinutes)
        )

        // TODO: Save step images to UserImageRepository
        // For now, we'll just save the step without images
        // This will need to be implemented similar to how AddPlanImageView works

        // Append to existing steps
        var updatedSteps = plan.steps
        updatedSteps.append(newStep)

        // Create updated plan
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
            steps: updatedSteps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updatePlan(updatedPlan)
            await MainActor.run { dismiss() }
        } catch {
            print("Error saving step: \(error)")
            // TODO: Show error alert
        }
    }
}

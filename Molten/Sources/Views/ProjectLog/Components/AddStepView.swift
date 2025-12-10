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

    let plan: ProjectModel
    let repository: ProjectRepository

    @State private var stepTitle = ""
    @State private var stepDescription = ""
    #if canImport(UIKit)
    @State private var stepImages: [UIImage] = []
    #endif
    @State private var glassItems: [ProjectGlassItem] = []
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingAddGlass = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    /// Check if step has any content
    private var hasAnyContent: Bool {
        // Title or description has content
        if !stepTitle.trimmingCharacters(in: .whitespaces).isEmpty ||
           !stepDescription.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        }

        // Has glass items
        if !glassItems.isEmpty {
            return true
        }

        #if canImport(UIKit)
        // Has images
        if !stepImages.isEmpty {
            return true
        }
        #endif

        return false
    }

    var body: some View {
        Form {
            Section("Step Details (Optional)") {
                TextField("Title (optional)", text: $stepTitle)
                TextField("Description (optional)", text: $stepDescription, axis: .vertical)
                    .lineLimit(3...6)
            }

            // Glass Items Section
            Section("Glass Needed for This Step") {
                if glassItems.isEmpty {
                    Button(action: {
                        showingAddGlass = true
                    }) {
                        Label("Add Glass", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("add_step_add_glass")
                } else {
                    ForEach(glassItems) { glass in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(glass.displayName)
                                    .font(.body)
                                if let notes = glass.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                            Spacer()
                            if glass.quantity > 0 {
                                Text(verbatim: "\(glass.quantity) \(glass.unit)")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        glassItems.remove(atOffsets: indexSet)
                    }

                    Button(action: {
                        showingAddGlass = true
                    }) {
                        Label("Add More Glass", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("add_step_add_more_glass")
                }
            }

            #if canImport(UIKit)
            // Images Section
            Section("Images (Optional)") {
                if stepImages.isEmpty {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Add Photos", systemImage: "photo")
                    }
                    .accessibilityIdentifier("add_step_add_photos")

                    #if !targetEnvironment(macCatalyst)
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    .accessibilityIdentifier("add_step_take_photo")
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
            #endif
        }
        .navigationTitle("Add Step")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("add_step_cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task { await saveStep() }
                }
                .disabled(!hasAnyContent)
                .accessibilityIdentifier("add_step_add")
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
        .sheet(isPresented: $showingAddGlass) {
            NavigationStack {
                AddGlassToStepView(plan: plan) { newGlass in
                    glassItems.append(newGlass)
                }
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func saveStep() async {
        // Create new step with next order number
        let newStep = ProjectStepModel(
            projectId: plan.id,
            order: plan.steps.count,
            title: stepTitle,
            description: stepDescription.isEmpty ? nil : stepDescription,
            estimatedMinutes: nil,
            glassItemsNeeded: glassItems.isEmpty ? nil : glassItems
        )

        // TODO: Save step images to UserImageRepository
        // For now, we'll just save the step without images
        // This will need to be implemented similar to how AddPlanImageView works

        // Append to existing steps
        var updatedSteps = plan.steps
        updatedSteps.append(newStep)

        // Create updated plan
        let updatedPlan = ProjectModel(
            id: plan.id,
            title: plan.title,
            type: plan.type,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
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
            author: plan.author,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )

        do {
            try await repository.updateProject(updatedPlan)
            await MainActor.run { dismiss() }
        } catch {
            print("Error saving step: \(error)")
            await MainActor.run {
                errorMessage = "Failed to save step: \(error.localizedDescription)"
                showingErrorAlert = true
            }
        }
    }
}

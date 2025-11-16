//
//  ImageSubmissionSheet.swift
//  Molten
//
//  Sheet for submitting manufacturer images to Molten for consideration
//

import SwiftUI

#if canImport(UIKit)
struct ImageSubmissionSheet: View {
    let image: UIImage
    let glassItem: GlassItemModel

    @Environment(\.dismiss) private var dismiss
    @State private var hasPermission = false
    @State private var offersFreeOfCharge = false
    @State private var email = ""
    @State private var isSubmitting = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?

    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private var canSubmit: Bool {
        hasPermission && offersFreeOfCharge && isValidEmail && !email.isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Submit Image to Molten")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.bold)

                        Text("Help improve the catalog by sharing this manufacturer image with other users")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("Note: Custom images you upload are private and visible only to you. This submission shares the manufacturer's default image.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.small)
                    }

                    // Image preview
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Image Preview")
                            .font(DesignSystem.Typography.headline)

                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .cornerRadius(DesignSystem.CornerRadius.medium)
                            Spacer()
                        }

                        Text(glassItem.name)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Divider()

                    // Terms and conditions
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Terms")
                            .font(DesignSystem.Typography.headline)

                        Toggle(isOn: $hasPermission) {
                            Text("I have permission to share this image and allow Molten to use it")
                                .font(DesignSystem.Typography.body)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.accentPrimary))

                        Toggle(isOn: $offersFreeOfCharge) {
                            Text("I offer this image to Molten free of charge")
                                .font(DesignSystem.Typography.body)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.accentPrimary))
                    }

                    Divider()

                    // Email field
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Contact Email")
                            .font(DesignSystem.Typography.headline)

                        Text("Required for us to contact you about this submission")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        TextField("your@email.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        if !email.isEmpty && !isValidEmail {
                            Text("Please enter a valid email address")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(.red)
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.medium)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitImage()
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .alert("Image Submitted", isPresented: $showingConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your submission! We'll review it and may contact you at \(email).")
            }
        }
    }

    private func submitImage() {
        isSubmitting = true
        errorMessage = nil

        // TODO: Implement actual submission to API
        // For now, just show success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSubmitting = false
            showingConfirmation = true
        }
    }
}

#Preview {
    let sampleGlassItem = GlassItemModel(
        stable_id: "bullseye-0001-0",
        name: "Bullseye Red Opal",
        manufacturer: "be",
        code: "0001",
        variant: "",
        coe: 90,
        type: "rod"
    )

    let sampleImage = UIImage(systemName: "photo")!

    return ImageSubmissionSheet(
        image: sampleImage,
        glassItem: sampleGlassItem
    )
}
#endif

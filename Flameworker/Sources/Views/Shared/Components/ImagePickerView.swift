//
//  ImagePickerView.swift
//  Flameworker
//
//  SwiftUI wrapper for image selection using PhotosPicker (iOS 16+)
//

import SwiftUI
import PhotosUI

/// Modern SwiftUI image picker using PhotosPickerphpItem
struct ImagePickerView: View {
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false

    let onImageSelected: ((UIImage) -> Void)?

    init(selectedImage: Binding<UIImage?>, onImageSelected: ((UIImage) -> Void)? = nil) {
        self._selectedImage = selectedImage
        self.onImageSelected = onImageSelected
    }

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "photo.on.rectangle.angled")
                Text("Choose Photo")
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let newValue = newValue {
                    await loadImage(from: newValue)
                }
            }
        }
    }

    @MainActor
    private func loadImage(from item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                // Resize image to reasonable max dimensions to save space
                let resizedImage = resizeImage(uiImage, maxDimension: 2048)
                selectedImage = resizedImage
                onImageSelected?(resizedImage)
            }
        } catch {
            print("❌ Failed to load image: \(error)")
        }
    }

    /// Resize image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)

        // If image is already smaller than max, return original
        guard maxSize > maxDimension else { return image }

        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

/// Camera picker for taking new photos
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    let onImageSelected: ((UIImage) -> Void)?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Resize to save space
                let resizedImage = parent.resizeImage(image, maxDimension: 2048)
                parent.selectedImage = resizedImage
                parent.onImageSelected?(resizedImage)
            }
            parent.dismiss.callAsFunction()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss.callAsFunction()
        }
    }

    /// Resize image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)

        // If image is already smaller than max, return original
        guard maxSize > maxDimension else { return image }

        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

/// Combined image source picker sheet (camera or photo library)
struct ImageSourcePickerSheet: View {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false

    let onImageSelected: ((UIImage) -> Void)?

    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    showingCamera = true
                }) {
                    Label("Take Photo", systemImage: "camera")
                }

                Button(action: {
                    showingPhotoPicker = true
                }) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            }
            .navigationTitle("Add Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPickerView(selectedImage: $selectedImage, onImageSelected: { image in
                    onImageSelected?(image)
                    isPresented = false
                })
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotosPickerWrapper(selectedImage: $selectedImage, onImageSelected: { image in
                    onImageSelected?(image)
                    isPresented = false
                })
            }
        }
    }
}

/// Wrapper for PhotosPicker to use in sheet
private struct PhotosPickerWrapper: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    let onImageSelected: ((UIImage) -> Void)?

    var body: some View {
        NavigationView {
            VStack {
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .padding()

                    Button("Use This Photo") {
                        onImageSelected?(selectedImage)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ImagePickerView(selectedImage: $selectedImage, onImageSelected: onImageSelected)
                        .padding()
                    Spacer()
                }
            }
            .navigationTitle("Choose Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

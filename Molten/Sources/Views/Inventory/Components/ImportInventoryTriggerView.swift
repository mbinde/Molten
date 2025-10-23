//
//  ImportInventoryTriggerView.swift
//  Molten
//
//  Trigger view for selecting an inventory import file
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportInventoryTriggerView: View {
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var showImportView = false

    var onImportComplete: (() -> Void)?

    var body: some View {
        Button {
            showFilePicker = true
        } label: {
            Label("Import from File", systemImage: "square.and.arrow.down")
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showImportView) {
            if let fileURL = selectedFileURL {
                ImportInventoryView(fileURL: fileURL) {
                    onImportComplete?()
                }
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Store the URL and show import view
            selectedFileURL = url
            showImportView = true

        case .failure(let error):
            print("❌ File selection failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ImportInventoryTriggerView()
}

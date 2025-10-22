//
//  AddFormScaffold.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Reusable scaffold for "Add" forms with standard error handling, toolbar, and validation
//

import SwiftUI
import Combine

// MARK: - AddFormScaffold

/// Standard scaffold for "Add" forms providing consistent error handling, toolbar, and validation
/// Eliminates duplication across AddInventoryItemView, AddShoppingListItemView, AddPurchaseRecordView
struct AddFormScaffold<Content: View>: View {
    let title: String
    let content: Content
    let isValid: Bool
    let onSave: () -> Void
    let onCancel: (() -> Void)?

    @State private var errorMessage = ""
    @State private var showingError = false

    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        isValid: Bool,
        onSave: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isValid = isValid
        self.onSave = onSave
        self.onCancel = onCancel
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            Form {
                content
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                toolbarContent
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { showingError = false }
            } message: {
                Text(errorMessage)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                KeyboardDismissal.hideKeyboard()
                if let onCancel = onCancel {
                    onCancel()
                } else {
                    dismiss()
                }
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
                onSave()
            }
            .disabled(!isValid)
        }
    }

    /// Show an error message to the user
    func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - AddFormState

/// Observable state manager for Add forms
/// Provides standard error handling, loading state, and validation
@MainActor
final class AddFormState: ObservableObject {
    @Published var errorMessage = ""
    @Published var showingError = false
    @Published var isLoading = false

    /// Show an error to the user
    func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    /// Show an error from a thrown Error
    func showError(_ error: Error) {
        showError(error.localizedDescription)
    }

    /// Execute an async operation with error handling
    func performAsync<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await operation()
            return .success(result)
        } catch {
            await MainActor.run {
                showError(error)
            }
            return .failure(error)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var quantity = ""
    @Previewable @State var store = ""

    let isValid = !quantity.isEmpty

    return AddFormScaffold(
        title: "Add to Shopping List",
        isValid: isValid,
        onSave: {
            print("Save tapped - quantity: \(quantity), store: \(store)")
        }
    ) {
        Section("Details") {
            LabeledDecimalField("Quantity", value: $quantity)

            LabeledField("Store (optional)") {
                TextField("e.g., Frantz Art Glass", text: $store)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

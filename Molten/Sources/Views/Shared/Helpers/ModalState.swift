//
//  ModalState.swift
//  Molten
//
//  Created by Assistant on 11/15/25.
//  Simplified modal state management to reduce boilerplate
//

import SwiftUI

/// A simple modal state manager to reduce @State boilerplate for sheets and alerts
/// Instead of multiple @State booleans, use a single @State with ModalState
///
/// Example usage:
/// ```swift
/// @State private var modal = ModalState<AddItemViewModel>()
///
/// // Present modal
/// Button("Add") { modal.present(AddItemViewModel()) }
///
/// // In view body
/// .sheet(item: $modal.item) { viewModel in
///     AddItemSheet(viewModel: viewModel) { modal.dismiss() }
/// }
/// ```
struct ModalState<Item: Identifiable> {
    var item: Item?

    /// Present a modal with the given item
    mutating func present(_ item: Item) {
        self.item = item
    }

    /// Dismiss the current modal
    mutating func dismiss() {
        self.item = nil
    }

    /// Check if a modal is currently presented
    var isPresented: Bool {
        item != nil
    }
}

/// Modal state for cases where you just need a boolean toggle (no data)
struct BooleanModalState {
    var isPresented: Bool = false

    /// Present the modal
    mutating func present() {
        isPresented = true
    }

    /// Dismiss the modal
    mutating func dismiss() {
        isPresented = false
    }

    /// Toggle the modal state
    mutating func toggle() {
        isPresented.toggle()
    }
}

// MARK: - Helper Extensions

extension View {
    /// Present a sheet using ModalState with automatic Identifiable binding
    func sheet<Item: Identifiable, Content: View>(
        state: Binding<ModalState<Item>>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        self.sheet(item: state.item, content: content)
    }

    /// Present a sheet using BooleanModalState
    func sheet<Content: View>(
        state: Binding<BooleanModalState>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: state.isPresented, content: content)
    }
}

// MARK: - Previews

private struct PreviewViewModel: Identifiable {
    let id = UUID()
    let title: String
}

#Preview("ModalState with Item") {
    struct DemoView: View {
        @State private var modal = ModalState<PreviewViewModel>()

        var body: some View {
            VStack(spacing: 20) {
                Button("Show Sheet") {
                    modal.present(PreviewViewModel(title: "Example Sheet"))
                }

                Text("Is Presented: \(modal.isPresented ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .sheet(item: $modal.item) { viewModel in
                NavigationView {
                    VStack {
                        Text(viewModel.title)
                            .font(.title)

                        Button("Dismiss") {
                            modal.dismiss()
                        }
                        .padding()
                    }
                    .navigationTitle("Modal")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    return DemoView()
}

#Preview("BooleanModalState") {
    struct DemoView: View {
        @State private var modal = BooleanModalState()

        var body: some View {
            VStack(spacing: 20) {
                Button("Show Sheet") {
                    modal.present()
                }

                Button("Toggle Sheet") {
                    modal.toggle()
                }

                Text("Is Presented: \(modal.isPresented ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .sheet(isPresented: $modal.isPresented) {
                NavigationView {
                    VStack {
                        Text("Simple Sheet")
                            .font(.title)

                        Button("Dismiss") {
                            modal.dismiss()
                        }
                        .padding()
                    }
                    .navigationTitle("Modal")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    return DemoView()
}

#Preview("Multiple Modals") {
    struct DemoView: View {
        @State private var addModal = BooleanModalState()
        @State private var editModal = ModalState<PreviewViewModel>()
        @State private var deleteAlert = BooleanModalState()

        var body: some View {
            List {
                Button("Add Item") {
                    addModal.present()
                }

                Button("Edit Item") {
                    editModal.present(PreviewViewModel(title: "Edit Sheet"))
                }

                Button("Delete Item") {
                    deleteAlert.present()
                }

                Section("State") {
                    Text("Add modal: \(addModal.isPresented ? "shown" : "hidden")")
                    Text("Edit modal: \(editModal.isPresented ? "shown" : "hidden")")
                    Text("Delete alert: \(deleteAlert.isPresented ? "shown" : "hidden")")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .sheet(isPresented: $addModal.isPresented) {
                Text("Add Item Sheet")
                    .padding()
            }
            .sheet(item: $editModal.item) { viewModel in
                VStack {
                    Text(viewModel.title)
                    Button("Done") { editModal.dismiss() }
                }
                .padding()
            }
            .alert("Delete Item", isPresented: $deleteAlert.isPresented) {
                Button("Cancel", role: .cancel) { deleteAlert.dismiss() }
                Button("Delete", role: .destructive) { deleteAlert.dismiss() }
            }
        }
    }

    return DemoView()
}

#Preview("Before & After Comparison") {
    VStack(alignment: .leading, spacing: 30) {
        VStack(alignment: .leading, spacing: 8) {
            Text("❌ Before (11 lines)")
                .font(.headline)

            Text("""
            @State private var showingAdd = false
            @State private var showingEdit = false
            @State private var showingDelete = false
            @State private var selectedItem: Item?

            Button("Add") { showingAdd = true }
            Button("Edit") {
                selectedItem = item
                showingEdit = true
            }
            Button("Delete") { showingDelete = true }
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Divider()

        VStack(alignment: .leading, spacing: 8) {
            Text("✅ After (5 lines)")
                .font(.headline)

            Text("""
            @State private var addModal = BooleanModalState()
            @State private var editModal = ModalState<Item>()
            @State private var deleteAlert = BooleanModalState()

            Button("Add") { addModal.present() }
            Button("Edit") { editModal.present(item) }
            Button("Delete") { deleteAlert.present() }
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    .padding()
}

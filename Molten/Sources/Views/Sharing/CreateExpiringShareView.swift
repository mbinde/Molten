//
//  CreateExpiringShareView.swift
//  Molten
//
//  View for creating a new expiring share alias
//

import SwiftUI

struct CreateExpiringShareView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InventorySharingViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display Name", text: $viewModel.expiringShareDisplayName)
                        .textContentType(.name)
                } header: {
                    Text("Display Name")
                } footer: {
                    Text("Choose a unique name for this temporary share (e.g., \"GAS 2025 Conference\")")
                }

                Section {
                    TextField("Notes (Optional)", text: $viewModel.expiringShareNotes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Add optional notes visible to people who download this share")
                }

                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Picker("Hours", selection: $viewModel.expiringShareHours) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text("\(hour)").tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 60)

                            Text("Hours")

                            Spacer()

                            Picker("Days", selection: $viewModel.expiringShareDays) {
                                ForEach(0...30, id: \.self) { day in
                                    Text("\(day)").tag(day)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 60)

                            Text("Days")
                        }

                        // Show calculated expiration time
                        if let expirationDate = expirationPreview {
                            HStack {
                                Text("Expires")
                                Spacer()
                                Text(expirationDate, style: .date)
                                    .foregroundColor(.secondary)
                                Text(expirationDate, style: .time)
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }

                        // Show validation error if invalid
                        if !isValidDuration {
                            Text("Minimum 1 hour, maximum 30 days + 23 hours")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Expiration")
                } footer: {
                    Text("After this time, the share code will stop working. You cannot extend it once created.")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create Temporary Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createExpiringShare()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.expiringShareDisplayName.isEmpty || viewModel.isCreatingExpiringShare || !isValidDuration)
                }
            }
        }
    }

    private var isValidDuration: Bool {
        let duration = ExpiringShareDuration(days: viewModel.expiringShareDays, hours: viewModel.expiringShareHours)
        return duration.isValid
    }

    private var expirationPreview: Date? {
        guard isValidDuration else { return nil }
        let duration = ExpiringShareDuration(days: viewModel.expiringShareDays, hours: viewModel.expiringShareHours)
        return duration.expirationDate()
    }
}

#Preview {
    CreateExpiringShareView(viewModel: InventorySharingViewModel())
}

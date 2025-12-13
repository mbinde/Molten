//
//  AccountRecoveryView.swift
//  Molten
//
//  View for recovering account access when security key is missing
//

import SwiftUI

struct AccountRecoveryView: View {
    @Binding var recoveryEmail: String
    @Binding var recoveryError: String?
    @Binding var isRecovering: Bool
    @Binding var isPendingVerification: Bool
    let onRecovery: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(DesignSystem.Colors.accentWarning)
                        Text("Account Recovery")
                            .font(.title2.bold())
                    }

                    Text("Your security key was not found. This can happen on a new device if iCloud Keychain sync is disabled, or after a factory reset.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                // Email recovery option
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recover with Email")
                        .font(.headline)

                    Text("If you registered with an email address, enter it below to recover your account.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    TextField("Email address", text: $recoveryEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    if let error = recoveryError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.accentDanger)
                    }

                    Button {
                        onRecovery()
                    } label: {
                        HStack {
                            if isRecovering {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                            }
                            Text("Recover Account")
                                .font(.body.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRecovering || !isValidEmail(recoveryEmail))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Divider with "or"
                HStack {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1)
                }
                .padding(.vertical, 8)

                // New account option
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start Fresh")
                        .font(.headline)

                    Text("If you used anonymous mode, or want to create a new account. Your previously imported purchases will still be visible, but any receipts waiting in the inbox will not be recoverable.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    NavigationLink {
                        PurchaseImportSettingsView()
                    } label: {
                        Text("Set Up New Account")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Recovery")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

#Preview {
    NavigationStack {
        AccountRecoveryView(
            recoveryEmail: .constant(""),
            recoveryError: .constant(nil),
            isRecovering: .constant(false),
            isPendingVerification: .constant(false),
            onRecovery: {}
        )
    }
}

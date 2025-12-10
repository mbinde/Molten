//
//  PurchaseListView.swift
//  Molten
//
//  List view showing all parsed purchases
//  Allows viewing purchase details and importing items to inventory
//

import SwiftUI

struct PurchaseListView: View {
    @Environment(\.appDependencies) private var dependencies
    @Binding var showingHelp: Bool
    @State private var purchases: [ReceiptSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isKeyNotFoundError = false
    @State private var showImported = false
    @State private var totalCount = 0
    @State private var showCopiedFeedback = false
    @State private var showingRecoverySheet = false
    @State private var recoveryEmail: String = ""
    @State private var recoveryError: String?
    @State private var isRecovering = false
    @State private var showingRecoveryEmailSent = false

    private var receiptService: ReceiptService {
        dependencies.receiptService
    }

    private let forwardingAddress = "receipts@moltenglass.app"

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading purchases...")
            } else if let error = errorMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(DesignSystem.Colors.accentWarning)
                            Text("Error")
                                .font(.title2.bold())
                        }
                        .padding(.bottom, 4)

                        Text(error)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Show recovery option inline for key-not-found errors when email recovery is possible
                        if isKeyNotFoundError && canRecoverAccount {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Enter your registered email to recover:")
                                    .font(.subheadline)

                                TextField("Email address", text: $recoveryEmail)
                                    .textFieldStyle(.roundedBorder)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()

                                if let recoveryError = recoveryError {
                                    Text(recoveryError)
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.Colors.accentDanger)
                                }

                                Button {
                                    requestRecovery()
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
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isRecovering || !isValidEmail(recoveryEmail))
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.top, 8)
                        } else {
                            Button {
                                loadPurchases()
                            } label: {
                                Text("Retry")
                                    .font(.body.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .alert("Recovery Email Sent", isPresented: $showingRecoveryEmailSent) {
                    Button("OK") {
                        recoveryEmail = ""
                        recoveryError = nil
                    }
                } message: {
                    Text("Check your inbox and click the recovery link to restore access to your account.")
                }
            } else if purchases.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(purchases) { purchase in
                        NavigationLink {
                            PurchaseDetailView(purchaseId: purchase.id)
                        } label: {
                            PurchaseRow(purchase: purchase)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Show Imported", isOn: $showImported)
                    Button {
                        loadPurchases()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Button {
                        showingHelp = true
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onChange(of: showImported) { _, _ in
            loadPurchases()
        }
        .onAppear {
            loadPurchases()
        }
        .refreshable {
            await refreshPurchases()
        }
    }

    private func loadPurchases() {
        isLoading = true
        errorMessage = nil
        isKeyNotFoundError = false

        Task { @MainActor in
            do {
                let response = try await receiptService.listReceipts(
                    limit: 100,
                    offset: 0,
                    includeAcknowledged: showImported
                )
                purchases = response.receipts
                totalCount = response.total
            } catch KeyPairError.keyNotFound {
                // Customize message based on identifier type
                errorMessage = keyNotFoundMessage
                isKeyNotFoundError = true
            } catch {
                errorMessage = error.userFacingMessage
            }
            isLoading = false
        }
    }

    /// Customized error message for key not found, based on how user registered
    private var keyNotFoundMessage: String {
        let baseMessage = "Your security key was not found.\n\nThis can happen on a new device if iCloud Keychain sync is disabled, or after a factory reset."

        switch receiptService.identifierType {
        case .email:
            // Recovery form shown inline, so keep message short
            return baseMessage
        case .plusAddress:
            return baseMessage + "\n\nSince you used the anonymous option, there is no way to recover your account. You'll need to set up a new account in Settings → Purchase Import. Previously imported receipts cannot be recovered."
        case nil:
            // Unknown - show both options to be safe, recovery form shown inline
            return baseMessage + "\n\nIf you used the anonymous option, you'll need to set up a new account in Settings → Purchase Import. Previously imported receipts cannot be recovered."
        }
    }

    /// Whether account recovery is possible (email or unknown identifier type)
    private var canRecoverAccount: Bool {
        receiptService.identifierType != .plusAddress
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func requestRecovery() {
        guard isValidEmail(recoveryEmail) else { return }

        isRecovering = true
        recoveryError = nil

        Task { @MainActor in
            do {
                _ = try await receiptService.requestAccountRecovery(email: recoveryEmail)
                showingRecoveryEmailSent = true
            } catch let apiError as ReceiptAPIError {
                if case .badRequest(let message) = apiError {
                    recoveryError = message
                } else {
                    recoveryError = apiError.localizedDescription
                }
            } catch {
                recoveryError = error.localizedDescription
            }
            isRecovering = false
        }
    }

    private func refreshPurchases() async {
        do {
            // First sync to get new purchases from server
            _ = try await receiptService.syncReceipts()

            // Then fetch the list
            let response = try await receiptService.listReceipts(
                limit: 100,
                offset: 0,
                includeAcknowledged: showImported
            )
            purchases = response.receipts
            totalCount = response.total
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    // MARK: - Empty State View

    @ViewBuilder
    private var emptyStateView: some View {
        List {
            // Success header section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You're All Set!")
                            .font(.headline)
                        Text("Start forwarding your order confirmation emails.")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Forwarding address section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Forward orders to:")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Button {
                        copyEmail()
                    } label: {
                        HStack {
                            if receiptService.identifierType == .plusAddress, let email = receiptService.receiptEmail {
                                Text(email)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            } else {
                                Text(forwardingAddress)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            Spacer()

                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                if receiptService.identifierType == .email, let email = receiptService.receiptEmail {
                    Text("Forward order confirmations from \(email)")
                } else {
                    Text("This email address is unique to you.")
                }
            }

            // How it works section
            Section("Next Steps") {
                SetupStepRow(
                    number: "1",
                    title: "Forward an order confirmation",
                    description: "Send your glass order emails to the address above"
                )

                SetupStepRow(
                    number: "2",
                    title: "We'll parse your order",
                    description: "Items, prices, and order details are extracted automatically"
                )

                SetupStepRow(
                    number: "3",
                    title: "Review and import",
                    description: "Add items to your inventory with one tap"
                )
            }

            // Supported retailers section
            Section {
                Text("ABR Imagery, Bullseye Glass, Glass Alchemy, Momka's Glass, Mountain Glass Arts, Frantz Art Glass, and more.")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } header: {
                Text("Supported Retailers")
            }

            // Show imported toggle if viewing pending
            if !showImported {
                Section {
                    Button {
                        showImported = true
                        loadPurchases()
                    } label: {
                        Label("Show Imported Purchases", systemImage: "checkmark.circle")
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showCopiedFeedback {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Email address copied")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: showCopiedFeedback)
    }

    private func copyEmail() {
        let email: String
        if receiptService.identifierType == .plusAddress, let plusEmail = receiptService.receiptEmail {
            email = plusEmail
        } else {
            email = forwardingAddress
        }

        UIPasteboard.general.string = email
        withAnimation {
            showCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
}

// MARK: - Setup Step Row

private struct SetupStepRow: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(DesignSystem.Colors.moltenOrange)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Purchase Row

private struct PurchaseRow: View {
    let purchase: ReceiptSummary

    private var retailerDisplayName: String {
        purchase.retailerName ?? purchase.retailerId.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(retailerDisplayName)
                    .font(.headline)

                Spacer()

                if purchase.acknowledged {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Text("New")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.moltenOrange)
                        .cornerRadius(8)
                }
            }

            HStack {
                if let orderNumber = purchase.orderNumber {
                    Text("Order #\(orderNumber)")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                if let orderDate = purchase.orderDate {
                    Text(orderDate, formatter: dateFormatter)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "cube.box")
                        .font(.caption)
                    Text("\(purchase.itemCount) item\(purchase.itemCount == 1 ? "" : "s")")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                if let total = purchase.totalAmount {
                    Text(total, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PurchaseListView(showingHelp: .constant(false))
    }
}

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

    // Server receipts (unacknowledged - the "inbox")
    @State private var newReceipts: [ReceiptSummary] = []

    // Local purchases (from Core Data - already imported)
    @State private var importedPurchases: [PurchaseRecordModel] = []

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isKeyNotFoundError = false
    @State private var hasAnyPurchases = false  // Track if user has ANY purchases (new or imported)
    @State private var showCopiedFeedback = false
    @State private var showingRecoverySheet = false
    @State private var recoveryEmail: String = ""
    @State private var recoveryError: String?
    @State private var isRecovering = false
    @State private var showingRecoveryEmailSent = false

    // Verification polling state (for pending recovery)
    @State private var isCheckingVerification = false
    @State private var isResendingVerification = false
    @State private var verificationMessage: String?
    @State private var isCheckingForOrders = false

    // Auto-refresh timer
    @State private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60  // seconds

    private var receiptService: ReceiptService {
        dependencies.receiptService
    }

    private var purchaseRecordRepository: PurchaseRecordRepository {
        dependencies.purchaseRecordRepository
    }

    private let forwardingAddress = "purchases@moltenglass.app"

    private var forwardingEmailAddress: String {
        if receiptService.identifierType == .plusAddress, let email = receiptService.receiptEmail {
            return email
        }
        return forwardingAddress
    }

    private var forwardingAddressFooter: String {
        if receiptService.identifierType == .email, let email = receiptService.receiptEmail {
            return "Forward order confirmations from \(email)"
        }
        return "This email address is unique to you."
    }

    /// New receipts sorted by date (most recent first)
    private var sortedNewReceipts: [ReceiptSummary] {
        newReceipts.sorted { first, second in
            let date1 = first.orderDate ?? first.receivedAt
            let date2 = second.orderDate ?? second.receivedAt
            return date1 > date2
        }
    }

    /// Imported purchases sorted by date (most recent first)
    private var sortedImportedPurchases: [PurchaseRecordModel] {
        importedPurchases.sorted { $0.datePurchased > $1.datePurchased }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading purchases...")
            } else if receiptService.isPendingEmailVerification {
                pendingVerificationView
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
            } else if !hasAnyPurchases {
                // Only show onboarding when user has NO purchases at all
                emptyStateView
                    .refreshable {
                        await refreshPurchases()
                    }
            } else {
                List {
                    // New receipts section (from server - unacknowledged)
                    if !sortedNewReceipts.isEmpty {
                        Section {
                            ForEach(sortedNewReceipts) { receipt in
                                NavigationLink {
                                    PurchaseDetailView(purchaseId: receipt.id)
                                } label: {
                                    PurchaseRow(purchase: receipt)
                                }
                            }
                        } header: {
                            HStack {
                                Text("New")
                                Spacer()
                                Text("\(sortedNewReceipts.count)")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }

                    // Imported purchases section (from local Core Data)
                    if !sortedImportedPurchases.isEmpty {
                        Section {
                            ForEach(sortedImportedPurchases) { purchase in
                                NavigationLink {
                                    PurchaseRecordDetailView(purchaseRecord: purchase)
                                } label: {
                                    ImportedPurchaseRow(purchase: purchase)
                                }
                            }
                        } header: {
                            HStack {
                                Text("Imported")
                                Spacer()
                                Text("\(sortedImportedPurchases.count)")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
                .refreshable {
                    await refreshPurchases()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    loadPurchases()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        .onAppear {
            loadPurchases()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    // MARK: - Auto-Refresh

    private func startAutoRefresh() {
        stopAutoRefresh()  // Cancel any existing task
        refreshTask = Task { @MainActor in
            // Check immediately on tab open
            await silentRefresh()
            // Then check every 60 seconds
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                guard !Task.isCancelled else { break }
                await silentRefresh()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Refresh purchases without showing loading indicator
    private func silentRefresh() async {
        do {
            // Sync to get new receipts from server
            _ = try await receiptService.syncReceipts()

            // Fetch only unacknowledged receipts from server (the "inbox")
            let response = try await receiptService.listReceipts(
                limit: 100,
                offset: 0,
                includeAcknowledged: false
            )
            newReceipts = response.receipts

            // Fetch imported purchases from local Core Data
            importedPurchases = try await purchaseRecordRepository.getAllRecords()

            hasAnyPurchases = !newReceipts.isEmpty || !importedPurchases.isEmpty
        } catch {
            // Silent refresh - don't show errors for background polling
        }
    }

    private func loadPurchases() {
        isLoading = true
        errorMessage = nil
        isKeyNotFoundError = false

        Task { @MainActor in
            do {
                // Fetch only unacknowledged receipts from server (the "inbox")
                let response = try await receiptService.listReceipts(
                    limit: 100,
                    offset: 0,
                    includeAcknowledged: false
                )
                newReceipts = response.receipts

                // Fetch imported purchases from local Core Data
                importedPurchases = try await purchaseRecordRepository.getAllRecords()

                hasAnyPurchases = !newReceipts.isEmpty || !importedPurchases.isEmpty
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
                // Recovery request successful - service is now in pending verification state
                // Clear error state and reload to show the pending verification UI
                errorMessage = nil
                isKeyNotFoundError = false
                recoveryEmail = ""
                // Note: The view will now show pendingVerificationSection via receiptService.isPendingEmailVerification
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
            // First sync to get new receipts from server
            _ = try await receiptService.syncReceipts()

            // Fetch only unacknowledged receipts from server
            let response = try await receiptService.listReceipts(
                limit: 100,
                offset: 0,
                includeAcknowledged: false
            )
            newReceipts = response.receipts

            // Fetch imported purchases from local Core Data
            importedPurchases = try await purchaseRecordRepository.getAllRecords()

            hasAnyPurchases = !newReceipts.isEmpty || !importedPurchases.isEmpty
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func checkForOrders() {
        isCheckingForOrders = true
        errorMessage = nil

        Task { @MainActor in
            do {
                // Sync to get new receipts from server
                _ = try await receiptService.syncReceipts()

                // Fetch only unacknowledged receipts from server
                let response = try await receiptService.listReceipts(
                    limit: 100,
                    offset: 0,
                    includeAcknowledged: false
                )
                newReceipts = response.receipts

                // Fetch imported purchases from local Core Data
                importedPurchases = try await purchaseRecordRepository.getAllRecords()

                hasAnyPurchases = !newReceipts.isEmpty || !importedPurchases.isEmpty
            } catch {
                errorMessage = error.userFacingMessage
            }
            isCheckingForOrders = false
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
            ForwardingAddressCard(
                email: forwardingEmailAddress,
                footerText: forwardingAddressFooter,
                onCopy: copyEmail
            )

            // Check for orders button
            CheckForOrdersButton(isLoading: isCheckingForOrders, action: checkForOrders)

            // How it works section
            PurchaseImportSetupSteps()

            // Supported retailers section
            SupportedRetailersSection()
        }
        .overlay(alignment: .bottom) {
            CopiedFeedbackOverlay(isVisible: showCopiedFeedback)
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

    // MARK: - Pending Verification View

    @ViewBuilder
    private var pendingVerificationView: some View {
        List {
            if receiptService.isRecoveryPending {
                // Account Recovery - user doesn't have credentials yet, must click email link
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.orange)
                            Text("Recovery Pending")
                                .font(.headline)
                        }

                        Text("We sent a recovery link to \(receiptService.receiptEmail ?? "your email"). Please check your inbox and click the link to restore access.")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("This may take a few minutes to arrive. Check your spam folder if you don't see it.")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, 4)

                    if let message = verificationMessage {
                        HStack {
                            Image(systemName: message.contains("recovered") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(message.contains("recovered") ? .green : .orange)
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Button {
                        checkRecoveryStatus()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Check Recovery Status")
                            if isCheckingVerification {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                        }
                    }
                    .disabled(isCheckingVerification)

                    Button(role: .destructive) {
                        receiptService.disableReceipts()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel Recovery")
                        }
                    }
                } header: {
                    Text("Account Recovery")
                } footer: {
                    Text("After clicking the link in your email, tap 'Check Recovery Status' to complete the process.")
                }
            } else {
                // Normal email verification - user has credentials, can check status
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "envelope.badge")
                                .foregroundColor(.orange)
                            Text("Verification Pending")
                                .font(.headline)
                        }

                        Text("We sent a verification link to \(receiptService.receiptEmail ?? "your email"). Please check your inbox and click the link to complete setup.")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("This may take a few minutes to arrive. Check your spam folder if you don't see it.")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, 4)

                    if let message = verificationMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(message)
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Button {
                        checkVerificationStatus()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Check Verification Status")
                            if isCheckingVerification {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                        }
                    }
                    .disabled(isCheckingVerification)

                    Button {
                        resendVerificationEmail()
                    } label: {
                        HStack {
                            Image(systemName: "envelope.arrow.triangle.branch")
                            Text("Resend Verification Email")
                            if isResendingVerification {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                        }
                    }
                    .disabled(isResendingVerification)

                    Button(role: .destructive) {
                        receiptService.disableReceipts()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel Setup")
                        }
                    }
                } header: {
                    Text("Email Verification")
                }
            }
        }
    }

    private func checkVerificationStatus() {
        isCheckingVerification = true
        verificationMessage = nil

        Task { @MainActor in
            do {
                let verified = try await receiptService.checkEmailVerificationStatus()
                if verified {
                    // Verification complete - reload to show purchases
                    loadPurchases()
                } else {
                    verificationMessage = "Not yet verified. Please click the link in your email."
                }
            } catch {
                verificationMessage = "Could not check status: \(error.localizedDescription)"
            }
            isCheckingVerification = false
        }
    }

    private func checkRecoveryStatus() {
        isCheckingVerification = true
        verificationMessage = nil

        Task { @MainActor in
            do {
                let recovered = try await receiptService.checkRecoveryStatus()
                if recovered {
                    // Recovery complete - reload to show purchases
                    verificationMessage = "Account recovered! Loading your purchases..."
                    loadPurchases()
                } else {
                    verificationMessage = "Recovery not yet complete. Please click the link in your recovery email first."
                }
            } catch {
                verificationMessage = "Could not check recovery status: \(error.localizedDescription)"
            }
            isCheckingVerification = false
        }
    }

    private func resendVerificationEmail() {
        isResendingVerification = true
        verificationMessage = nil

        Task { @MainActor in
            do {
                try await receiptService.resendVerificationEmail()
                verificationMessage = "Verification email sent! Check your inbox."
            } catch {
                verificationMessage = "Could not resend: \(error.localizedDescription)"
            }
            isResendingVerification = false
        }
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

// MARK: - Imported Purchase Row (for local Core Data records)

private struct ImportedPurchaseRow: View {
    let purchase: PurchaseRecordModel

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // No checkmark badge needed - being in the "Imported" section is clear enough
            Text(purchase.supplier)
                .font(.headline)

            HStack {
                if let orderNumber = purchase.orderNumber {
                    Text("Order #\(orderNumber)")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Text(purchase.datePurchased, formatter: dateFormatter)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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

                if let total = purchase.formattedPrice {
                    Text(total)
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

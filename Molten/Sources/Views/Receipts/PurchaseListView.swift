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
    @State private var recoveryEmail: String = ""
    @State private var recoveryError: String?
    @State private var isRecovering = false

    // Verification polling state (for pending recovery)
    @State private var isPendingVerification = false  // Local state to trigger view updates
    @State private var isCheckingVerification = false
    @State private var isResendingVerification = false
    @State private var verificationMessage: String?
    @State private var isCheckingForOrders = false

    // Auto-refresh timer
    @State private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 60  // seconds

    // Report issue state
    @State private var reportedReceiptIds: Set<String> = []
    @State private var reportingReceiptId: String?
    @State private var reportAlert: ReportAlert?

    private enum ReportAlert: Identifiable {
        case success
        case error(String)

        var id: String {
            switch self {
            case .success: return "success"
            case .error(let msg): return "error-\(msg)"
            }
        }
    }

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

    /// New receipts sorted by date (most recent first), excluding hidden ones
    private var sortedNewReceipts: [ReceiptSummary] {
        let hiddenIds = receiptService.hiddenReceiptIds
        return newReceipts
            .filter { !hiddenIds.contains($0.id) }
            .sorted { first, second in
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
            } else if isPendingVerification || receiptService.isPendingEmailVerification {
                pendingVerificationView
            } else if let error = errorMessage, !isKeyNotFoundError, !hasAnyPurchases {
                // Show blocking error ONLY when user has NO local purchases
                // If they have purchases, errors are shown inline in the list
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

                        Button {
                            loadPurchases()
                        } label: {
                            Text("Retry")
                                .font(.body.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if !hasAnyPurchases && !isKeyNotFoundError {
                // Only show onboarding when user has NO purchases at all
                emptyStateView
                    .refreshable {
                        await refreshPurchases()
                    }
            } else {
                List {
                    // Inline error section (shown when there's an error but user has purchases)
                    if let error = errorMessage, !isKeyNotFoundError {
                        Section {
                            NavigationLink {
                                ErrorDetailView(
                                    errorMessage: error,
                                    onRetry: loadPurchases
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundColor(DesignSystem.Colors.accentWarning)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Connection Error")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Tap to view details and retry")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Account recovery section (shown when security key is missing)
                    if isKeyNotFoundError {
                        Section {
                            NavigationLink {
                                AccountRecoveryView(
                                    recoveryEmail: $recoveryEmail,
                                    recoveryError: $recoveryError,
                                    isRecovering: $isRecovering,
                                    isPendingVerification: $isPendingVerification,
                                    onRecovery: requestRecovery
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundColor(DesignSystem.Colors.accentWarning)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Account Recovery Needed")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Tap to recover your account or start fresh")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // New receipts section (from server - unacknowledged)
                    if !sortedNewReceipts.isEmpty {
                        Section {
                            ForEach(sortedNewReceipts) { receipt in
                                NavigationLink {
                                    PurchaseDetailView(purchaseId: receipt.id)
                                } label: {
                                    PurchaseRow(
                                        purchase: receipt,
                                        isReported: reportedReceiptIds.contains(receipt.id),
                                        isReporting: reportingReceiptId == receipt.id
                                    )
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // Show report action for failed receipts that haven't been reported
                                    if receipt.isParseFailed && !reportedReceiptIds.contains(receipt.id) {
                                        Button {
                                            reportParseIssue(receiptId: receipt.id)
                                        } label: {
                                            Label("Report", systemImage: "envelope.badge")
                                        }
                                        .tint(.orange)
                                    }
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
            // Sync local pending state from service (in case it was set in a previous session)
            isPendingVerification = receiptService.isPendingEmailVerification
            loadPurchases()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .alert(item: $reportAlert) { alert in
            switch alert {
            case .success:
                return Alert(
                    title: Text("Report Submitted"),
                    message: Text("Thank you for reporting this issue. We'll investigate and improve our parser."),
                    dismissButton: .default(Text("OK"))
                )
            case .error(let message):
                return Alert(
                    title: Text("Could Not Submit Report"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Report Issue

    private func reportParseIssue(receiptId: String) {
        reportingReceiptId = receiptId

        Task { @MainActor in
            do {
                try await receiptService.reportParseIssue(receiptId: receiptId)
                // Hide the receipt locally so it doesn't show in the list
                receiptService.hideReceipt(id: receiptId)
                reportedReceiptIds.insert(receiptId)
                reportAlert = .success
            } catch {
                reportAlert = .error(error.localizedDescription)
            }
            reportingReceiptId = nil
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
            // Always fetch imported purchases from local Core Data first - this never fails due to key issues
            do {
                importedPurchases = try await purchaseRecordRepository.getAllRecords()
            } catch {
                // Local fetch failed - rare, but show error
                errorMessage = error.userFacingMessage
                isLoading = false
                return
            }

            // Try to fetch server receipts (may fail if key is missing)
            do {
                let response = try await receiptService.listReceipts(
                    limit: 100,
                    offset: 0,
                    includeAcknowledged: false
                )
                newReceipts = response.receipts
            } catch KeyPairError.keyNotFound {
                // Key not found - mark it but don't block showing local purchases
                isKeyNotFoundError = true
                newReceipts = []
            } catch {
                // Other server error - mark it but don't block showing local purchases
                errorMessage = error.userFacingMessage
                newReceipts = []
            }

            hasAnyPurchases = !newReceipts.isEmpty || !importedPurchases.isEmpty
            isLoading = false
        }
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
                // Clear error state and set local pending flag to trigger view update
                errorMessage = nil
                isKeyNotFoundError = false
                recoveryEmail = ""
                isPendingVerification = true  // Trigger view update to show pending verification UI
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
    var isReported: Bool = false
    var isReporting: Bool = false

    private var retailerDisplayName: String {
        if purchase.isParseFailed {
            return "Unable to parse"
        }
        if purchase.isPending {
            return "Processing..."
        }
        if let name = purchase.retailerName {
            return name
        }
        if let retailerId = purchase.retailerId {
            return retailerId.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "Unknown retailer"
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
                // Show warning icon for failed receipts
                if purchase.isParseFailed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignSystem.Colors.accentWarning)
                        .font(.headline)
                }

                Text(retailerDisplayName)
                    .font(.headline)
                    .foregroundColor(purchase.isParseFailed ? DesignSystem.Colors.textSecondary : .primary)

                Spacer()

                if purchase.isParseFailed {
                    if isReporting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if isReported {
                        Text("Reported")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.accentSuccess)
                            .cornerRadius(8)
                    } else {
                        Text("Failed")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.accentDanger)
                            .cornerRadius(8)
                    }
                } else if purchase.isPending {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if purchase.acknowledged {
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

            // Show helpful message for failed receipts
            if purchase.isParseFailed {
                if isReported {
                    Text("Thanks for reporting! We'll look into this and improve our parser.")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } else {
                    Text("This email couldn't be recognized. Swipe left to report this issue.")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
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

// MARK: - Error Detail View

private struct ErrorDetailView: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(DesignSystem.Colors.accentWarning)
                    Text("Connection Error")
                        .font(.title2.bold())
                }
                .padding(.bottom, 4)

                Text("There was a problem connecting to the server. Your imported purchases are still available below.")
                    .font(.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Divider()

                Text("Error Details")
                    .font(.headline)

                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Button {
                    onRetry()
                } label: {
                    Text("Retry Connection")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Error Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        PurchaseListView(showingHelp: .constant(false))
    }
}

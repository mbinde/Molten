//
//  PurchaseImportSettingsView.swift
//  Molten
//
//  Settings view for purchase email imports
//  Allows enabling/disabling purchase imports via email or plus-address
//

import SwiftUI

struct PurchaseImportSettingsView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(EntitlementService.self) private var entitlementService
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabling = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingDisableConfirmation = false
    @State private var showingUpgradePrompt = false
    @State private var showCopiedFeedback = false

    // Email registration state
    @State private var emailInput: String = ""
    @State private var showingEmailEntry = false
    @State private var emailSheetError: String?
    @State private var showingEmailSentAlert = false

    // Verification polling state
    @State private var isCheckingVerification = false
    @State private var verificationCheckTimer: Timer?
    @State private var isResendingVerification = false

    // Account recovery state
    @State private var showingRecoverySheet = false
    @State private var recoveryEmail: String = ""
    @State private var recoverySheetError: String?
    @State private var isRecovering = false
    @State private var showingRecoveryEmailSent = false

    // Observe the receipt service directly to get UI updates
    @ObservedObject private var receiptService: ReceiptService

    init() {
        // Initialize with the shared instance from dependencies
        // This will be set properly via the environment
        _receiptService = ObservedObject(wrappedValue: AppDependencies.shared.receiptService)
    }

    var body: some View {
        List {
            if receiptService.isSetUp {
                enabledSection
                actionsSection
            } else if receiptService.isPendingEmailVerification {
                pendingVerificationSection
            } else {
                setupOptionsSection
            }

            if let success = successMessage {
                successSection(success)
            }

            if let error = errorMessage {
                errorSection(error)
            }

            howItWorksSection
        }
        .navigationTitle("Purchase Import")
        .confirmationDialog(
            "Disable Purchase Imports?",
            isPresented: $showingDisableConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disable", role: .destructive) {
                receiptService.disableReceipts()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your import configuration. You'll need to set up purchase imports again if you want to use it in the future.")
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView(
                feature: "purchase import",
                currentCount: 0,
                limit: 0
            )
        }
        .sheet(isPresented: $showingEmailEntry) {
            emailEntrySheet
        }
        .sheet(isPresented: $showingRecoverySheet) {
            recoverySheet
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

    // MARK: - Enabled Section

    private let forwardingAddress = "receipts@moltenglass.app"

    @ViewBuilder
    private var enabledSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundColor(.green)
                    Text("Purchase Import Enabled")
                        .font(.headline)
                }

                if receiptService.identifierType == .email {
                    Text("Forward your glass purchase order confirmations from \(receiptService.receiptEmail ?? "your registered email") to the address below.")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } else {
                    Text("Forward your glass purchase order confirmations to the email address below.")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.vertical, 4)

            // Show forwarding address for all users
            if receiptService.identifierType == .plusAddress, let email = receiptService.receiptEmail {
                // Plus-address users: show their unique address
                copyableEmailRow(email: email)
            } else if receiptService.identifierType == .email {
                // Email users: show the forwarding address
                copyableEmailRow(email: forwardingAddress)
            }

            // Pending Count
            if receiptService.pendingReceiptCount > 0 {
                NavigationLink {
                    PurchaseListView(showingHelp: .constant(false))
                } label: {
                    HStack {
                        Text("Pending Orders")
                        Spacer()
                        Text("\(receiptService.pendingReceiptCount)")
                            .font(.body.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.moltenOrange)
                            .cornerRadius(12)
                    }
                }
            }

            // Last Sync Time
            if let lastSync = receiptService.lastSyncDate {
                HStack {
                    Text("Last Synced")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("ago")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        } header: {
            Text("Status")
        } footer: {
            if receiptService.identifierType == .plusAddress {
                Text("This email address is unique to you. Forward order confirmations from supported retailers and we'll parse them automatically.")
            } else {
                Text("Forward order confirmations from your registered email (\(receiptService.receiptEmail ?? "")) and we'll parse them automatically.")
            }
        }
    }

    // MARK: - Pending Verification Section

    @ViewBuilder
    private var pendingVerificationSection: some View {
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
                stopVerificationPolling()
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
        .onAppear {
            startVerificationPolling()
        }
        .onDisappear {
            stopVerificationPolling()
        }
    }

    // MARK: - Setup Options Section

    @ViewBuilder
    private var setupOptionsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "envelope.badge")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("Purchase Import")
                        .font(.headline)
                }

                Text("Automatically track your glass purchases by forwarding order confirmation emails. Choose how you'd like to identify yourself:")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, 4)
        }

        // Option 1: Register Email (Recommended)
        Section {
            Button {
                checkEntitlementAndShowEmailEntry()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "envelope")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Use My Email Address")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            Text("Recommended")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.accentSuccess)
                                .cornerRadius(4)
                        }

                        Text("Register your email. Forward orders from that address to receipts@moltenglass.app")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
        } footer: {
            Text("Your email is stored securely. If you get a new device or reset your phone, you can recover access via email verification.")
        }

        // Option 2: Get Plus Address (Anonymous)
        Section {
            Button {
                checkEntitlementAndEnableWithPlusAddress()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "key")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stay Anonymous")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)

                        Text("Get a unique forwarding address. Your email stays completely private.")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    if isEnabling {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isEnabling)
        } footer: {
            Text("We never store your email address. Note: If you get a new device, factory reset your phone, or disable iCloud Keychain sync, there is no way to recover your previously imported receipts.")
        }

        // Account Recovery Option
        Section {
            Button {
                showingRecoverySheet = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recover Existing Account")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)

                        Text("Already set up on another device? Recover access using your registered email.")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)
        } footer: {
            Text("Only works if you previously registered with an email address.")
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            Button {
                syncNow()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                    if isSyncing {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
            .disabled(isSyncing)

            NavigationLink {
                PurchaseListView(showingHelp: .constant(false))
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("View All Purchases")
                }
            }

            Button(role: .destructive) {
                showingDisableConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Disable Purchase Imports")
                }
            }

        } header: {
            Text("Actions")
        }
    }

    // MARK: - How It Works Section

    @ViewBuilder
    private var howItWorksSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "envelope.arrow.triangle.branch", text: "Forward order confirmation emails")
                InfoRow(icon: "doc.text.viewfinder", text: "We parse items, prices, and order details")
                InfoRow(icon: "checkmark.square", text: "Review and import items to your inventory")
                InfoRow(icon: "lock.shield", text: "Your data stays private and secure")
            }
        } header: {
            Text("How It Works")
        }
    }

    // MARK: - Success/Error Sections

    @ViewBuilder
    private func successSection(_ message: String) -> some View {
        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(message)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func errorSection(_ message: String) -> some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Email Entry Sheet

    @ViewBuilder
    private var emailEntrySheet: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Email address", text: $emailInput)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Enter Your Email")
                } footer: {
                    Text("We'll send a verification link to this address. Forward your order confirmations from this email to receipts@moltenglass.app after verification.")
                }

                if let error = emailSheetError {
                    Section {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                        }

                        // Show recovery button if email is already registered
                        if error.contains("already registered") {
                            Button {
                                // Immediately trigger recovery with the entered email
                                let emailToRecover = emailInput
                                showingEmailEntry = false
                                emailSheetError = nil
                                // Trigger recovery after sheet dismisses
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    recoveryEmail = emailToRecover
                                    triggerRecoveryDirectly()
                                }
                            } label: {
                                Label("Recover Existing Account", systemImage: "key.fill")
                            }
                        }
                    }
                }

                Section {
                    Button {
                        enableWithEmail()
                    } label: {
                        HStack {
                            Spacer()
                            if isEnabling {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Send Verification Email")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(isEnabling || !isValidEmail(emailInput) ? Color.gray.opacity(0.3) : DesignSystem.Colors.accentSuccess)
                        .foregroundColor(isEnabling || !isValidEmail(emailInput) ? .secondary : .white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(isEnabling || !isValidEmail(emailInput))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle("Register Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEmailEntry = false
                        emailInput = ""
                        emailSheetError = nil
                    }
                }
            }
            .alert("Verification Email Sent", isPresented: $showingEmailSentAlert) {
                Button("OK") {
                    showingEmailEntry = false
                    emailInput = ""
                    emailSheetError = nil
                }
            } message: {
                Text("Check your inbox in a few minutes and click the verification link to complete setup. If you don't see it, check your spam folder.")
            }
        }
    }

    // MARK: - Recovery Sheet

    @ViewBuilder
    private var recoverySheet: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Email address", text: $recoveryEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Enter Your Registered Email")
                } footer: {
                    Text("Enter the email address you used to set up purchase imports on your previous device. We'll send a recovery link to verify your identity.")
                }

                if let error = recoverySheetError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                Section {
                    RecoveryButton(
                        isRecovering: isRecovering,
                        isValidEmail: isValidEmail(recoveryEmail),
                        onTap: {
                            print("[Recovery] Button tapped! email=\(recoveryEmail)")
                            requestRecovery()
                        }
                    )
                    .onAppear {
                        print("[Recovery] Sheet appeared. email=\(recoveryEmail) isRecovering=\(isRecovering) isValid=\(isValidEmail(recoveryEmail))")
                    }
                }
            }
            .navigationTitle("Account Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingRecoverySheet = false
                        recoveryEmail = ""
                        recoverySheetError = nil
                    }
                }
            }
            .alert("Recovery Email Sent", isPresented: $showingRecoveryEmailSent) {
                Button("OK") {
                    showingRecoverySheet = false
                    recoveryEmail = ""
                    recoverySheetError = nil
                }
            } message: {
                Text("If this email is registered, you'll receive a recovery link. Click the link to restore access to your account.")
            }
        }
    }

    // MARK: - Private Methods

    private func checkEntitlementAndShowEmailEntry() {
        if entitlementService.canUseVersionedCloudBackups() {
            showingEmailEntry = true
        } else {
            showingUpgradePrompt = true
        }
    }

    private func checkEntitlementAndEnableWithPlusAddress() {
        if entitlementService.canUseVersionedCloudBackups() {
            enableWithPlusAddress()
        } else {
            showingUpgradePrompt = true
        }
    }

    private func enableWithPlusAddress() {
        isEnabling = true
        errorMessage = nil

        Task { @MainActor in
            do {
                _ = try await receiptService.enableReceiptsWithPlusAddress()
            } catch {
                errorMessage = error.localizedDescription
            }
            isEnabling = false
        }
    }

    private func enableWithEmail() {
        guard isValidEmail(emailInput) else { return }

        // Check if this is the same email we're already waiting on verification for
        if receiptService.isPendingEmailVerification,
           let pendingEmail = receiptService.receiptEmail,
           pendingEmail.lowercased() == emailInput.lowercased() {
            // Same email - just resend verification
            resendVerificationEmail()
            return
        }

        isEnabling = true
        emailSheetError = nil

        Task { @MainActor in
            do {
                try await receiptService.enableReceiptsWithEmail(emailInput)
                // Success - show the alert
                showingEmailSentAlert = true
            } catch let apiError as ReceiptAPIError {
                print("[EnableWithEmail] API error: \(apiError)")
                switch apiError {
                case .conflict:
                    // Email already registered to another account - guide to recovery
                    emailSheetError = "This email is already registered. Use 'Recover Existing Account' below to restore access on this device."
                case .unauthorized:
                    // This shouldn't happen during registration - show helpful message
                    emailSheetError = "Unable to authenticate. Please try again or use the anonymous option."
                default:
                    emailSheetError = apiError.localizedDescription
                }
            } catch {
                print("[EnableWithEmail] Other error: \(error)")
                emailSheetError = error.localizedDescription
            }
            isEnabling = false
        }
    }

    private func resendVerificationEmail() {
        isResendingVerification = true
        errorMessage = nil
        successMessage = nil

        Task { @MainActor in
            do {
                try await receiptService.resendVerificationEmail()
                successMessage = "Verification email sent! Check your inbox."
            } catch {
                print("[ResendVerification] error: \(error)")
                errorMessage = "Could not resend email: \(error.localizedDescription)"
            }
            isResendingVerification = false
        }
    }

    private func syncNow() {
        isSyncing = true
        errorMessage = nil
        successMessage = nil

        Task { @MainActor in
            do {
                let count = try await receiptService.syncReceipts()

                if count > 0 {
                    successMessage = "Found \(count) pending order\(count == 1 ? "" : "s")"
                } else {
                    successMessage = "No new orders"
                }

                // Clear success message after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation {
                        successMessage = nil
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isSyncing = false
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    private func requestRecovery() {
        guard isValidEmail(recoveryEmail) else {
            print("[Recovery] Invalid email: \(recoveryEmail)")
            return
        }

        print("[Recovery] Starting recovery for: \(recoveryEmail)")
        isRecovering = true
        recoverySheetError = nil

        Task { @MainActor in
            do {
                let message = try await receiptService.requestAccountRecovery(email: recoveryEmail)
                print("[Recovery] Success: \(message)")
                // Success - show the alert
                showingRecoveryEmailSent = true
            } catch let apiError as ReceiptAPIError {
                print("[Recovery] API error: \(apiError)")
                if case .badRequest(let message) = apiError {
                    recoverySheetError = message
                } else {
                    recoverySheetError = apiError.localizedDescription
                }
            } catch {
                print("[Recovery] Other error: \(error)")
                recoverySheetError = error.localizedDescription
            }
            isRecovering = false
        }
    }

    /// Trigger recovery directly without showing the recovery sheet
    /// Used when user clicks "Recover Existing Account" from the email registration error
    private func triggerRecoveryDirectly() {
        guard isValidEmail(recoveryEmail) else {
            errorMessage = "Invalid email address"
            return
        }

        isRecovering = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let message = try await receiptService.requestAccountRecovery(email: recoveryEmail)
                print("[Recovery] Direct recovery success: \(message)")
                // Show success message in the main view
                successMessage = "Recovery email sent! Check your inbox and click the link to restore access."
            } catch let apiError as ReceiptAPIError {
                print("[Recovery] Direct recovery API error: \(apiError)")
                if case .badRequest(let message) = apiError {
                    errorMessage = message
                } else if case .unauthorized = apiError {
                    // This means there's already a pending recovery - offer to resend
                    errorMessage = "A recovery is already in progress. Check your email for the recovery link, or try again in a few minutes."
                } else {
                    errorMessage = apiError.localizedDescription
                }
            } catch {
                print("[Recovery] Direct recovery error: \(error)")
                errorMessage = error.localizedDescription
            }
            isRecovering = false
        }
    }

    // MARK: - Verification Polling

    private func checkVerificationStatus() {
        isCheckingVerification = true

        Task { @MainActor in
            do {
                let verified = try await receiptService.checkEmailVerificationStatus()
                if verified {
                    stopVerificationPolling()
                    // Dismiss the settings view - PurchaseListView will show the setup instructions
                    dismiss()
                }
            } catch {
                errorMessage = "Could not check status: \(error.localizedDescription)"
            }
            isCheckingVerification = false
        }
    }

    private func startVerificationPolling() {
        stopVerificationPolling()

        verificationCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                do {
                    let verified = try await receiptService.checkEmailVerificationStatus()
                    if verified {
                        stopVerificationPolling()
                        // Dismiss the settings view - PurchaseListView will show the setup instructions
                        dismiss()
                    }
                } catch {
                    // Silently ignore polling errors
                }
            }
        }
    }

    private func stopVerificationPolling() {
        verificationCheckTimer?.invalidate()
        verificationCheckTimer = nil
    }

    // MARK: - Copyable Email Row

    @ViewBuilder
    private func copyableEmailRow(email: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forward orders to:")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Button {
                copyEmail(email)
            } label: {
                HStack {
                    Text(email)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func copyEmail(_ email: String) {
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

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Recovery Button

private struct RecoveryButton: View {
    let isRecovering: Bool
    let isValidEmail: Bool
    let onTap: () -> Void

    private var isDisabled: Bool {
        isRecovering || !isValidEmail
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Spacer()
                if isRecovering {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Send Recovery Email")
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .background(isDisabled ? Color.gray.opacity(0.3) : DesignSystem.Colors.accentSuccess)
            .foregroundColor(isDisabled ? DesignSystem.Colors.textSecondary : .white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

#Preview {
    NavigationStack {
        PurchaseImportSettingsView()
    }
}

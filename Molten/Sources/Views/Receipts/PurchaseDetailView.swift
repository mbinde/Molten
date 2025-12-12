//
//  PurchaseDetailView.swift
//  Molten
//
//  Detail view for a single purchase
//  Shows all parsed items and allows importing them to inventory
//

import SwiftUI

struct PurchaseDetailView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var purchase: ReceiptDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isKeyNotFoundError = false
    @State private var isMarking = false
    @State private var showingMarkConfirmation = false
    @State private var selectedItems: Set<Int> = []
    @State private var showingImportSheet = false
    @State private var isImported = false
    /// Tracks the user's selected match candidate for each item (item.id -> candidate.catalogStableId)
    @State private var selectedMatches: [Int: String] = [:]
    /// Tracks quantity overrides for each item (item.id -> quantity)
    @State private var itemQuantities: [Int: Int] = [:]
    /// Client-side catalog match results (item.id -> match result)
    @State private var clientMatchResults: [Int: ItemMatchResult] = [:]
    @State private var isMatching = false
    /// Existing purchase record if this receipt was already imported
    @State private var existingPurchaseRecord: PurchaseRecordModel?
    /// Mapping of receipt item index to imported purchase record item (for already-imported items)
    @State private var importedItemsMap: [Int: PurchaseRecordItemModel] = [:]
    /// Potential duplicate purchases (for warning the user)
    @State private var potentialDuplicates: [PotentialDuplicate] = []
    @State private var showDuplicateWarning = false
    @State private var duplicateWarningDismissed = false
    @State private var exactDuplicateDismissed = false
    @State private var showingEmailBody = false
    @State private var emailBody: String?
    @State private var isLoadingEmail = false
    // Recovery state
    @State private var recoveryEmail: String = ""
    @State private var recoveryError: String?
    @State private var isRecovering = false
    @State private var showingRecoveryEmailSent = false
    // Entitlement state
    @State private var hasProAccess = false
    @State private var showingPaywall = false

    let purchaseId: String

    private var receiptService: ReceiptService {
        dependencies.receiptService
    }

    private var catalogService: CatalogService {
        dependencies.catalogService
    }

    private var retailerDisplayName: String {
        guard let purchase = purchase else { return "" }
        return purchase.retailerName ?? purchase.retailerId.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var canImportReceipts: Bool {
        receiptService.canImportReceipts(hasProAccess: hasProAccess)
    }

    private var remainingFreeImports: Int? {
        receiptService.remainingFreeImports(hasProAccess: hasProAccess)
    }

    private var subscriptionService: SubscriptionServiceProtocol {
        dependencies.subscriptionService
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading order...")
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
                            .foregroundColor(DesignSystem.Colors.textPrimary)
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
                            .background(DesignSystem.Colors.backgroundInputLight)
                            .cornerRadius(12)
                            .padding(.top, 8)
                        } else {
                            Button {
                                loadPurchase()
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
            } else if let purchase = purchase {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Information
                        purchaseHeader(purchase)

                        // Exact duplicate banner (already imported)
                        if existingPurchaseRecord != nil && !exactDuplicateDismissed {
                            exactDuplicateBanner
                        }

                        // Potential duplicate warning (similar but not exact)
                        if existingPurchaseRecord == nil && !potentialDuplicates.isEmpty && !duplicateWarningDismissed {
                            duplicateWarningBanner
                        }

                        // Items Section
                        itemsSection(purchase)

                        // Actions
                        if !isImported {
                            actionsSection(purchase)
                        }
                    }
                    .padding()
                    .padding(.bottom, 40)  // Extra padding for tab bar
                }
            }
        }
        .navigationTitle("Order Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // Check Pro status for import limits
            hasProAccess = await subscriptionService.hasProAccess()
        }
        .onAppear {
            loadPurchase()
        }
        .confirmationDialog(
            "Mark as Imported?",
            isPresented: $showingMarkConfirmation,
            titleVisibility: .visible
        ) {
            Button("Mark as Imported") {
                markAsImported()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will mark the order as imported. You can still view it in your purchase history.")
        }
        .sheet(isPresented: $showingImportSheet) {
            if let purchase = purchase {
                PurchaseImportSheet(
                    purchase: purchase,
                    selectedItemIds: selectedItems,
                    selectedMatches: selectedMatches,
                    itemQuantities: itemQuantities,
                    clientMatchResults: clientMatchResults,
                    catalogService: catalogService,
                    receiptService: receiptService,
                    onImportComplete: {
                        isImported = true
                        dismiss()
                    }
                )
            }
        }
        .sheet(isPresented: $showingEmailBody) {
            EmailBodySheet(emailBody: emailBody ?? "", retailerName: retailerDisplayName)
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private func purchaseHeader(_ purchase: ReceiptDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(retailerDisplayName)
                        .font(.title2.bold())

                    if let orderNumber = purchase.orderNumber {
                        Text("Order #\(orderNumber)")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                if isImported {
                    Label("Imported", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(DesignSystem.Colors.accentSuccess)
                }
            }

            Divider()

            HStack {
                if let orderDate = purchase.orderDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Order Date")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(orderDate, style: .date)
                            .font(.subheadline)
                    }
                }

                Spacer()

                if let total = purchase.totalAmount {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(total, format: .currency(code: "USD"))
                            .font(.headline)
                    }
                }
            }

            if let subject = purchase.subject {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email Subject")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(subject)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
            }

            Button {
                loadEmailBody()
            } label: {
                HStack {
                    if isLoadingEmail {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "envelope.open")
                    }
                    Text("View Original Email")
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(DesignSystem.Colors.backgroundInputLight)
        .cornerRadius(12)
    }

    // MARK: - Duplicate Warning Banner

    @ViewBuilder
    private var duplicateWarningBanner: some View {
        if let topDuplicate = potentialDuplicates.first {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: topDuplicate.confidence == .high ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundColor(topDuplicate.confidence == .high ? DesignSystem.Colors.accentWarning : DesignSystem.Colors.moltenOrange)

                    Text(topDuplicate.confidence.displayName)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Button {
                        withAnimation {
                            duplicateWarningDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Text("This receipt may be related to an existing purchase:")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Show the top duplicate
                VStack(alignment: .leading, spacing: 4) {
                    Text(topDuplicate.existingRecord.supplier)
                        .font(.subheadline.bold())
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(topDuplicate.existingRecord.datePurchased, style: .date)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    ForEach(topDuplicate.reasons, id: \.self) { reason in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.accentSuccess)
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.background)
                .cornerRadius(8)

                // Show count of other duplicates if any
                if potentialDuplicates.count > 1 {
                    Text("\(potentialDuplicates.count - 1) other potential match\(potentialDuplicates.count > 2 ? "es" : "")")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                HStack {
                    Button {
                        withAnimation {
                            duplicateWarningDismissed = true
                        }
                    } label: {
                        Text("Import Anyway")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
            .padding()
            .background(topDuplicate.confidence == .high
                ? DesignSystem.Colors.accentWarning.opacity(0.1)
                : DesignSystem.Colors.moltenOrange.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Exact Duplicate Banner

    @ViewBuilder
    private var exactDuplicateBanner: some View {
        if let existing = existingPurchaseRecord {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accentSuccess)

                    Text("Already Imported")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Button {
                        withAnimation {
                            exactDuplicateDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Text("This receipt was already imported to your inventory:")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Show the existing record details
                VStack(alignment: .leading, spacing: 4) {
                    Text(existing.supplier)
                        .font(.subheadline.bold())
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(existing.datePurchased, style: .date)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    if !existing.items.isEmpty {
                        Text("\(existing.items.count) item\(existing.items.count == 1 ? "" : "s") imported")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.background)
                .cornerRadius(8)

                // Action buttons
                HStack(spacing: 12) {
                    // Dismiss as duplicate - marks as acknowledged and goes back
                    Button {
                        dismissAsDuplicate()
                    } label: {
                        HStack {
                            if isMarking {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .controlSize(.small)
                            }
                            Text("Dismiss as Duplicate")
                                .font(.subheadline)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignSystem.Colors.accentDanger)
                    .disabled(isMarking)

                    // Re-import option
                    Button {
                        withAnimation {
                            // Clear the existing record to allow re-import
                            existingPurchaseRecord = nil
                            importedItemsMap = [:]
                            exactDuplicateDismissed = true
                            // Re-select all items with catalog matches
                            if let purchase = purchase {
                                let selectableItemIds = selectableItems(purchase.items).map { $0.id }
                                selectedItems = Set(selectableItemIds)
                            }
                        }
                    } label: {
                        Text("Re-Import Anyway")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }

                Text("Dismiss removes this from your inbox. Re-import lets you add items again.")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding()
            .background(DesignSystem.Colors.accentSuccess.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Items Section

    /// Helper to check if a receipt item has a catalog match (uses client-side matching)
    private func hasCatalogMatch(_ item: ReceiptItem) -> Bool {
        // Check client-side match results first
        if let clientResult = clientMatchResults[item.id] {
            return !clientResult.candidates.isEmpty
        }
        // Fallback to server-provided data (for backwards compatibility during transition)
        return item.matchCandidates?.isEmpty == false || item.catalogStableId != nil
    }

    /// Get match candidates for an item (uses client-side matching)
    private func matchCandidates(for item: ReceiptItem) -> [MatchCandidate] {
        // Prefer client-side match results
        if let clientResult = clientMatchResults[item.id] {
            return clientResult.candidates
        }
        // Fallback to server-provided data
        return item.matchCandidates ?? []
    }

    /// Items that have catalog matches and can be selected for import
    private func selectableItems(_ items: [ReceiptItem]) -> [ReceiptItem] {
        items.filter { hasCatalogMatch($0) }
    }

    @ViewBuilder
    private func itemsSection(_ purchase: ReceiptDetail) -> some View {
        let selectable = selectableItems(purchase.items)
        let allSelectableIds = Set(selectable.map { $0.id })
        let allSelected = !allSelectableIds.isEmpty && selectedItems == allSelectableIds

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items (\(purchase.items.count))")
                    .font(.headline)

                Spacer()

                if !isImported && !selectable.isEmpty {
                    Button {
                        if allSelected {
                            selectedItems.removeAll()
                        } else {
                            selectedItems = allSelectableIds
                        }
                    } label: {
                        Text(allSelected ? "Select None" : "Select All")
                            .font(.caption)
                    }
                }
            }

            if purchase.items.isEmpty {
                ContentUnavailableView {
                    Label("No Items", systemImage: "cube.box")
                } description: {
                    Text("This order has no parsed items")
                }
                .frame(height: 150)
            } else {
                ForEach(purchase.items) { item in
                    PurchaseItemRow(
                        item: item,
                        clientMatchCandidates: matchCandidates(for: item),
                        isSelected: selectedItems.contains(item.id),
                        isSelectable: !isImported && !importedItemsMap.keys.contains(item.id),
                        importedItem: importedItemsMap[item.id],
                        catalogService: catalogService,
                        selectedCandidateId: selectedMatches[item.id],
                        quantityOverride: itemQuantities[item.id],
                        onToggle: {
                            if selectedItems.contains(item.id) {
                                selectedItems.remove(item.id)
                            } else {
                                selectedItems.insert(item.id)
                            }
                        },
                        onSelectCandidate: { candidateId in
                            selectedMatches[item.id] = candidateId
                        },
                        onQuantityChange: { newQuantity in
                            itemQuantities[item.id] = newQuantity
                        }
                    )
                }
            }
        }
    }

    // MARK: - Actions Section

    @ViewBuilder
    private func actionsSection(_ purchase: ReceiptDetail) -> some View {
        VStack(spacing: 12) {
            if !selectedItems.isEmpty {
                Button {
                    showingImportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import \(selectedItems.count) Item\(selectedItems.count == 1 ? "" : "s") to Inventory")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                showingMarkConfirmation = true
            } label: {
                HStack {
                    if isMarking {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "checkmark.circle")
                        Text("Mark as Imported")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isMarking)
        }
        .padding(.top)
    }

    // MARK: - Actions

    private func loadPurchase() {
        isLoading = true
        errorMessage = nil
        isKeyNotFoundError = false

        Task { @MainActor in
            do {
                let loaded = try await receiptService.getReceipt(receiptId: purchaseId)
                purchase = loaded
                isImported = loaded.acknowledged

                // Check if this receipt was already imported to local inventory
                await checkForExistingImport(loaded)

                // Check for potential duplicate purchases (even if not exact match)
                await checkForPotentialDuplicates(loaded)

                // Run client-side catalog matching only for items not already imported
                await matchItemsWithCatalog(loaded)

                // Select only items with catalog matches that haven't been imported yet
                if !loaded.acknowledged {
                    let unimportedSelectableItems = selectableItems(loaded.items).filter { !importedItemsMap.keys.contains($0.id) }
                    selectedItems = Set(unimportedSelectableItems.map { $0.id })
                }
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

    /// Check if this receipt has already been imported to local inventory
    private func checkForExistingImport(_ receipt: ReceiptDetail) async {
        let importService = ReceiptImportService(
            purchaseRecordRepository: dependencies.purchaseRecordRepository,
            storageLocationRepository: dependencies.storageLocationRepository,
            inventoryRepository: dependencies.inventoryRepository,
            consumptionRepository: dependencies.inventoryConsumptionRecordRepository
        )

        do {
            let existing = try await importService.findExistingPurchaseRecord(
                emailReceiptId: receipt.id,
                orderNumber: receipt.orderNumber,
                supplier: receipt.retailerName ?? receipt.retailerId,
                senderEmail: receipt.senderEmail,
                orderDate: receipt.orderDate ?? Date(),
                total: receipt.totalAmount.map { Decimal($0) }
            )

            if let existing = existing {
                existingPurchaseRecord = existing

                // Build mapping from receipt items to imported items by matching line hash
                // This is stable across re-imports since it's based on the receipt line content
                let importedItemsByHash = Dictionary(
                    existing.items.compactMap { item -> (String, PurchaseRecordItemModel)? in
                        guard let hash = item.receiptLineHash else { return nil }
                        return (hash, item)
                    },
                    uniquingKeysWith: { first, _ in first }
                )

                var mapping: [Int: PurchaseRecordItemModel] = [:]
                for receiptItem in receipt.items {
                    if let importedItem = importedItemsByHash[receiptItem.lineHash] {
                        mapping[receiptItem.id] = importedItem
                    }
                }
                importedItemsMap = mapping
            }
        } catch {
            // If we can't check, just proceed without the existing record info
            print("Could not check for existing import: \(error)")
        }
    }

    /// Check for potential duplicate purchases (not exact matches, but similar)
    private func checkForPotentialDuplicates(_ receipt: ReceiptDetail) async {
        let importService = ReceiptImportService(
            purchaseRecordRepository: dependencies.purchaseRecordRepository,
            storageLocationRepository: dependencies.storageLocationRepository,
            inventoryRepository: dependencies.inventoryRepository,
            consumptionRepository: dependencies.inventoryConsumptionRecordRepository
        )

        do {
            let duplicates = try await importService.findPotentialDuplicates(
                orderNumber: receipt.orderNumber,
                supplier: receipt.retailerName ?? receipt.retailerId,
                receiptItems: receipt.items,
                excludingRecordId: existingPurchaseRecord?.id
            )

            if !duplicates.isEmpty {
                potentialDuplicates = duplicates
                // Auto-show warning for high confidence duplicates
                if duplicates.contains(where: { $0.confidence == .high }) {
                    showDuplicateWarning = true
                }
            }
        } catch {
            print("Could not check for potential duplicates: \(error)")
        }
    }

    /// Matches receipt items against the local catalog
    private func matchItemsWithCatalog(_ receipt: ReceiptDetail) async {
        isMatching = true
        let matcher = ReceiptCatalogMatcher(catalogService: catalogService)

        // Only match items that haven't already been imported
        let itemsToMatch = receipt.items.filter { !importedItemsMap.keys.contains($0.id) }
        let results = await matcher.matchItems(itemsToMatch, retailerId: receipt.retailerId)
        clientMatchResults = results
        isMatching = false
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

    private func markAsImported() {
        isMarking = true

        Task { @MainActor in
            do {
                try await receiptService.acknowledgeReceipt(receiptId: purchaseId)
                isImported = true
            } catch {
                errorMessage = error.userFacingMessage
            }
            isMarking = false
        }
    }

    /// Dismiss this receipt as a duplicate - deletes from server and navigates back
    private func dismissAsDuplicate() {
        isMarking = true

        Task { @MainActor in
            do {
                try await receiptService.deleteReceipt(receiptId: purchaseId)
                dismiss()  // Go back to the list
            } catch {
                errorMessage = error.userFacingMessage
            }
            isMarking = false
        }
    }

    private func loadEmailBody() {
        isLoadingEmail = true

        Task { @MainActor in
            do {
                emailBody = try await receiptService.getReceiptEmail(receiptId: purchaseId)
                showingEmailBody = true
            } catch {
                errorMessage = "Could not load email: \(error.userFacingMessage)"
            }
            isLoadingEmail = false
        }
    }
}

// MARK: - Purchase Item Row

private struct PurchaseItemRow: View {
    let item: ReceiptItem
    /// Client-side match candidates (from ReceiptCatalogMatcher)
    let clientMatchCandidates: [MatchCandidate]
    let isSelected: Bool
    let isSelectable: Bool
    /// If this item was already imported, contains the imported item details
    let importedItem: PurchaseRecordItemModel?
    let catalogService: CatalogService
    /// The currently selected candidate's stable ID (nil = use original order)
    let selectedCandidateId: String?
    /// User's explicit quantity override (nil = use rod estimate or item quantity)
    let quantityOverride: Int?
    let onToggle: () -> Void
    let onSelectCandidate: (String) -> Void
    let onQuantityChange: (Int) -> Void

    @State private var catalogItem: GlassItemModel?
    @State private var importedCatalogItem: GlassItemModel?  // For showing imported item details
    @State private var isLoadingCatalog = false
    @State private var showingCandidates = false
    @State private var justSwapped = false
    @State private var rodEstimate: RodEstimate?

    /// Whether this item was already imported
    private var isAlreadyImported: Bool {
        importedItem != nil
    }

    /// Whether this item has a catalog match (uses client-side matching)
    private var hasCatalogMatch: Bool {
        !clientMatchCandidates.isEmpty || isAlreadyImported
    }

    /// Reorders candidates so the selected one is first
    private var orderedCandidates: [MatchCandidate] {
        guard !clientMatchCandidates.isEmpty else { return [] }
        let candidates = clientMatchCandidates
        guard let selectedId = selectedCandidateId else { return candidates }

        // Find the selected candidate and move it to the front
        if let selectedIndex = candidates.firstIndex(where: { $0.catalogStableId == selectedId }) {
            var reordered = candidates
            let selected = reordered.remove(at: selectedIndex)
            reordered.insert(selected, at: 0)
            return reordered
        }
        return candidates
    }

    private var topCandidate: MatchCandidate? {
        orderedCandidates.first
    }

    private var otherCandidates: [MatchCandidate] {
        Array(orderedCandidates.dropFirst())
    }

    private var matchConfidenceColor: Color {
        guard let confidence = item.matchConfidence else { return .secondary }
        if confidence >= 0.9 { return .green }
        if confidence >= 0.7 { return .orange }
        return .red
    }

    private var matchMethodDisplay: String {
        guard let method = item.matchMethod else { return "" }
        switch method {
        case "sku_exact": return "SKU Match"
        case "sku_partial": return "Partial SKU"
        case "name_exact": return "Name Match"
        case "name_fuzzy": return "Fuzzy Match"
        case "component_match": return "Best Guess"
        default: return method
        }
    }

    private var hasOtherCandidates: Bool {
        otherCandidates.count > 0
    }

    private var otherCandidatesCount: Int {
        otherCandidates.count
    }

    /// The display quantity - user override takes precedence, then rod estimate, then raw item quantity
    private var displayQuantity: Int {
        // User's explicit override always wins
        if let override = quantityOverride {
            return override
        }
        // Otherwise use rod estimate if available
        if let estimate = rodEstimate {
            return estimate.rodCount
        }
        // Fall back to item's raw quantity
        return Int(item.quantity ?? 1)
    }

    /// The unit name for display - "Rod" or "Rods" for rod estimates, otherwise the catalog type
    /// For frit, shows "Jar of Frit" or "Jar of #38 Frit" if subtype is known
    private var unitDisplayName: String {
        if rodEstimate != nil {
            return displayQuantity == 1 ? "Rod" : "Rods"
        }
        guard let candidate = topCandidate else { return "item" }

        // Special handling for frit - show as "Jar of Frit" or "Jar of #38 Frit"
        if candidate.catalogType.lowercased() == "frit" {
            if let subtype = candidate.catalogSubtype {
                return displayQuantity == 1 ? "Jar of \(subtype) Frit" : "Jars of \(subtype) Frit"
            }
            return displayQuantity == 1 ? "Jar of Frit" : "Jars of Frit"
        }

        // Use the GlassItemTypeSystem to get proper display name
        if let type = GlassItemTypeSystem.getType(named: candidate.catalogType) {
            // displayName is plural (e.g., "Rods", "Frit"), we want singular for quantity 1
            let plural = type.displayName
            // Handle special cases where singular == plural
            if plural == "Frit" || plural == "Powder" || plural == "Scrap" {
                return plural
            }
            // Remove trailing 's' for simple plurals when quantity is 1
            if displayQuantity == 1 && plural.hasSuffix("s") {
                return String(plural.dropLast())
            }
            return plural
        }
        return candidate.catalogType.capitalized
    }

    /// Unit price - calculated from total / display quantity
    private var displayUnitPrice: Double? {
        guard let total = item.totalPrice, displayQuantity > 0 else { return nil }
        return total / Double(displayQuantity)
    }

    /// Row background color - different for already-imported vs selected vs default
    private var rowBackgroundColor: Color {
        if isAlreadyImported {
            // Grayed out for already-imported items
            return DesignSystem.Colors.backgroundSecondary.opacity(0.5)
        } else if isSelected {
            // Orange highlight for selected items
            return DesignSystem.Colors.moltenOrange.opacity(0.1)
        } else {
            // Default background
            return DesignSystem.Colors.backgroundInputLight
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main item row
            Button {
                if isSelectable && hasCatalogMatch && !isAlreadyImported {
                    onToggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    if isAlreadyImported {
                        // Show "already imported" seal - distinct from selection checkmark
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.title3)
                    } else if isSelectable {
                        if hasCatalogMatch {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .accentColor : .secondary)
                                .font(.title3)
                        } else {
                            // Show disabled state for items without catalog match
                            Image(systemName: "xmark.circle")
                                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))
                                .font(.title3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // Item name
                        Text(item.rawName)
                            .font(.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.leading)

                        // SKU if available
                        if let sku = item.rawSku {
                            Text("SKU: \(sku)")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        // Already imported - show what it was imported as
                        if let imported = importedItem {
                            AlreadyImportedCard(
                                importedItem: imported,
                                catalogItem: importedCatalogItem
                            )
                        } else if topCandidate != nil {
                            // Quantity and unit price row (editable) - only for items not yet imported
                            HStack(spacing: 4) {
                                // Editable quantity field
                                TextField("", value: Binding(
                                    get: { displayQuantity },
                                    set: { newValue in
                                        if newValue > 0 {
                                            onQuantityChange(newValue)
                                        }
                                    }
                                ), format: .number)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)

                                Text(unitDisplayName)
                                    .font(.subheadline)

                                if let price = displayUnitPrice {
                                    Text("·")
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    Text(price, format: .currency(code: "USD"))
                                        .font(.subheadline)
                                    Text("ea")
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                            .padding(.top, 4)

                            // Catalog match info - show as card if we have a match or candidates
                            if let candidate = topCandidate {
                                // Show top match as a nice card with pulse effect on swap
                                TopMatchCard(candidate: candidate)
                                    .scaleEffect(justSwapped ? 1.03 : 1.0)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.accentColor, lineWidth: justSwapped ? 2 : 0)
                                            .opacity(justSwapped ? 1 : 0)
                                    )
                                    .animation(.easeInOut(duration: 0.2), value: justSwapped)
                            }
                        } else {
                            // No catalog match - cannot be imported
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text("No catalog match – cannot import")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }

                    Spacer()

                    // Total price
                    if let total = item.totalPrice {
                        Text(total, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Show other candidates toggle if available
            if hasOtherCandidates {
                Button {
                    withAnimation {
                        showingCandidates.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: showingCandidates ? "chevron.up" : "chevron.down")
                            .font(.caption)
                        Text(showingCandidates ? "Hide other suggestions" : "Show \(otherCandidatesCount) other suggestion\(otherCandidatesCount == 1 ? "" : "s")")
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundColor(DesignSystem.Colors.moltenOrange)
                    .padding(.horizontal)
                    .padding(.bottom, showingCandidates ? 4 : 12)
                }
                .buttonStyle(.plain)

                // Other candidates list (the ones not currently selected as top)
                if showingCandidates {
                    VStack(spacing: 8) {
                        ForEach(otherCandidates) { candidate in
                            CandidateRow(candidate: candidate) {
                                // Collapse the list, update selection, trigger pulse
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showingCandidates = false
                                    onSelectCandidate(candidate.catalogStableId)
                                    justSwapped = true
                                }
                                // Reset pulse after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        justSwapped = false
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(rowBackgroundColor)
        .cornerRadius(8)
        .task {
            await loadCatalogItem()
        }
        .onChange(of: selectedCandidateId) { _, newValue in
            // Recalculate estimate when user selects a different candidate
            Task {
                await loadCatalogItemForCandidate(newValue)
            }
        }
    }

    private func loadCatalogItem() async {
        isLoadingCatalog = true

        // If already imported, load the catalog item it was imported as
        if let imported = importedItem {
            importedCatalogItem = try? await catalogService.fetchGlassItem(byStableId: imported.item_stable_id)
            isLoadingCatalog = false
            return
        }

        // Use the selected candidate if available, otherwise use the top client match candidate
        let stableId = selectedCandidateId
            ?? clientMatchCandidates.first?.catalogStableId

        guard let stableId = stableId else {
            isLoadingCatalog = false
            return
        }
        catalogItem = try? await catalogService.fetchGlassItem(byStableId: stableId)
        calculateRodEstimate()

        // If we couldn't estimate rods but have a raw quantity, propagate that
        if quantityOverride == nil && rodEstimate == nil {
            let rawQty = Int(item.quantity ?? 1)
            if rawQty > 0 {
                onQuantityChange(rawQty)
            }
        }

        isLoadingCatalog = false
    }

    private func loadCatalogItemForCandidate(_ candidateId: String?) async {
        guard let candidateId = candidateId else { return }
        isLoadingCatalog = true
        catalogItem = try? await catalogService.fetchGlassItem(byStableId: candidateId)
        calculateRodEstimate()
        isLoadingCatalog = false
    }

    private func calculateRodEstimate() {
        guard let catalogItem = catalogItem else {
            rodEstimate = nil
            return
        }

        rodEstimate = RodEstimator.estimate(
            item: item,
            catalogCOE: catalogItem.coe,
            catalogManufacturer: catalogItem.manufacturer
        )

        // Propagate the calculated quantity to the parent if user hasn't overridden it
        // This ensures the import sheet gets the estimated value even if user didn't edit the field
        if quantityOverride == nil, let estimate = rodEstimate {
            onQuantityChange(estimate.rodCount)
        }
    }
}

// MARK: - Top Match Card (shown inline with item)

private struct TopMatchCard: View {
    let candidate: MatchCandidate

    private var confidenceColor: Color {
        if candidate.confidence >= 0.9 { return .green }
        if candidate.confidence >= 0.7 { return .yellow }
        if candidate.confidence >= 0.5 { return .orange }
        return .red
    }

    /// Full manufacturer name from abbreviation
    private var manufacturerName: String {
        GlassManufacturers.manufacturers[candidate.catalogManufacturer.uppercased()]
            ?? candidate.catalogManufacturer
    }

    /// Type display with optional subtype (e.g., "Frit (#38)")
    private var typeDisplay: String {
        let baseType = candidate.catalogType.capitalized
        if let subtype = candidate.catalogSubtype {
            return "\(baseType) (\(subtype))"
        }
        return baseType
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.catalogName)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: 4) {
                    Text(manufacturerName)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(4)

                    Text(typeDisplay)
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            // Confidence badge
            Text("\(Int(candidate.confidence * 100))%")
                .font(.caption.bold())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor)
                .cornerRadius(12)
        }
        .padding(8)
        .background(DesignSystem.Colors.background)
        .cornerRadius(6)
    }
}

// MARK: - Already Imported Card (shown when item was previously imported)

private struct AlreadyImportedCard: View {
    let importedItem: PurchaseRecordItemModel
    let catalogItem: GlassItemModel?

    /// Full manufacturer name from abbreviation
    private var manufacturerName: String {
        guard let item = catalogItem else { return "" }
        return GlassManufacturers.manufacturers[item.manufacturer.uppercased()]
            ?? item.manufacturer
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let item = catalogItem {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    HStack(spacing: 4) {
                        Text(manufacturerName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DesignSystem.Colors.backgroundSecondary)
                            .cornerRadius(4)

                        Text(importedItem.type.capitalized)
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("·")
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("\(Int(importedItem.quantity)) imported")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                } else {
                    Text(importedItem.item_stable_id)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(Int(importedItem.quantity)) \(importedItem.type) imported")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            // "Already imported" badge - gray to avoid confusion with selection
            Text("Imported")
                .font(.caption.bold())
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DesignSystem.Colors.backgroundSecondary)
                .cornerRadius(12)
        }
        .padding(8)
        .background(DesignSystem.Colors.backgroundSecondary.opacity(0.3))
        .cornerRadius(6)
    }
}

// MARK: - Candidate Row (for dropdown list, tappable to select)

private struct CandidateRow: View {
    let candidate: MatchCandidate
    let onSelect: () -> Void

    private var confidenceColor: Color {
        if candidate.confidence >= 0.9 { return .green }
        if candidate.confidence >= 0.7 { return .yellow }
        if candidate.confidence >= 0.5 { return .orange }
        return .red
    }

    /// Full manufacturer name from abbreviation
    private var manufacturerName: String {
        GlassManufacturers.manufacturers[candidate.catalogManufacturer.uppercased()]
            ?? candidate.catalogManufacturer
    }

    /// Type display with optional subtype (e.g., "Frit (#38)")
    private var typeDisplay: String {
        let baseType = candidate.catalogType.capitalized
        if let subtype = candidate.catalogSubtype {
            return "\(baseType) (\(subtype))"
        }
        return baseType
    }

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.catalogName)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    HStack(spacing: 4) {
                        Text(manufacturerName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DesignSystem.Colors.backgroundSecondary)
                            .cornerRadius(4)

                        Text(typeDisplay)
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                // Confidence badge
                Text("\(Int(candidate.confidence * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidenceColor)
                    .cornerRadius(12)

                // Indicate it's selectable
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(DesignSystem.Colors.moltenOrange)
                    .font(.caption)
            }
            .padding(8)
            .background(DesignSystem.Colors.background)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Purchase Import Sheet

/// How to record frit quantity - by jar count or by weight
enum FritQuantityMode: String, CaseIterable {
    case jars = "jars"
    case weight = "weight"

    var displayName: String {
        switch self {
        case .jars: return "Jars"
        case .weight: return "Weight"
        }
    }
}

/// Model for an item being imported with its editable quantity
private struct ReceiptImportItem: Identifiable {
    let id: Int
    let receiptItem: ReceiptItem
    let catalogStableId: String?
    let catalogType: String?  // Type from match candidate (e.g., "rod", "frit")
    var catalogItem: GlassItemModel?
    var quantity: String  // String for text field binding (jars or rods count)
    var rodEstimate: RodEstimate?  // Full estimate with rod count and price per rod
    var cannotEstimateReason: String?  // Reason why we couldn't estimate

    // Frit-specific fields for weight vs jars choice
    var fritQuantityMode: FritQuantityMode = .jars
    var fritWeightValue: String = ""  // e.g., "4" for 4 oz
    var fritWeightUnit: String = ""   // e.g., "oz", "lb"
    var hasFritWeightOption: Bool = false  // True if receipt has weight info for frit

    var quantityInt: Int? {
        Int(quantity)
    }

    var quantityDouble: Double? {
        Double(quantity)
    }

    var isValid: Bool {
        // For frit in weight mode, validate the weight value
        if hasFritWeightOption && fritQuantityMode == .weight {
            if let weight = Double(fritWeightValue), weight > 0 {
                return true
            }
            return false
        }
        // For everything else, validate integer quantity
        if let qty = quantityInt {
            return qty > 0
        }
        return false
    }

    /// Calculate the price per unit based on current quantity
    var pricePerUnit: Double? {
        guard let total = receiptItem.totalPrice else { return nil }

        if hasFritWeightOption && fritQuantityMode == .weight {
            guard let weight = Double(fritWeightValue), weight > 0 else { return nil }
            return total / weight
        }

        guard let qty = quantityInt, qty > 0 else { return nil }
        return total / Double(qty)
    }

    /// The unit label for display (e.g., "ea", "oz", "lb")
    var unitLabel: String {
        if hasFritWeightOption && fritQuantityMode == .weight {
            return fritWeightUnit.isEmpty ? "oz" : fritWeightUnit
        }
        return "ea"
    }
}

private struct PurchaseImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies

    let purchase: ReceiptDetail
    let selectedItemIds: Set<Int>
    let selectedMatches: [Int: String]  // item.id -> catalogStableId
    let itemQuantities: [Int: Int]  // item.id -> user-specified quantity from previous screen
    let clientMatchResults: [Int: ItemMatchResult]  // item.id -> client-side match result
    let catalogService: CatalogService
    let receiptService: ReceiptService
    let onImportComplete: () -> Void

    @State private var importItems: [ReceiptImportItem] = []
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importMode: ReceiptImportMode = .addNew
    @State private var importProgress: String = ""
    @State private var hasProAccess = false
    @State private var showingPaywall = false

    private var subscriptionService: SubscriptionServiceProtocol {
        dependencies.subscriptionService
    }

    private var canImportReceipts: Bool {
        receiptService.canImportReceipts(hasProAccess: hasProAccess)
    }

    private var remainingFreeImports: Int? {
        receiptService.remainingFreeImports(hasProAccess: hasProAccess)
    }

    private var selectedItems: [ReceiptItem] {
        purchase.items.filter { selectedItemIds.contains($0.id) }
    }

    private var allItemsValid: Bool {
        importItems.allSatisfy { $0.isValid && $0.catalogItem != nil }
    }

    private var invalidItemCount: Int {
        importItems.filter { !$0.isValid || $0.catalogItem == nil }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading catalog info...")
                } else {
                    List {
                        // Import mode picker
                        Section {
                            Picker("Import Mode", selection: $importMode) {
                                Text("Add as new inventory").tag(ReceiptImportMode.addNew)
                                Text("Match to existing inventory").tag(ReceiptImportMode.matchExisting)
                            }
                            .pickerStyle(.segmented)
                        } header: {
                            Text("How to Import")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        } footer: {
                            Text(importMode == .addNew
                                ? "Creates new inventory entries for each item."
                                : "Tries to find and link to existing inventory you already added.")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        // Items section
                        Section {
                            ForEach($importItems) { $item in
                                ReceiptImportItemRow(item: $item)
                            }
                        } header: {
                            Text("Items to Import")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        } footer: {
                            if invalidItemCount > 0 {
                                Label(
                                    "\(invalidItemCount) item\(invalidItemCount == 1 ? " needs" : "s need") a quantity and catalog match before importing",
                                    systemImage: "exclamationmark.triangle"
                                )
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DesignSystem.Colors.accentWarning.opacity(0.3))
                                .cornerRadius(4)
                            }
                        }

                        // Import limit warning (for free users)
                        if !canImportReceipts {
                            Section {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Import Limit Reached", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundColor(DesignSystem.Colors.accentWarning)
                                        .font(.headline)
                                    Text("You've imported \(ReceiptService.freeImportLimit) receipts on the free tier. Upgrade to Pro for unlimited receipt imports.")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    Button {
                                        Task {
                                            try? await subscriptionService.presentPaywall()
                                            // Refresh Pro status after paywall
                                            hasProAccess = await subscriptionService.hasProAccess()
                                        }
                                    } label: {
                                        Text("Upgrade to Pro")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        } else if let remaining = remainingFreeImports, remaining <= 3 {
                            Section {
                                Label("\(remaining) free import\(remaining == 1 ? "" : "s") remaining", systemImage: "info.circle")
                                    .foregroundColor(DesignSystem.Colors.accentWarning)
                                    .font(.subheadline)
                            }
                        }

                        // Import button section
                        Section {
                            Button {
                                performImport()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isImporting {
                                        VStack(spacing: 4) {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                            if !importProgress.isEmpty {
                                                Text(importProgress)
                                                    .font(.caption)
                                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                            }
                                        }
                                    } else {
                                        Label("Import to Inventory", systemImage: "square.and.arrow.down")
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(!allItemsValid || isImporting || !canImportReceipts)
                        }

                        if let error = errorMessage {
                            Section {
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .foregroundColor(DesignSystem.Colors.accentDanger)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
            .task {
                // Check Pro status for import limits
                hasProAccess = await subscriptionService.hasProAccess()
                await loadCatalogInfo()
            }
        }
    }

    // MARK: - Data Loading

    private func loadCatalogInfo() async {
        var items: [ReceiptImportItem] = []

        for receiptItem in selectedItems {
            // Get client-side match candidates for this item
            let clientCandidates = clientMatchResults[receiptItem.id]?.candidates ?? []

            // Determine which catalog item to use (user override or default from client matching)
            let selectedCandidateId = selectedMatches[receiptItem.id]
            let matchCandidate = clientCandidates.first(where: { $0.catalogStableId == selectedCandidateId })
                ?? clientCandidates.first

            let catalogStableId = matchCandidate?.catalogStableId
            let catalogType = matchCandidate?.catalogType

            var importItem = ReceiptImportItem(
                id: receiptItem.id,
                receiptItem: receiptItem,
                catalogStableId: catalogStableId,
                catalogType: catalogType,
                quantity: "",
                rodEstimate: nil,
                cannotEstimateReason: nil
            )

            // Load catalog item if we have a stable ID
            if let stableId = catalogStableId {
                importItem.catalogItem = try? await catalogService.fetchGlassItem(byStableId: stableId)
            }

            // Determine quantity based on product type
            // FIRST: Check if user already specified a quantity on the previous screen
            if let userQuantity = itemQuantities[receiptItem.id], userQuantity > 0 {
                importItem.quantity = String(userQuantity)
                // Still calculate estimate for display purposes
                if let catalogItem = importItem.catalogItem {
                    let estimate = RodEstimator.estimate(
                        item: receiptItem,
                        catalogCOE: catalogItem.coe,
                        catalogManufacturer: catalogItem.manufacturer
                    )
                    importItem.rodEstimate = estimate
                }
            } else if let catalogItem = importItem.catalogItem {
                // For frit and powder, check if receipt has weight info
                let fritTypes = ["frit", "powder"]
                if let type = catalogType?.lowercased(), fritTypes.contains(type) {
                    // Check if the receipt has weight-based quantity (e.g., "4 oz")
                    if let unit = receiptItem.quantityUnit,
                       let parsedUnit = ReceiptWeightUnit.parse(unit),
                       parsedUnit.isWeightBased,
                       let qty = receiptItem.quantity {
                        // Receipt has weight info - offer jars vs weight choice
                        importItem.hasFritWeightOption = true
                        importItem.fritWeightValue = String(format: "%.2g", qty)
                        importItem.fritWeightUnit = parsedUnit.rawValue.lowercased()
                        // Default to jars mode, user can switch to weight
                        importItem.fritQuantityMode = .jars
                        // For jars mode, default to 1 jar (user must specify)
                        importItem.quantity = "1"
                        importItem.cannotEstimateReason = "Receipt shows weight - select jars or weight"
                    } else {
                        // No weight info - use receipt quantity as jar count
                        let qty = Int(receiptItem.quantity ?? 1)
                        importItem.quantity = String(max(qty, 1))
                    }
                } else if let type = catalogType?.lowercased(), ["sheet", "billet", "bar"].contains(type) {
                    // Other count-based types - use receipt quantity directly
                    let qty = Int(receiptItem.quantity ?? 1)
                    importItem.quantity = String(max(qty, 1))
                } else {
                    // For rods/stringers, try to estimate from weight
                    let estimate = RodEstimator.estimate(
                        item: receiptItem,
                        catalogCOE: catalogItem.coe,
                        catalogManufacturer: catalogItem.manufacturer
                    )

                    if let estimate = estimate {
                        importItem.rodEstimate = estimate
                        importItem.quantity = String(estimate.rodCount)
                    } else {
                        // Couldn't estimate - figure out why
                        if receiptItem.quantityUnit == nil {
                            importItem.cannotEstimateReason = "No unit info from receipt"
                        } else if ReceiptWeightUnit.parse(receiptItem.quantityUnit)?.isWeightBased == false {
                            // Sold by count - use receipt quantity
                            let qty = Int(receiptItem.quantity ?? 1)
                            importItem.quantity = String(max(qty, 1))
                        } else if RodEstimator.dimensions(forCOE: catalogItem.coe) == nil {
                            importItem.cannotEstimateReason = "Unknown COE (\(catalogItem.coe))"
                        } else {
                            importItem.cannotEstimateReason = "Could not calculate"
                        }
                    }
                }
            } else {
                importItem.cannotEstimateReason = "No catalog match"
            }

            items.append(importItem)
        }

        importItems = items
        isLoading = false
    }

    // MARK: - Import

    private func performImport() {
        isImporting = true
        errorMessage = nil
        importProgress = "Preparing..."

        Task { @MainActor in
            do {
                let importService = ReceiptImportService(
                    purchaseRecordRepository: dependencies.purchaseRecordRepository,
                    storageLocationRepository: dependencies.storageLocationRepository,
                    inventoryRepository: dependencies.inventoryRepository,
                    consumptionRepository: dependencies.inventoryConsumptionRecordRepository
                )

                // Check for existing purchase record (deduplication)
                importProgress = "Checking for duplicates..."
                let existingRecord = try await importService.findExistingPurchaseRecord(
                    emailReceiptId: purchase.id,
                    orderNumber: purchase.orderNumber,
                    supplier: purchase.retailerName ?? purchase.retailerId,
                    senderEmail: purchase.senderEmail,
                    orderDate: purchase.orderDate ?? Date(),
                    total: purchase.totalAmount.map { Decimal($0) }
                )

                // Build purchase record items with receipt line hashes
                var purchaseRecordItems: [PurchaseRecordItemModel] = []
                var itemIdMap: [Int: UUID] = [:]  // Map import item index to purchase item ID

                for (index, importItem) in importItems.enumerated() {
                    guard let catalogItem = importItem.catalogItem,
                          let catalogType = importItem.catalogType,
                          importItem.isValid else { continue }

                    // Get quantity based on frit mode
                    let quantity: Double
                    if importItem.hasFritWeightOption && importItem.fritQuantityMode == .weight {
                        guard let weight = Double(importItem.fritWeightValue), weight > 0 else { continue }
                        quantity = weight
                    } else {
                        guard let qty = importItem.quantityInt, qty > 0 else { continue }
                        quantity = Double(qty)
                    }

                    let purchaseItemId = UUID()
                    itemIdMap[index] = purchaseItemId

                    let purchaseItem = PurchaseRecordItemModel(
                        id: purchaseItemId,
                        item_stable_id: catalogItem.stable_id,
                        type: catalogType.lowercased(),
                        quantity: quantity,
                        totalPrice: importItem.receiptItem.totalPrice.map { Decimal($0) },
                        orderIndex: Int32(index),
                        unitPrice: importItem.pricePerUnit.map { Decimal($0) },
                        currency: "USD",
                        receiptLineHash: importItem.receiptItem.lineHash
                    )
                    purchaseRecordItems.append(purchaseItem)
                }

                // Create or update purchase record
                let purchaseRecordId: UUID
                if let existing = existingRecord {
                    purchaseRecordId = existing.id
                    // TODO: Consider updating existing record with new items
                } else {
                    importProgress = "Creating purchase record..."
                    let newRecord = PurchaseRecordModel(
                        supplier: purchase.retailerName ?? purchase.retailerId,
                        datePurchased: purchase.orderDate ?? Date(),
                        subtotal: purchase.totalAmount.map { Decimal($0) },
                        items: purchaseRecordItems,
                        emailReceiptId: purchase.id,
                        senderEmail: purchase.senderEmail,
                        orderNumber: purchase.orderNumber
                    )
                    let created = try await dependencies.purchaseRecordRepository.createRecord(newRecord)
                    purchaseRecordId = created.id
                }

                // Import each item to inventory
                for (index, importItem) in importItems.enumerated() {
                    guard let catalogItem = importItem.catalogItem,
                          let catalogType = importItem.catalogType,
                          importItem.isValid,
                          let purchaseItemId = itemIdMap[index] else { continue }

                    // Determine quantity and containerCount based on type and mode
                    let quantity: Double
                    let containerCount: Double?
                    let isFritType = ["frit", "powder"].contains(catalogType.lowercased())

                    if isFritType {
                        if importItem.hasFritWeightOption && importItem.fritQuantityMode == .weight {
                            // Weight mode: convert to grams for storage
                            guard let weight = Double(importItem.fritWeightValue), weight > 0 else { continue }
                            // Convert from receipt unit to grams
                            if let unit = ReceiptWeightUnit.parse(importItem.fritWeightUnit),
                               let grams = unit.toGrams(weight) {
                                quantity = grams
                            } else {
                                // Fallback: assume grams if can't parse unit
                                quantity = weight
                            }
                            containerCount = nil
                        } else {
                            // Jars mode: quantity is 0, containerCount is the jar count
                            guard let jars = importItem.quantityInt, jars > 0 else { continue }
                            quantity = 0  // No weight, just jars
                            containerCount = Double(jars)
                        }
                    } else {
                        // Non-frit: use quantity directly
                        guard let qty = importItem.quantityInt, qty > 0 else { continue }
                        quantity = Double(qty)
                        containerCount = nil
                    }

                    importProgress = "Importing item \(index + 1) of \(importItems.count)..."

                    let unitPrice = importItem.pricePerUnit.map { Decimal($0) }
                    let stableId = catalogItem.stable_id

                    switch importMode {
                    case .addNew:
                        // Add as new inventory
                        _ = try await importService.importAsNewInventory(
                            itemStableId: stableId,
                            itemType: catalogType.lowercased(),
                            quantity: quantity,
                            containerCount: containerCount,
                            purchaseRecordItemId: purchaseItemId,
                            unitPrice: unitPrice,
                            currency: "USD"
                        )

                    case .matchExisting:
                        // Try to match existing inventory
                        let matchResult = try await importService.findMatchingLocations(
                            itemStableId: stableId,
                            orderDate: purchase.orderDate ?? Date(),
                            requestedQuantity: quantity
                        )

                        if matchResult.isFullMatch || matchResult.availableQuantity > 0 {
                            // Link and split as needed
                            _ = try await importService.linkAndSplitLocations(
                                matchResult: matchResult,
                                purchaseRecordItemId: purchaseItemId,
                                unitPrice: unitPrice,
                                currency: "USD"
                            )

                            // If partial match, add new for the remainder
                            if matchResult.shortfall > 0 {
                                _ = try await importService.importAsNewInventory(
                                    itemStableId: stableId,
                                    itemType: catalogType.lowercased(),
                                    quantity: matchResult.shortfall,
                                    containerCount: containerCount,
                                    purchaseRecordItemId: purchaseItemId,
                                    unitPrice: unitPrice,
                                    currency: "USD"
                                )
                            }
                        } else {
                            // No existing inventory found, add as new
                            _ = try await importService.importAsNewInventory(
                                itemStableId: stableId,
                                itemType: catalogType.lowercased(),
                                quantity: quantity,
                                containerCount: containerCount,
                                purchaseRecordItemId: purchaseItemId,
                                unitPrice: unitPrice,
                                currency: "USD"
                            )
                        }
                    }
                }

                // Mark receipt as acknowledged on server
                importProgress = "Finishing up..."
                try await receiptService.acknowledgeReceipt(receiptId: purchase.id)

                onImportComplete()
                dismiss()
            } catch {
                errorMessage = error.userFacingMessage
            }
            isImporting = false
            importProgress = ""
        }
    }
}

// MARK: - Import Item Row

private struct ReceiptImportItemRow: View {
    @Binding var item: ReceiptImportItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item name from receipt
            Text(item.receiptItem.rawName)
                .font(.subheadline)
                .lineLimit(2)

            // Catalog match info
            if let catalogItem = item.catalogItem {
                HStack(spacing: 4) {
                    Text(catalogItem.name)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(catalogItem.manufacturer.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(4)

                    Text("COE \(catalogItem.coe)")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                Label("No catalog match", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.accentWarning.opacity(0.3))
                    .cornerRadius(4)
            }

            // Frit/Powder: Jars vs Weight picker when receipt has weight info
            if item.hasFritWeightOption {
                fritQuantitySection
            } else {
                // Standard quantity input row
                standardQuantitySection
            }

            // Warning if we couldn't estimate (only show when no frit option)
            if !item.hasFritWeightOption, let reason = item.cannotEstimateReason, item.quantity.isEmpty {
                Label(reason, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.accentWarning.opacity(0.3))
                    .cornerRadius(4)
            }

            // Validation error
            if !item.isValid {
                let errorMessage = item.hasFritWeightOption && item.fritQuantityMode == .weight
                    ? "Enter a valid weight"
                    : "Enter a valid quantity"
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.accentDanger.opacity(0.3))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Frit Quantity Section (Jars vs Weight choice)

    @ViewBuilder
    private var fritQuantitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Info about receipt quantity
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.moltenOrange)
                Text("Receipt shows: \(item.fritWeightValue) \(item.fritWeightUnit)")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Jars vs Weight picker
            Picker("Record as", selection: $item.fritQuantityMode) {
                Text("Jars").tag(FritQuantityMode.jars)
                Text("Weight (\(item.fritWeightUnit))").tag(FritQuantityMode.weight)
            }
            .pickerStyle(.segmented)

            // Input row based on mode
            HStack {
                if item.fritQuantityMode == .jars {
                    Text("Jars:")
                        .font(.subheadline)

                    TextField("0", text: $item.quantity)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                } else {
                    Text("Weight:")
                        .font(.subheadline)

                    TextField("0", text: $item.fritWeightValue)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)

                    Text(item.fritWeightUnit)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                // Price per unit
                if let pricePerUnit = item.pricePerUnit {
                    Text("\(pricePerUnit, format: .currency(code: "USD"))/\(item.unitLabel)")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Standard Quantity Section (for non-frit items)

    @ViewBuilder
    private var standardQuantitySection: some View {
        HStack {
            Text("Quantity:")
                .font(.subheadline)

            TextField("0", text: $item.quantity)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)

            if let estimate = item.rodEstimate {
                Text("(estimated \(estimate.rodCount))")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Price per unit (calculated from current quantity)
            if let pricePerUnit = item.pricePerUnit {
                Text("\(pricePerUnit, format: .currency(code: "USD"))/ea")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Email Body Sheet

private struct EmailBodySheet: View {
    @Environment(\.dismiss) private var dismiss
    let emailBody: String
    let retailerName: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(emailBody)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Original Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PurchaseDetailView(purchaseId: "test-purchase-id")
    }
}

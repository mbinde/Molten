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
    @State private var matchingProgress: (completed: Int, total: Int) = (0, 0)
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
    // Report/Delete state
    @State private var isReporting = false
    @State private var isDeleting = false
    @State private var showingDeleteConfirmation = false
    @State private var actionAlert: ActionAlert?

    private enum ActionAlert: Identifiable {
        case reportSuccess
        case reportError(String)
        case deleteError(String)

        var id: String {
            switch self {
            case .reportSuccess: return "reportSuccess"
            case .reportError(let msg): return "reportError-\(msg)"
            case .deleteError(let msg): return "deleteError-\(msg)"
            }
        }
    }

    let purchaseId: String

    private var receiptService: ReceiptService {
        dependencies.receiptService
    }

    private var catalogService: CatalogService {
        dependencies.catalogService
    }

    private var retailerDisplayName: String {
        guard let purchase = purchase else { return "" }
        if let name = purchase.retailerName {
            return name
        }
        if let retailerId = purchase.retailerId {
            return retailerId.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return "Unknown retailer"
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
                loadingView
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

                        // Failed receipt actions
                        if purchase.isParseFailed {
                            failedReceiptActionsSection
                        }

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
                    }
                    .padding()
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Report Issue - for failed receipts
                    if purchase?.isParseFailed == true {
                        Button {
                            reportAndHideReceipt()
                        } label: {
                            Label("Report Issue", systemImage: "envelope.badge")
                        }
                        .disabled(isReporting)
                    }

                    // Delete - for any receipt
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(isDeleting)
                } label: {
                    if isReporting || isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Receipt",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteReceipt()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This receipt will be hidden from your list. You can re-import it by forwarding the email again.")
        }
        .alert(item: $actionAlert) { alert in
            switch alert {
            case .reportSuccess:
                return Alert(
                    title: Text("Report Submitted"),
                    message: Text("Thank you for reporting this issue. We'll investigate and improve our parser."),
                    dismissButton: .default(Text("OK")) {
                        // Only dismiss if this was a failed receipt (it gets hidden)
                        if purchase?.isParseFailed == true {
                            dismiss()
                        }
                    }
                )
            case .reportError(let message):
                return Alert(
                    title: Text("Could Not Submit Report"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            case .deleteError(let message):
                return Alert(
                    title: Text("Could Not Delete"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            if isMatching && matchingProgress.total > 0 {
                // Show progress when matching items
                VStack(spacing: 8) {
                    Text("Matching items to catalog...")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    ProgressView(value: Double(matchingProgress.completed), total: Double(matchingProgress.total))
                        .progressViewStyle(.linear)
                        .tint(DesignSystem.Colors.moltenOrange)

                    Text("\(matchingProgress.completed) of \(matchingProgress.total)")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, 40)
            } else {
                // Initial loading spinner
                ProgressView("Loading order...")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Failed Receipt Actions Section

    @ViewBuilder
    private var failedReceiptActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DesignSystem.Colors.accentWarning)
                Text("Unable to Parse")
                    .font(.headline)
            }

            Text("We couldn't recognize this email as an order confirmation. You can report this issue so we can improve our parser, or delete it from your list.")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            HStack(spacing: 12) {
                Button {
                    reportAndHideReceipt()
                } label: {
                    HStack {
                        if isReporting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "envelope.badge")
                        }
                        Text("Report Issue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.Colors.moltenOrange)
                .disabled(isReporting || isDeleting)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("Delete")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isReporting || isDeleting)
            }
        }
        .padding()
        .background(DesignSystem.Colors.accentWarning.opacity(0.1))
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
        if let existing = existingPurchaseRecord, let purchase = purchase {
            let categories = categorizeItems(purchase.items)
            let hasMoreToImport = !categories.readyToImport.isEmpty

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: hasMoreToImport ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(hasMoreToImport ? DesignSystem.Colors.accentWarning : DesignSystem.Colors.accentSuccess)

                    Text(hasMoreToImport ? "Partially Imported" : "Already Imported")
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

                // Dynamic summary based on categories
                Text(importSummaryText(categories: categories, existing: existing))
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

                    // Show breakdown of item status
                    importStatusBreakdown(categories: categories)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.background)
                .cornerRadius(8)

                // Action buttons - different based on whether there's more to import
                HStack(spacing: 12) {
                    if hasMoreToImport {
                        // Primary action: Import the remaining items
                        Button {
                            withAnimation {
                                exactDuplicateDismissed = true
                                // Select only the items that are ready to import
                                selectedItems = Set(categories.readyToImport.map { $0.id })
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("Import \(categories.readyToImport.count) More")
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        // Dismiss as done
                        Button {
                            dismissAsDuplicate()
                        } label: {
                            HStack {
                                if isMarking {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.small)
                                }
                                Text("Dismiss")
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isMarking)
                    } else {
                        // All done - primary action is dismiss
                        Button {
                            dismissAsDuplicate()
                        } label: {
                            HStack {
                                if isMarking {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .controlSize(.small)
                                }
                                Text("Dismiss as Done")
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignSystem.Colors.accentSuccess)
                        .disabled(isMarking)

                        // Re-import option
                        Button {
                            withAnimation {
                                // Clear the existing record to allow re-import
                                existingPurchaseRecord = nil
                                importedItemsMap = [:]
                                exactDuplicateDismissed = true
                                // Re-select all items with catalog matches
                                let selectableItemIds = selectableItems(purchase.items).map { $0.id }
                                selectedItems = Set(selectableItemIds)
                            }
                        } label: {
                            Text("Re-Import Anyway")
                                .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()
                }

                Text(hasMoreToImport
                    ? "You can import additional items or dismiss this receipt."
                    : "Dismiss removes this from your inbox. Re-import lets you add items again.")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding()
            .background((hasMoreToImport ? DesignSystem.Colors.accentWarning : DesignSystem.Colors.accentSuccess).opacity(0.1))
            .cornerRadius(12)
        }
    }

    /// Generate summary text based on import status
    private func importSummaryText(categories: ItemCategories, existing: PurchaseRecordModel) -> String {
        let total = categories.readyToImport.count + categories.cannotImport.count + categories.alreadyImported.count

        if categories.readyToImport.isEmpty && categories.cannotImport.isEmpty {
            // All items were imported
            return "All \(total) items from this receipt were imported to your inventory."
        } else if categories.readyToImport.isEmpty {
            // All importable items were imported, some couldn't be matched
            return "All importable items were imported. \(categories.cannotImport.count) item\(categories.cannotImport.count == 1 ? " has" : "s have") no catalog match."
        } else {
            // Some items can still be imported
            return "\(categories.readyToImport.count) item\(categories.readyToImport.count == 1 ? "" : "s") can still be imported."
        }
    }

    /// Show breakdown of item import status
    @ViewBuilder
    private func importStatusBreakdown(categories: ItemCategories) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if !categories.alreadyImported.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.accentSuccess)
                    Text("\(categories.alreadyImported.count) imported")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            if !categories.readyToImport.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.accentWarning)
                    Text("\(categories.readyToImport.count) ready to import")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            if !categories.cannotImport.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("\(categories.cannotImport.count) no catalog match")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
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

    /// Categorize items into three groups for display
    private struct ItemCategories {
        let readyToImport: [ReceiptItem]    // Has catalog match, not yet imported
        let cannotImport: [ReceiptItem]      // No catalog match
        let alreadyImported: [ReceiptItem]   // Previously imported
    }

    private func categorizeItems(_ items: [ReceiptItem]) -> ItemCategories {
        var readyToImport: [ReceiptItem] = []
        var cannotImport: [ReceiptItem] = []
        var alreadyImported: [ReceiptItem] = []

        for item in items {
            if importedItemsMap.keys.contains(item.id) {
                alreadyImported.append(item)
            } else if hasCatalogMatch(item) {
                readyToImport.append(item)
            } else {
                cannotImport.append(item)
            }
        }

        return ItemCategories(
            readyToImport: readyToImport,
            cannotImport: cannotImport,
            alreadyImported: alreadyImported
        )
    }

    @ViewBuilder
    private func itemsSection(_ purchase: ReceiptDetail) -> some View {
        let categories = categorizeItems(purchase.items)
        let allSelectableIds = Set(categories.readyToImport.map { $0.id })
        let allSelected = !allSelectableIds.isEmpty && selectedItems == allSelectableIds

        VStack(alignment: .leading, spacing: 16) {
            // Header with select all
            HStack {
                Text("Items (\(purchase.items.count))")
                    .font(.headline)

                Spacer()

                if !isImported && !categories.readyToImport.isEmpty {
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
                // Section 1: Ready to Import (has catalog match, not imported)
                if !categories.readyToImport.isEmpty {
                    itemGroupSection(
                        title: "Ready to Import",
                        subtitle: "\(categories.readyToImport.count) item\(categories.readyToImport.count == 1 ? "" : "s")",
                        items: categories.readyToImport,
                        icon: "arrow.down.circle",
                        iconColor: DesignSystem.Colors.accentSuccess
                    )

                    // Import button right after importable items
                    if !selectedItems.isEmpty && !isImported {
                        Button {
                            showingImportSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import \(selectedItems.count) Item\(selectedItems.count == 1 ? "" : "s")")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                }

                // Section 2: Cannot Import (no catalog match)
                if !categories.cannotImport.isEmpty {
                    itemGroupSection(
                        title: "No Catalog Match",
                        subtitle: "\(categories.cannotImport.count) item\(categories.cannotImport.count == 1 ? "" : "s")",
                        items: categories.cannotImport,
                        icon: "xmark.circle",
                        iconColor: DesignSystem.Colors.textSecondary
                    )
                }

                // Section 3: Already Imported
                if !categories.alreadyImported.isEmpty {
                    itemGroupSection(
                        title: "Already Imported",
                        subtitle: "\(categories.alreadyImported.count) item\(categories.alreadyImported.count == 1 ? "" : "s")",
                        items: categories.alreadyImported,
                        icon: "checkmark.circle.fill",
                        iconColor: DesignSystem.Colors.textSecondary
                    )
                }

                // Report Issue button for parsed receipts
                reportIssueSection

                // Delete button - only show if NO items can be imported
                // (all items either have no catalog match or are already imported)
                if categories.readyToImport.isEmpty {
                    deleteReceiptSection
                }
            }

            // Extra padding to keep content above tab bar
            Spacer()
                .frame(height: 60)
        }
    }

    // MARK: - Delete Receipt Section (for receipts with no importable items)

    @ViewBuilder
    private var deleteReceiptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.top, 8)

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Delete Receipt")
                }
                .font(.subheadline)
            }
            .disabled(isDeleting)
            .padding(.top, 4)

            Text("Remove this receipt from your inbox")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Report Issue Section (for parsed receipts)

    @ViewBuilder
    private var reportIssueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.top, 16)

            Button {
                reportParseIssue()
            } label: {
                HStack {
                    if isReporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "flag")
                    }
                    Text("Report Issue with Parse")
                }
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .disabled(isReporting)
            .padding(.top, 8)

            Text("Let us know if items are missing or incorrectly parsed")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    /// Report a parse issue (without hiding - for successfully parsed receipts)
    private func reportParseIssue() {
        isReporting = true

        Task { @MainActor in
            do {
                try await receiptService.reportParseIssue(receiptId: purchaseId)
                actionAlert = .reportSuccess
            } catch {
                actionAlert = .reportError(error.localizedDescription)
            }
            isReporting = false
        }
    }

    @ViewBuilder
    private func itemGroupSection(
        title: String,
        subtitle: String,
        items: [ReceiptItem],
        icon: String,
        iconColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("·")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Items
            ForEach(items) { item in
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
                supplier: receipt.retailerName ?? receipt.retailerId ?? "Unknown",
                senderEmail: receipt.senderEmail,
                orderDate: receipt.orderDate ?? Date(),
                total: receipt.totalAmount.map { Decimal($0) }
            )

            if let existing = existing {
                existingPurchaseRecord = existing

                // Build mapping from receipt items to imported items by matching line hash
                // This is stable across re-imports since it's based on the receipt line content
                let importedItemsByHash: [String: PurchaseRecordItemModel] = Dictionary(
                    existing.items.compactMap { item -> (String, PurchaseRecordItemModel)? in
                        guard let hash = item.receiptLineHash else { return nil }
                        return (hash, item)
                    },
                    uniquingKeysWith: { (first: PurchaseRecordItemModel, _: PurchaseRecordItemModel) in first }
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
                supplier: receipt.retailerName ?? receipt.retailerId ?? "Unknown",
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
    @MainActor
    private func matchItemsWithCatalog(_ receipt: ReceiptDetail) async {
        isMatching = true
        matchingProgress = (0, 0)
        let matcher = ReceiptCatalogMatcher(catalogService: catalogService)

        // Only match items that haven't already been imported
        let itemsToMatch = receipt.items.filter { !importedItemsMap.keys.contains($0.id) }

        // Capture a reference to update progress on main actor
        let updateProgress: @Sendable (Int, Int) async -> Void = { @MainActor completed, total in
            self.matchingProgress = (completed, total)
        }

        let results = await matcher.matchItems(
            itemsToMatch,
            retailerId: receipt.retailerId ?? "",
            onProgress: updateProgress
        )

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

    /// Report a parse issue and hide the receipt locally
    private func reportAndHideReceipt() {
        isReporting = true

        Task { @MainActor in
            do {
                // Report the issue to the server
                try await receiptService.reportParseIssue(receiptId: purchaseId)
                // Hide locally so it doesn't show in the list
                receiptService.hideReceipt(id: purchaseId)
                actionAlert = .reportSuccess
            } catch {
                actionAlert = .reportError(error.localizedDescription)
            }
            isReporting = false
        }
    }

    /// Delete (hide) the receipt locally
    private func deleteReceipt() {
        isDeleting = true

        Task { @MainActor in
            // Just hide locally - don't need server interaction
            receiptService.hideReceipt(id: purchaseId)
            isDeleting = false
            dismiss()
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
                    // No checkbox for already-imported items - it's clear from the section header
                    if !isAlreadyImported && isSelectable {
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
                        // Import mode picker - custom cards for clarity
                        Section {
                            VStack(spacing: 8) {
                                Text("Select one:")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Option 1: Add as new inventory
                                ImportModeCard(
                                    title: "Create New",
                                    description: "Add these as new items in your inventory",
                                    isSelected: importMode == .addNew,
                                    action: { importMode = .addNew }
                                )

                                // Option 2: Match to existing
                                ImportModeCard(
                                    title: "Add to Existing",
                                    description: "Find items you've already added and add price and purchase date information.",
                                    isSelected: importMode == .matchExisting,
                                    action: { importMode = .matchExisting }
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
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
                    supplier: purchase.retailerName ?? purchase.retailerId ?? "Unknown",
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
                let shouldDeleteCurrentReceipt: Bool
                if let existing = existingRecord {
                    // Merge new items into existing purchase record
                    importProgress = "Merging with existing purchase record..."

                    // Combine existing items with new items, adjusting order indices
                    let existingMaxIndex = existing.items.map { $0.orderIndex }.max() ?? -1
                    let adjustedNewItems = purchaseRecordItems.enumerated().map { offset, item in
                        PurchaseRecordItemModel(
                            id: item.id,
                            item_stable_id: item.item_stable_id,
                            type: item.type,
                            subtype: item.subtype,
                            subsubtype: item.subsubtype,
                            quantity: item.quantity,
                            totalPrice: item.totalPrice,
                            orderIndex: existingMaxIndex + 1 + Int32(offset),
                            unitPrice: item.unitPrice,
                            currency: item.currency,
                            receiptLineHash: item.receiptLineHash
                        )
                    }

                    let mergedItems = existing.items + adjustedNewItems

                    // Create updated record with merged items
                    let updatedRecord = PurchaseRecordModel(
                        id: existing.id,
                        supplier: existing.supplier,
                        datePurchased: existing.datePurchased,
                        dateAdded: existing.dateAdded,
                        subtotal: existing.subtotal,
                        tax: existing.tax,
                        shipping: existing.shipping,
                        currency: existing.currency,
                        notes: existing.notes,
                        items: mergedItems,
                        workspace_id: existing.workspace_id,
                        emailReceiptId: existing.emailReceiptId,
                        senderEmail: existing.senderEmail,
                        orderNumber: existing.orderNumber
                    )

                    _ = try await dependencies.purchaseRecordRepository.updateRecord(updatedRecord)
                    purchaseRecordId = existing.id
                    shouldDeleteCurrentReceipt = true  // Delete this duplicate after import
                } else {
                    importProgress = "Creating purchase record..."
                    let newRecord = PurchaseRecordModel(
                        supplier: purchase.retailerName ?? purchase.retailerId ?? "Unknown",
                        datePurchased: purchase.orderDate ?? Date(),
                        subtotal: purchase.totalAmount.map { Decimal($0) },
                        items: purchaseRecordItems,
                        emailReceiptId: purchase.id,
                        senderEmail: purchase.senderEmail,
                        orderNumber: purchase.orderNumber
                    )
                    let created = try await dependencies.purchaseRecordRepository.createRecord(newRecord)
                    purchaseRecordId = created.id
                    shouldDeleteCurrentReceipt = false  // This is a new record, don't delete receipt
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

                    print("[Import] Processing item \(index): stableId=\(stableId), type=\(catalogType), quantity=\(quantity), mode=\(importMode)")

                    switch importMode {
                    case .addNew:
                        print("[Import] Mode is addNew, creating new inventory")
                        // Add as new inventory
                        _ = try await importService.importAsNewInventory(
                            itemStableId: stableId,
                            itemType: catalogType.lowercased(),
                            quantity: quantity,
                            containerCount: containerCount,
                            purchaseRecordItemId: purchaseItemId,
                            unitPrice: unitPrice,
                            currency: "USD",
                            purchaseDate: purchase.orderDate
                        )

                    case .matchExisting:
                        print("[Import] Mode is matchExisting, searching for existing inventory")
                        // Try to match existing inventory
                        let matchResult = try await importService.findMatchingLocations(
                            itemStableId: stableId,
                            orderDate: purchase.orderDate ?? Date(),
                            requestedQuantity: quantity
                        )

                        print("[Import] matchResult: isFullMatch=\(matchResult.isFullMatch), availableQty=\(matchResult.availableQuantity), shortfall=\(matchResult.shortfall)")

                        if matchResult.isFullMatch || matchResult.availableQuantity > 0 {
                            print("[Import] Found existing inventory, linking and splitting")
                            // Link and split as needed
                            _ = try await importService.linkAndSplitLocations(
                                matchResult: matchResult,
                                purchaseRecordItemId: purchaseItemId,
                                unitPrice: unitPrice,
                                currency: "USD",
                                purchaseDate: purchase.orderDate
                            )

                            // If partial match, add new for the remainder
                            if matchResult.shortfall > 0 {
                                print("[Import] Partial match, adding \(matchResult.shortfall) as new inventory")
                                _ = try await importService.importAsNewInventory(
                                    itemStableId: stableId,
                                    itemType: catalogType.lowercased(),
                                    quantity: matchResult.shortfall,
                                    containerCount: containerCount,
                                    purchaseRecordItemId: purchaseItemId,
                                    unitPrice: unitPrice,
                                    currency: "USD",
                                    purchaseDate: purchase.orderDate
                                )
                            }
                        } else {
                            print("[Import] No existing inventory found, falling back to addNew")
                            // No existing inventory found, add as new
                            _ = try await importService.importAsNewInventory(
                                itemStableId: stableId,
                                itemType: catalogType.lowercased(),
                                quantity: quantity,
                                containerCount: containerCount,
                                purchaseRecordItemId: purchaseItemId,
                                unitPrice: unitPrice,
                                currency: "USD",
                                purchaseDate: purchase.orderDate
                            )
                        }
                    }
                }

                // Handle receipt cleanup on server
                importProgress = "Finishing up..."
                if shouldDeleteCurrentReceipt {
                    // This was a duplicate receipt merged into an existing purchase record
                    // Delete it from the server to avoid showing it again
                    try await receiptService.deleteReceipt(receiptId: purchase.id)
                } else {
                    // Normal import - just acknowledge the receipt
                    try await receiptService.acknowledgeReceipt(receiptId: purchase.id)
                }

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

// MARK: - Import Mode Card

/// A selectable card for choosing import mode
private struct ImportModeCard: View {
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? DesignSystem.Colors.moltenOrange : DesignSystem.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(12)
            .background(isSelected ? DesignSystem.Colors.moltenOrange.opacity(0.15) : DesignSystem.Colors.background)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? DesignSystem.Colors.moltenOrange : DesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
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

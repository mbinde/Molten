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
    @State private var showingEmailBody = false
    @State private var emailBody: String?
    @State private var isLoadingEmail = false
    // Recovery state
    @State private var recoveryEmail: String = ""
    @State private var recoveryError: String?
    @State private var isRecovering = false
    @State private var showingRecoveryEmailSent = false

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

                        // Items Section
                        itemsSection(purchase)

                        // Actions
                        if !isImported {
                            actionsSection(purchase)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Order Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
                    catalogService: catalogService,
                    receiptService: receiptService,
                    onImportComplete: {
                        isImported = true
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
                        .foregroundColor(.green)
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Items Section

    @ViewBuilder
    private func itemsSection(_ purchase: ReceiptDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items (\(purchase.items.count))")
                    .font(.headline)

                Spacer()

                if !isImported && !purchase.items.isEmpty {
                    Button {
                        if selectedItems.count == purchase.items.count {
                            selectedItems.removeAll()
                        } else {
                            selectedItems = Set(purchase.items.map { $0.id })
                        }
                    } label: {
                        Text(selectedItems.count == purchase.items.count ? "Select None" : "Select All")
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
                        isSelected: selectedItems.contains(item.id),
                        isSelectable: !isImported,
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
                // Select all items by default (unless already imported)
                if !loaded.acknowledged {
                    selectedItems = Set(loaded.items.map { $0.id })
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
    let isSelected: Bool
    let isSelectable: Bool
    let catalogService: CatalogService
    /// The currently selected candidate's stable ID (nil = use original order)
    let selectedCandidateId: String?
    /// User's explicit quantity override (nil = use rod estimate or item quantity)
    let quantityOverride: Int?
    let onToggle: () -> Void
    let onSelectCandidate: (String) -> Void
    let onQuantityChange: (Int) -> Void

    @State private var catalogItem: GlassItemModel?
    @State private var isLoadingCatalog = false
    @State private var showingCandidates = false
    @State private var justSwapped = false
    @State private var rodEstimate: RodEstimate?

    /// Reorders candidates so the selected one is first
    private var orderedCandidates: [MatchCandidate] {
        guard let candidates = item.matchCandidates, !candidates.isEmpty else { return [] }
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
    private var unitDisplayName: String {
        if rodEstimate != nil {
            return displayQuantity == 1 ? "Rod" : "Rods"
        }
        guard let candidate = topCandidate else { return "item" }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main item row
            Button {
                if isSelectable {
                    onToggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    if isSelectable {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                            .font(.title3)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // Item name
                        Text(item.rawName)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        // SKU if available
                        if let sku = item.rawSku {
                            Text("SKU: \(sku)")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        // Quantity and unit price row (editable)
                        if topCandidate != nil {
                            HStack(spacing: 4) {
                                // Quantity stepper
                                Button {
                                    if displayQuantity > 1 {
                                        onQuantityChange(displayQuantity - 1)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(displayQuantity > 1 ? .accentColor : DesignSystem.Colors.textSecondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(displayQuantity <= 1)

                                Text("\(displayQuantity)")
                                    .font(.subheadline.bold())
                                    .frame(minWidth: 24)

                                Button {
                                    onQuantityChange(displayQuantity + 1)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)

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
                        }

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
                        } else if item.catalogStableId != nil, let catalogItem = catalogItem {
                            // Fallback: show catalog item if loaded but no candidates
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.caption2)
                                Text(catalogItem.name)
                                    .font(.caption)
                            }
                            .foregroundColor(matchConfidenceColor)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle")
                                    .font(.caption2)
                                Text("No catalog match")
                                    .font(.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.textSecondary)
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
                    .foregroundColor(.accentColor)
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
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
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
        // Use the selected candidate if available, otherwise use the top candidate or default match
        let stableId = selectedCandidateId
            ?? item.matchCandidates?.first?.catalogStableId
            ?? item.catalogStableId

        guard let stableId = stableId else { return }
        isLoadingCatalog = true
        catalogItem = try? await catalogService.fetchGlassItem(byStableId: stableId)
        calculateRodEstimate()
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
    }
}

// MARK: - Top Match Card (shown inline with item)

private struct TopMatchCard: View {
    let candidate: MatchCandidate

    private var confidenceColor: Color {
        if candidate.confidence >= 0.9 { return .green }
        if candidate.confidence >= 0.7 { return .orange }
        if candidate.confidence >= 0.5 { return .yellow }
        return .red
    }

    /// Full manufacturer name from abbreviation
    private var manufacturerName: String {
        GlassManufacturers.manufacturers[candidate.catalogManufacturer.uppercased()]
            ?? candidate.catalogManufacturer
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.catalogName)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text(manufacturerName)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)

                    Text(candidate.catalogType.capitalized)
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            // Confidence badge
            Text("\(Int(candidate.confidence * 100))%")
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor)
                .cornerRadius(12)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(6)
    }
}

// MARK: - Candidate Row (for dropdown list, tappable to select)

private struct CandidateRow: View {
    let candidate: MatchCandidate
    let onSelect: () -> Void

    private var confidenceColor: Color {
        if candidate.confidence >= 0.9 { return .green }
        if candidate.confidence >= 0.7 { return .orange }
        if candidate.confidence >= 0.5 { return .yellow }
        return .red
    }

    /// Full manufacturer name from abbreviation
    private var manufacturerName: String {
        GlassManufacturers.manufacturers[candidate.catalogManufacturer.uppercased()]
            ?? candidate.catalogManufacturer
    }

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.catalogName)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text(manufacturerName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)

                        Text(candidate.catalogType.capitalized)
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                // Confidence badge
                Text("\(Int(candidate.confidence * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidenceColor)
                    .cornerRadius(12)

                // Indicate it's selectable
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Purchase Import Sheet

/// Model for an item being imported with its editable quantity
private struct ReceiptImportItem: Identifiable {
    let id: Int
    let receiptItem: ReceiptItem
    let catalogStableId: String?
    let catalogType: String?  // Type from match candidate (e.g., "rod", "frit")
    var catalogItem: GlassItemModel?
    var quantity: String  // String for text field binding
    var rodEstimate: RodEstimate?  // Full estimate with rod count and price per rod
    var cannotEstimateReason: String?  // Reason why we couldn't estimate

    var quantityInt: Int? {
        Int(quantity)
    }

    var isValid: Bool {
        if let qty = quantityInt {
            return qty > 0
        }
        return false
    }

    /// Calculate the price per unit based on current quantity
    var pricePerUnit: Double? {
        guard let total = receiptItem.totalPrice,
              let qty = quantityInt, qty > 0 else { return nil }
        return total / Double(qty)
    }
}

private struct PurchaseImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies

    let purchase: ReceiptDetail
    let selectedItemIds: Set<Int>
    let selectedMatches: [Int: String]  // item.id -> catalogStableId
    let catalogService: CatalogService
    let receiptService: ReceiptService
    let onImportComplete: () -> Void

    @State private var importItems: [ReceiptImportItem] = []
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importMode: ReceiptImportMode = .addNew
    @State private var importProgress: String = ""

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
                        } footer: {
                            Text(importMode == .addNew
                                ? "Creates new inventory entries for each item."
                                : "Tries to find and link to existing inventory you already added.")
                        }

                        // Items section
                        Section {
                            ForEach($importItems) { $item in
                                ReceiptImportItemRow(item: $item)
                            }
                        } header: {
                            Text("Items to Import")
                        } footer: {
                            if invalidItemCount > 0 {
                                Label(
                                    "\(invalidItemCount) item\(invalidItemCount == 1 ? " needs" : "s need") a quantity and catalog match before importing",
                                    systemImage: "exclamationmark.triangle"
                                )
                                .foregroundColor(.orange)
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
                            .disabled(!allItemsValid || isImporting)
                        }

                        if let error = errorMessage {
                            Section {
                                Label(error, systemImage: "exclamationmark.triangle")
                                    .foregroundColor(.red)
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
                await loadCatalogInfo()
            }
        }
    }

    // MARK: - Data Loading

    private func loadCatalogInfo() async {
        var items: [ReceiptImportItem] = []

        for receiptItem in selectedItems {
            // Determine which catalog item to use (user override or default)
            let selectedCandidateId = selectedMatches[receiptItem.id]
            let matchCandidate = receiptItem.matchCandidates?.first(where: { $0.catalogStableId == selectedCandidateId })
                ?? receiptItem.matchCandidates?.first

            let catalogStableId = matchCandidate?.catalogStableId ?? receiptItem.catalogStableId
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

            // Try to estimate quantity for rods
            if let catalogItem = importItem.catalogItem {
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
                        importItem.cannotEstimateReason = "Sold by count, not weight"
                    } else if RodEstimator.dimensions(forCOE: catalogItem.coe) == nil {
                        importItem.cannotEstimateReason = "Unknown COE (\(catalogItem.coe))"
                    } else {
                        importItem.cannotEstimateReason = "Could not calculate"
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

                // Create or update purchase record
                let purchaseRecordId: UUID
                if let existing = existingRecord {
                    purchaseRecordId = existing.id
                } else {
                    importProgress = "Creating purchase record..."
                    let newRecord = PurchaseRecordModel(
                        supplier: purchase.retailerName ?? purchase.retailerId,
                        datePurchased: purchase.orderDate ?? Date(),
                        subtotal: purchase.totalAmount.map { Decimal($0) },
                        emailReceiptId: purchase.id,
                        senderEmail: purchase.senderEmail,
                        orderNumber: purchase.orderNumber
                    )
                    let created = try await dependencies.purchaseRecordRepository.createRecord(newRecord)
                    purchaseRecordId = created.id
                }

                // Import each item
                for (index, importItem) in importItems.enumerated() {
                    guard let catalogItem = importItem.catalogItem,
                          let catalogType = importItem.catalogType,
                          let quantity = importItem.quantityInt,
                          quantity > 0 else { continue }

                    importProgress = "Importing item \(index + 1) of \(importItems.count)..."

                    let purchaseItemId = UUID()
                    let unitPrice = importItem.pricePerUnit.map { Decimal($0) }
                    let stableId = catalogItem.stable_id

                    // Create purchase record item
                    // Note: This is handled by the existing record, but we track items separately
                    // The purchase record item links the receipt line to inventory

                    switch importMode {
                    case .addNew:
                        // Add as new inventory
                        _ = try await importService.importAsNewInventory(
                            itemStableId: stableId,
                            itemType: catalogType.lowercased(),
                            quantity: Double(quantity),
                            purchaseRecordItemId: purchaseItemId,
                            unitPrice: unitPrice,
                            currency: "USD"
                        )

                    case .matchExisting:
                        // Try to match existing inventory
                        let matchResult = try await importService.findMatchingLocations(
                            itemStableId: stableId,
                            orderDate: purchase.orderDate ?? Date(),
                            requestedQuantity: Double(quantity)
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
                                quantity: Double(quantity),
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
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)

                    Text("COE \(catalogItem.coe)")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                Text("No catalog match")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Quantity input row
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

            // Warning if we couldn't estimate
            if let reason = item.cannotEstimateReason, item.quantity.isEmpty {
                Label(reason, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Validation error
            if !item.quantity.isEmpty && !item.isValid {
                Label("Enter a valid quantity", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
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

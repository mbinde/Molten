//
//  OnlineStockCard.swift
//  Molten
//
//  Card component showing online stock availability at retailers
//

import SwiftUI

/// Card displaying online stock availability for an item across retailers
struct OnlineStockCard: View {
    let stockData: OnlineStockModel?
    let isLoading: Bool
    let error: Error?
    let onRetailerTap: ((RetailerStockModel) -> Void)?
    let onRefresh: (() -> Void)?

    init(
        stockData: OnlineStockModel? = nil,
        isLoading: Bool = false,
        error: Error? = nil,
        onRetailerTap: ((RetailerStockModel) -> Void)? = nil,
        onRefresh: (() -> Void)? = nil
    ) {
        self.stockData = stockData
        self.isLoading = isLoading
        self.error = error
        self.onRetailerTap = onRetailerTap
        self.onRefresh = onRefresh
    }

    /// Whether we have stock to display
    private var hasStockToShow: Bool {
        guard let data = stockData else { return false }
        return !data.retailers.isEmpty && data.anyInStock
    }

    var body: some View {
        VStack(alignment: .leading, spacing: hasStockToShow ? DesignSystem.Spacing.lg : 0) {
            header

            if isLoading {
                loadingState
            } else if hasStockToShow {
                retailerList(stockData!.retailers)
            }
            // No content shown for error, empty, or out-of-stock - header handles it
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Online Availability", systemImage: "cart.fill")
                .font(DesignSystem.Typography.subsectionTitle)
                .fontWeight(DesignSystem.FontWeight.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            // Status indicator
            if !isLoading {
                if let data = stockData, data.anyInStock {
                    Text("In stock")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.accentSuccess)
                } else if error != nil {
                    Text("Unavailable")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                } else {
                    Text("No stock found")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.accentDanger)
                }
            }

            if let onRefresh = onRefresh, !isLoading {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        HStack {
            ProgressView()
            Text("Checking availability...")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Retailer List

    /// A display row combining retailer info with a specific price option
    private struct DisplayRow: Identifiable {
        let retailer: RetailerStockModel
        let option: PriceOptionModel?
        let form: String?

        var id: String {
            "\(retailer.retailerCode)-\(option?.variantId ?? "default")-\(form ?? "none")"
        }

        var isAvailable: Bool {
            option?.available ?? retailer.stockStatus.isAvailable
        }
    }

    private func retailerList(_ retailers: [RetailerStockModel]) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(buildDisplayRows(retailers)) { row in
                retailerRow(row)
            }
        }
    }

    /// Build display rows - one per form per retailer
    private func buildDisplayRows(_ retailers: [RetailerStockModel]) -> [DisplayRow] {
        var rows: [DisplayRow] = []

        for retailer in retailers {
            let bestOptions = retailer.bestOptionPerForm

            if bestOptions.isEmpty {
                // No price options, show single row with retailer info
                rows.append(DisplayRow(retailer: retailer, option: nil, form: nil))
            } else {
                // One row per form with best price
                for option in bestOptions {
                    rows.append(DisplayRow(retailer: retailer, option: option, form: option.form))
                }
            }
        }

        // Sort: available first, then by retailer name, then by form
        return rows.sorted { lhs, rhs in
            if lhs.isAvailable && !rhs.isAvailable { return true }
            if !lhs.isAvailable && rhs.isAvailable { return false }
            if lhs.retailer.retailerName != rhs.retailer.retailerName {
                return lhs.retailer.retailerName < rhs.retailer.retailerName
            }
            return (lhs.form ?? "") < (rhs.form ?? "")
        }
    }

    // MARK: - Retailer Row

    private func retailerRow(_ row: DisplayRow) -> some View {
        Button {
            onRetailerTap?(row.retailer)
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Status indicator
                stockStatusIcon(row.isAvailable ? .inStock : .outOfStock)

                // Retailer name with optional form
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.retailer.retailerName)
                        .font(DesignSystem.Typography.listItemSubtitle)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if let form = row.form {
                        Text(form)
                            .font(DesignSystem.Typography.listItemCaption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                // Price if available
                if let price = row.option?.formattedPrice {
                    Text(price)
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Link indicator
                if row.retailer.productUrl != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .background(row.retailer.productUrl != nil ? DesignSystem.Colors.background : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(row.retailer.productUrl == nil)
    }

    // MARK: - Stock Status Icon

    @ViewBuilder
    private func stockStatusIcon(_ status: StockStatus) -> some View {
        switch status {
        case .inStock:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.accentSuccess)
        case .lowStock:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.accentWarning)
        case .outOfStock:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.accentDanger)
        case .unknown, .notCarried:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
    }
}

// MARK: - Preview

#Preview("With Stock Data") {
    let retailers = [
        RetailerStockModel(
            retailerCode: "northstar",
            retailerName: "Northstar Glassworks",
            stockStatus: .inStock,
            lastChecked: Date(),
            productUrl: "https://northstarglass.com/product/123",
            priceOptions: [
                PriceOptionModel(variantId: "1", variantTitle: "Rods - First Quality", price: 85.00, priceUnit: "lb", currency: "USD", available: true),
                PriceOptionModel(variantId: "2", variantTitle: "Rods - Odd Quality", price: 65.00, priceUnit: "lb", currency: "USD", available: true),
                PriceOptionModel(variantId: "3", variantTitle: "Frit", price: 90.00, priceUnit: "16 oz jar", currency: "USD", available: true)
            ],
            quantityAvailable: 3
        ),
        RetailerStockModel(
            retailerCode: "lws",
            retailerName: "Lampwork Supply",
            stockStatus: .inStock,
            lastChecked: Date(),
            productUrl: "https://lampworksupply.com/product/123",
            priceOptions: [
                PriceOptionModel(variantId: "4", variantTitle: "Rods - First Quality", price: 80.00, priceUnit: "lb", currency: "USD", available: true),
                PriceOptionModel(variantId: "5", variantTitle: "Fine Frit", price: 85.00, priceUnit: "16 oz jar", currency: "USD", available: true)
            ],
            quantityAvailable: 2
        ),
        RetailerStockModel(
            retailerCode: "abr",
            retailerName: "ABR Imagery",
            stockStatus: .inStock,
            lastChecked: Date(),
            productUrl: "https://abrimagery.com/product/123",
            priceOptions: [
                PriceOptionModel(variantId: "6", variantTitle: "Rods", price: 25.50, priceUnit: "1/4 lb", currency: "USD", available: true)
            ],
            quantityAvailable: 1
        ),
        RetailerStockModel(
            retailerCode: "delphi",
            retailerName: "Delphi Glass",
            stockStatus: .outOfStock,
            lastChecked: Date(),
            productUrl: "https://delphi.com/product/123",
            priceOptions: [],
            quantityAvailable: nil
        )
    ]

    let stockData = OnlineStockModel(
        itemStableId: "test123",
        retailers: retailers,
        lastUpdated: Date()
    )

    ScrollView {
        OnlineStockCard(
            stockData: stockData,
            isLoading: false,
            error: nil,
            onRetailerTap: { retailer in
                print("Tapped: \(retailer.retailerName)")
            },
            onRefresh: {
                print("Refresh tapped")
            }
        )
        .padding()
    }
}

#Preview("Loading") {
    OnlineStockCard(
        stockData: nil,
        isLoading: true,
        error: nil
    )
    .padding()
}

#Preview("Error") {
    OnlineStockCard(
        stockData: nil,
        isLoading: false,
        error: StockDatabaseError.databaseNotInitialized
    )
    .padding()
}

#Preview("Empty") {
    let stockData = OnlineStockModel(
        itemStableId: "test123",
        retailers: [],
        lastUpdated: Date()
    )

    OnlineStockCard(
        stockData: stockData,
        isLoading: false,
        error: nil
    )
    .padding()
}

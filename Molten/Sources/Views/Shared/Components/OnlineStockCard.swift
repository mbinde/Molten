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

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            header

            if isLoading {
                loadingState
            } else if error != nil {
                errorState
            } else if let data = stockData {
                if data.retailers.isEmpty {
                    emptyState
                } else {
                    retailerList(data.retailers)
                }
            } else {
                emptyState
            }
        }
        .padding(DesignSystem.Padding.standard)
        .background(DesignSystem.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Online Availability", systemImage: "globe")
                .font(DesignSystem.Typography.subsectionTitle)
                .fontWeight(DesignSystem.FontWeight.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            if let data = stockData {
                if data.anyInStock {
                    Text("\(data.inStockCount) in stock")
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.accentSuccess)
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

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(DesignSystem.Colors.accentWarning)
            Text("Couldn't check availability")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("No retailer data available")
            .font(DesignSystem.Typography.listItemCaption)
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Retailer List

    private func retailerList(_ retailers: [RetailerStockModel]) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Sort: in-stock first, then low stock, then others
            ForEach(sortedRetailers(retailers)) { retailer in
                retailerRow(retailer)
            }
        }
    }

    private func sortedRetailers(_ retailers: [RetailerStockModel]) -> [RetailerStockModel] {
        retailers.sorted { lhs, rhs in
            // In stock items first
            if lhs.stockStatus.isAvailable && !rhs.stockStatus.isAvailable {
                return true
            }
            if !lhs.stockStatus.isAvailable && rhs.stockStatus.isAvailable {
                return false
            }
            // Then alphabetically by name
            return lhs.retailerName < rhs.retailerName
        }
    }

    // MARK: - Retailer Row

    private func retailerRow(_ retailer: RetailerStockModel) -> some View {
        Button {
            onRetailerTap?(retailer)
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Status indicator
                stockStatusIcon(retailer.stockStatus)

                // Retailer name
                Text(retailer.retailerName)
                    .font(DesignSystem.Typography.listItemSubtitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                // Price if available
                if let price = retailer.formattedPrice {
                    Text(price)
                        .font(DesignSystem.Typography.listItemCaption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Link indicator
                if retailer.productUrl != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .background(retailer.productUrl != nil ? DesignSystem.Colors.background : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(retailer.productUrl == nil)
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
            retailerCode: "bullseye",
            retailerName: "Bullseye Glass Co",
            stockStatus: .inStock,
            lastChecked: Date(),
            productUrl: "https://bullseye.com/product/123",
            price: 4.50,
            priceUnit: "rod",
            currency: "USD",
            quantityAvailable: 25
        ),
        RetailerStockModel(
            retailerCode: "frantz",
            retailerName: "Frantz Art Glass",
            stockStatus: .lowStock,
            lastChecked: Date(),
            productUrl: "https://frantz.com/product/123",
            price: 4.75,
            priceUnit: "rod",
            currency: "USD",
            quantityAvailable: 3
        ),
        RetailerStockModel(
            retailerCode: "delphi",
            retailerName: "Delphi Glass",
            stockStatus: .outOfStock,
            lastChecked: Date(),
            productUrl: "https://delphi.com/product/123",
            price: nil,
            priceUnit: nil,
            currency: nil,
            quantityAvailable: nil
        ),
        RetailerStockModel(
            retailerCode: "arrow",
            retailerName: "Arrow Springs",
            stockStatus: .unknown,
            lastChecked: Date(),
            productUrl: nil,
            price: nil,
            priceUnit: nil,
            currency: nil,
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
        error: OnlineStockAPIError.serverError(statusCode: 500)
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

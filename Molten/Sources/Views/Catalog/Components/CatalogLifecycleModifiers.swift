//
//  CatalogLifecycleModifiers.swift
//  Molten
//
//  View modifier for managing lifecycle events and notifications in CatalogView
//

import SwiftUI

struct CatalogLifecycleModifiers: ViewModifier {
    let userDefaults: UserDefaults
    @Binding var defaultSortOptionRawValue: String
    @Binding var enabledManufacturersData: Data
    @Binding var searchTitlesOnly: Bool
    @Binding var searchScope: CatalogSearchScope
    @Binding var selectedProductTypes: Set<String>
    @Binding var sortOption: SortOption
    let viewModel: CatalogViewModel
    let clearSearch: () -> Void
    let resetNavigation: () -> Void
    @Binding var catalogUpdateMessage: String
    @Binding var showCatalogUpdateToast: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .clearCatalogSearch)) { _ in
                clearSearch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetCatalogNavigation)) { _ in
                resetNavigation()
            }
            .onReceive(NotificationCenter.default.publisher(for: .ratingSubmitted)) { notification in
                // Reload catalog data when ratings are submitted or deleted
                print("🔔 [CatalogView] Received notification for: \(notification.object ?? "nil")")
                Task {
                    let ratingService = AppDependencies.shared.ratingService
                    let itemId = notification.object as? String

                    // IMPORTANT: Server needs time to rebuild bulk cache after invalidation.
                    // Retry fetching until we find the new rating or timeout after 3 seconds.
                    var freshRatings: [AggregatedRatingModel]?
                    var attempts = 0
                    let maxAttempts = 6  // 6 attempts × 500ms = 3 seconds max

                    while attempts < maxAttempts {
                        freshRatings = try? await ratingService.fetchAllRatingsBulk(forceRefresh: true)
                        // If we're looking for a specific item, check if it's in the results
                        if let itemId = itemId {
                            let itemRating = freshRatings?.first(where: { $0.itemStableId == itemId })
                            if let rating = itemRating {
                                break  // Success! Found the new rating
                            } else {
                                attempts += 1
                                if attempts < maxAttempts {
                                    try? await Task.sleep(nanoseconds: 500_000_000)  // Wait 500ms before retry
                                }
                            }
                        } else {
                            break  // No specific item to check for, just use what we got
                        }
                    }

                    // Then reload catalog with fresh ratings
                    await CatalogDataCache.shared.reload(catalogService: viewModel.catalogService)
                    await viewModel.loadData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .catalogUpdateCompleted)) { notification in
                // Reload catalog data when update completes
                Task {
                    await viewModel.loadData()

                    // Show toast notification
                    if let result = notification.object as? CatalogUpdateResult {
                        catalogUpdateMessage = "Catalog updated to v\(result.version)"
                        withAnimation {
                            showCatalogUpdateToast = true
                        }
                    }
                }
            }
            .onAppear {
                // Load settings from safe UserDefaults (isolated during testing)
                defaultSortOptionRawValue = userDefaults.string(forKey: "defaultSortOption") ?? SortOption.name.rawValue
                enabledManufacturersData = userDefaults.data(forKey: "enabledManufacturers") ?? Data()

                // Load search titles only setting (default: true)
                let titlesOnly = userDefaults.bool(forKey: "searchTitlesOnly") != false  // Default to true if not set
                searchTitlesOnly = titlesOnly
                searchScope = titlesOnly ? .titlesOnly : .allFields

                // Product types: empty set = show all (new behavior, no need to persist)

                // Initialize sort option from user settings
                sortOption = SortOption(rawValue: defaultSortOptionRawValue) ?? .name
            }
            .task {
                // MIGRATION: Load data from ViewModel
                await viewModel.loadData()
            }
    }
}

//
//  SentryTestView.swift
//  Molten
//
//  Debug view for testing Sentry error logging integration
//

import SwiftUI

struct SentryTestView: View {
    @State private var lastTestTime: Date?
    @State private var showingSuccessAlert = false

    private let logger: LoggingService

    init(logger: LoggingService = AppDependencies.shared.loggingService) {
        self.logger = logger
    }

    var body: some View {
        List {
            Section {
                Text("Test your Sentry integration by sending sample errors. These will appear in your Sentry dashboard within seconds.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } header: {
                Text("Sentry Testing")
            }

            Section {
                Button {
                    testCatalogDownloadError()
                } label: {
                    Label("Test Catalog Download Error", systemImage: "arrow.down.circle")
                }

                Button {
                    testCatalogDownloadSuccess()
                } label: {
                    Label("Test Catalog Download Success", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                }
            } header: {
                Text("Catalog Download (operation:catalog-download)")
            } footer: {
                Text("Simulates catalog download events. Check Sentry for 'operation:catalog-download' filter.")
            }

            Section {
                Button {
                    testRatingCacheError()
                } label: {
                    Label("Test Rating Cache Error", systemImage: "star.slash")
                }

                Button {
                    testRatingCacheSuccess()
                } label: {
                    Label("Test Rating Cache Success", systemImage: "star.fill")
                        .foregroundColor(.green)
                }

                Button {
                    testRatingCacheDegraded()
                } label: {
                    Label("Test Rating Cache Warning", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            } header: {
                Text("Rating Cache (operation:rating-cache-rebuild)")
            } footer: {
                Text("Simulates rating cache operations. Check Sentry for 'operation:rating-cache-rebuild' filter.")
            }

            Section {
                Button {
                    testCloudKitSyncError()
                } label: {
                    Label("Test CloudKit Sync Error", systemImage: "icloud.slash")
                }

                Button {
                    testCloudKitQuotaExceeded()
                } label: {
                    Label("Test CloudKit Quota Exceeded", systemImage: "externaldrive.fill.badge.exclamationmark")
                        .foregroundColor(.red)
                }

                Button {
                    testCloudKitOffline()
                } label: {
                    Label("Test CloudKit Offline", systemImage: "wifi.slash")
                        .foregroundColor(.orange)
                }
            } header: {
                Text("CloudKit Sync (operation:cloudkit-sync)")
            } footer: {
                Text("Simulates CloudKit sync issues. Check Sentry for 'operation:cloudkit-sync' filter.")
            }

            Section {
                Button {
                    testAllErrors()
                } label: {
                    Label("Send All Test Errors", systemImage: "exclamationmark.octagon.fill")
                        .foregroundColor(.red)
                }
            } footer: {
                Text("Sends one of each error type to test dashboard aggregation.")
            }

            if let lastTest = lastTestTime {
                Section {
                    HStack {
                        Text("Last Test:")
                        Spacer()
                        Text(lastTest, style: .relative)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .navigationTitle("Test Sentry")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Event Sent", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Check your Sentry dashboard to see the event.")
        }
    }

    // MARK: - Test Methods

    private func testCatalogDownloadError() {
        logger.error("Test catalog download failure", context: [
            "operation": "catalog-download",
            "version": "1.2.3",
            "progress": 0.75,
            "error_type": "NetworkTimeout",
            "file_size_mb": 25.5,
            "test": true
        ])
        recordTestSent()
    }

    private func testCatalogDownloadSuccess() {
        logger.info("Catalog download completed successfully", context: [
            "operation": "catalog-download",
            "version": "1.2.3",
            "item_count": 2659,
            "file_size_mb": 25.5,
            "test": true
        ])
        recordTestSent()
    }

    private func testRatingCacheError() {
        logger.error("Rating cache rebuild failed", context: [
            "operation": "rating-cache-rebuild",
            "items_requested": 100,
            "had_cached_data": false,
            "error_type": "APITimeout",
            "test": true
        ])
        recordTestSent()
    }

    private func testRatingCacheSuccess() {
        logger.info("Rating cache updated successfully", context: [
            "operation": "rating-cache-rebuild",
            "items_updated": 100,
            "forced_refresh": false,
            "test": true
        ])
        recordTestSent()
    }

    private func testRatingCacheDegraded() {
        logger.warning("Rating fetch failed, using stale cache", context: [
            "operation": "rating-cache-rebuild",
            "items_requested": 100,
            "stale_items_returned": 95,
            "test": true
        ])
        recordTestSent()
    }

    private func testCloudKitSyncError() {
        logger.error("CloudKit sync failed", context: [
            "operation": "cloudkit-sync",
            "sync_type": "import",
            "error_domain": "CKErrorDomain",
            "error_code": 2,
            "error_type": "CKError",
            "test": true
        ])
        recordTestSent()
    }

    private func testCloudKitQuotaExceeded() {
        logger.error("CloudKit quota exceeded", context: [
            "operation": "cloudkit-sync",
            "sync_type": "import",
            "error_code": 10,
            "test": true
        ])
        recordTestSent()
    }

    private func testCloudKitOffline() {
        logger.warning("CloudKit sync offline", context: [
            "operation": "cloudkit-sync",
            "sync_type": "import",
            "error_code": 3,
            "test": true
        ])
        recordTestSent()
    }

    private func testAllErrors() {
        testCatalogDownloadError()
        testRatingCacheError()
        testCloudKitSyncError()
        testCloudKitQuotaExceeded()

        // Small delay between events
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingSuccessAlert = true
        }
    }

    private func recordTestSent() {
        lastTestTime = Date()
        showingSuccessAlert = true
    }
}

#Preview {
    NavigationStack {
        SentryTestView()
    }
}

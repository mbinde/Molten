//
//  SubscriptionManagementView.swift
//  Molten
//
//  Extracted from SettingsView.swift
//

import SwiftUI

struct SubscriptionManagementView: View {
    @Environment(EntitlementService.self) private var entitlementService
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var showingUpgradePrompt = false

    var body: some View {
        List {
            // Current tier section
            Section {
                HStack {
                    if entitlementService.tier == .premium {
                        Image(systemName: "crown.fill")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                    } else {
                        Image(systemName: "star.circle")
                            .font(.largeTitle)
                            .foregroundColor(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entitlementService.tier == .premium ? "Premium Member" : "Free Tier")
                            .font(.title2.bold())

                        if entitlementService.tier == .premium {
                            Text("Unlimited access to all features")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Limited to free tier features")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                }
                .padding(.vertical, 8)
            }

            // Usage section
            Section("Current Usage") {
                UsageRow(
                    icon: "cube.box",
                    title: "Inventory Items",
                    current: 0,  // TODO: Get actual count
                    limit: entitlementService.getInventoryLimit()
                )

                UsageRow(
                    icon: "cart",
                    title: "Shopping List Items",
                    current: 0,  // TODO: Get actual count
                    limit: entitlementService.getShoppingListLimit()
                )

                UsageRow(
                    icon: "folder",
                    title: "Projects",
                    current: 0,  // TODO: Get actual count
                    limit: entitlementService.getProjectsLimit()
                )

                UsageRow(
                    icon: "book",
                    title: "Logbook Entries",
                    current: 0,  // TODO: Get actual count
                    limit: entitlementService.getLogbookEntriesLimit()
                )
            }

            // Actions section
            if entitlementService.tier == .free {
                Section {
                    Button(action: {
                        showingUpgradePrompt = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                            Text("Upgrade to Premium")
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Upgrade")
                } footer: {
                    Text("Unlock unlimited inventory, shopping lists, projects, and logbook entries plus premium features.")
                }
            } else {
                Section {
                    Button(action: {
                        #if os(iOS)
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                        #endif
                    }) {
                        Label("Manage Subscription in App Store", systemImage: "gear")
                    }

                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }) {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Manage")
                }
            }

            // Premium features section
            Section("Premium Features") {
                FeatureRow(icon: "infinity", title: "Unlimited Inventory Items")
                FeatureRow(icon: "cart.fill", title: "Unlimited Shopping Lists")
                FeatureRow(icon: "folder.fill", title: "Unlimited Projects")
                FeatureRow(icon: "book.fill", title: "Unlimited Logbook Entries")
                FeatureRow(icon: "printer.fill", title: "Batch Label Printing")
                FeatureRow(icon: "qrcode.viewfinder", title: "QR Code Scanning for Inventory")
                FeatureRow(icon: "tag.fill", title: "Custom Tags & Notes for Inventory")
                FeatureRow(icon: "photo.fill", title: "Add Images to Inventory Items")
            }
        }
        .navigationTitle("Subscription")
        .sheet(isPresented: $showingUpgradePrompt) {
            UpgradePromptView(
                feature: "subscription",
                currentCount: 0,
                limit: 0
            )
        }
    }
}

//
//  PurchasesView.swift
//  Molten
//
//  Main view for the Purchases tab - shows purchase import workflow
//  Either displays setup instructions or the list of imported purchases
//

import SwiftUI

struct PurchasesView: View {
    @Environment(\.appDependencies) private var dependencies
    @State private var showingSettings = false

    // Observe the receipt service directly to get UI updates
    @ObservedObject private var receiptService: ReceiptService

    init() {
        _receiptService = ObservedObject(wrappedValue: AppDependencies.shared.receiptService)
    }

    var body: some View {
        NavigationStack {
            Group {
                if receiptService.isSetUp {
                    // Purchase import is enabled - show purchases list
                    PurchaseListView(showingHelp: $showingSettings)
                } else {
                    // Not set up yet - show onboarding
                    PurchaseOnboardingView(showingSettings: $showingSettings)
                }
            }
            .navigationTitle("Purchases")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    PurchaseImportSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingSettings = false
                                }
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Purchase Onboarding View

private struct PurchaseOnboardingView: View {
    @Binding var showingSettings: Bool

    var body: some View {
        List {
            Section {
                Text("Automatically track your glass purchases by forwarding order confirmation emails.")
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Section("How it works") {
                OnboardingStepRow(
                    icon: "1.circle.fill",
                    title: "Get your import email",
                    description: "Enable purchase imports to get a unique email address"
                )

                OnboardingStepRow(
                    icon: "2.circle.fill",
                    title: "Forward order emails",
                    description: "Forward order confirmations from glass suppliers"
                )

                OnboardingStepRow(
                    icon: "3.circle.fill",
                    title: "Review & import",
                    description: "View parsed items and add them to your inventory"
                )
            }

            Section {
                Button {
                    showingSettings = true
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - Onboarding Step Row

private struct OnboardingStepRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.moltenOrange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    PurchasesView()
}

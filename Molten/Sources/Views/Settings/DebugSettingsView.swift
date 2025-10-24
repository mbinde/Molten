//
//  DebugSettingsView.swift
//  Molten
//
//  Created by Assistant on 10/19/25.
//

import SwiftUI

struct DebugSettingsView: View {
    @AppStorage("showDebugInfo") private var showDebugInfo = false
    @State private var showingResetDisclaimerAlert = false
    @State private var showingResetTerminologyAlert = false

    private let catalogService: CatalogService

    init(catalogService: CatalogService = RepositoryFactory.createCatalogService()) {
        self.catalogService = catalogService
    }

    var body: some View {
        List {
            Section {
                Toggle("Show Debug Information", isOn: $showDebugInfo)
                    .help("Show additional debug information throughout the app")
            } header: {
                Text("Display")
            }

            Section {
                Button {
                    showingResetDisclaimerAlert = true
                } label: {
                    Label("Reset Alpha Disclaimer", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }

                Button {
                    showingResetTerminologyAlert = true
                } label: {
                    Label("Reset Terminology Onboarding", systemImage: "text.bubble")
                        .foregroundColor(.blue)
                }
            } header: {
                Text("Onboarding & Disclaimers")
            } footer: {
                Text("Reset onboarding screens to test the first-run experience. The disclaimer or onboarding will show again on next app launch.")
            }

            Section {
                NavigationLink {
                    DataManagementView(catalogService: catalogService)
                } label: {
                    Label("Data Management", systemImage: "externaldrive")
                }

                NavigationLink {
                    TestDataGeneratorView()
                } label: {
                    Label("Test Data Generator", systemImage: "wand.and.stars")
                }

                NavigationLink {
                    CoreDataDiagnosticView()
                } label: {
                    Label("Core Data Diagnostics", systemImage: "stethoscope")
                }
            } header: {
                Text("Data Tools")
            } footer: {
                Text("Tools for managing catalog data, generating test inventory, and diagnosing Core Data issues.")
            }
        }
        .navigationTitle("Debug Settings")
        .alert("Reset Alpha Disclaimer", isPresented: $showingResetDisclaimerAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAlphaDisclaimer()
            }
        } message: {
            Text("This will reset the alpha disclaimer acknowledgment. The disclaimer will appear again on next app launch.")
        }
        .alert("Reset Terminology Onboarding", isPresented: $showingResetTerminologyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetTerminologyOnboarding()
            }
        } message: {
            Text("This will reset the terminology onboarding. You'll see the onboarding screen again on next app launch.")
        }
    }

    private func resetAlphaDisclaimer() {
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedAlphaDisclaimer")
        print("✅ Reset alpha disclaimer - will show on next launch")
    }

    private func resetTerminologyOnboarding() {
        GlassTerminologySettings.shared.hasCompletedOnboarding = false
        print("✅ Reset terminology onboarding - will show on next launch")
    }
}

#Preview {
    NavigationStack {
        DebugSettingsView()
    }
}

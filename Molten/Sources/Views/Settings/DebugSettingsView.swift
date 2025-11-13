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
    @ObservedObject private var catalogPreferences = CatalogUpdatePreferences.shared

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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Glass Catalog:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("v\(catalogPreferences.glassCatalogVersion)")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Tools Catalog:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("v\(catalogPreferences.toolsCatalogVersion)")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Coatings Catalog:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("v\(catalogPreferences.coatingsCatalogVersion)")
                            .fontWeight(.medium)
                    }

                    if let lastUpdate = catalogPreferences.lastSuccessfulUpdate {
                        HStack {
                            Text("Last Update:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(lastUpdate, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            } header: {
                Text("Catalog Versions")
            } footer: {
                Text("Catalog versions currently loaded in the app. Glass catalog v0 means bundled catalog is being used.")
            }

            Section {
                Button {
                    showingResetDisclaimerAlert = true
                } label: {
                    Label("Reset Alpha Disclaimer", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
            } header: {
                Text("Onboarding & Disclaimers")
            } footer: {
                Text("Reset the alpha disclaimer to test the first-run experience. The disclaimer will show again on next app launch.")
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
    }

    private func resetAlphaDisclaimer() {
        UserDefaults.standard.removeObject(forKey: "hasAcknowledgedAlphaDisclaimer")
        print("✅ Reset alpha disclaimer - will show on next launch")
    }
}

#Preview {
    NavigationStack {
        DebugSettingsView()
    }
}

//
//  SettingsView.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import SwiftUI

// MARK: - Release Configuration
// Set to false for simplified release builds
private let isAdvancedFeaturesEnabled = false

struct SettingsView: View {
    @AppStorage("defaultSortOption") private var defaultSortOptionRawValue = SortOption.name.rawValue
    @AppStorage("defaultInventorySortOption") private var defaultInventorySortOptionRawValue = "Name"
    @AppStorage("defaultUnits") private var defaultUnitsRawValue = DefaultUnits.pounds.rawValue
    @AppStorage("showRatingsInCatalog") private var showRatingsInCatalog = true
    @Environment(EntitlementService.self) private var entitlementService
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private let catalogService: CatalogService
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var subscriptionViewModel: SubscriptionViewModel
    @State private var catalogUpdateViewModel: CatalogUpdateViewModel

    init(
        catalogService: CatalogService = AppDependencies().catalogService,
        subscriptionService: SubscriptionServiceProtocol = AppDependencies().subscriptionService,
        catalogUpdateService: CatalogUpdateService? = nil
    ) {
        self.catalogService = catalogService
        self.subscriptionService = subscriptionService
        self._subscriptionViewModel = State(initialValue: SubscriptionViewModel(subscriptionService: subscriptionService))

        // Initialize catalog update view model
        let updateService = catalogUpdateService ?? CatalogUpdateService(
            apiClient: CatalogAPIClient(),
            storageService: try! CatalogStorageService(),
            networkMonitor: NetworkMonitor.shared
        )
        self._catalogUpdateViewModel = State(initialValue: CatalogUpdateViewModel(updateService: updateService))
    }

    private var defaultSortOptionBinding: Binding<SortOption> {
        Binding(
            get: { SortOption(rawValue: defaultSortOptionRawValue) ?? .name },
            set: { defaultSortOptionRawValue = $0.rawValue }
        )
    }

    private var defaultInventorySortOptionBinding: Binding<String> {
        Binding(
            get: { defaultInventorySortOptionRawValue },
            set: { defaultInventorySortOptionRawValue = $0 }
        )
    }

    private var defaultUnitsBinding: Binding<DefaultUnits> {
        Binding(
            get: { DefaultUnits(rawValue: defaultUnitsRawValue) ?? .pounds },
            set: { defaultUnitsRawValue = $0.rawValue }
        )
    }

    // Subscription computed properties
    private var subscriptionIcon: String {
        subscriptionViewModel.hasProAccess ? "star.fill" : "star"
    }

    private var subscriptionBadge: String {
        subscriptionViewModel.hasProAccess ? "Pro" : "Free"
    }

    private var subscriptionBadgeColor: Color {
        subscriptionViewModel.hasProAccess ? .white : .blue
    }

    private var subscriptionBadgeBackground: Color {
        subscriptionViewModel.hasProAccess ? .yellow : .blue.opacity(0.2)
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - General
                Section("General") {
                    Picker("Appearance", selection: Binding(
                        get: { UserSettings.shared.appearanceMode },
                        set: { UserSettings.shared.appearanceMode = $0 }
                    )) {
                        ForEach(UserSettings.AppearanceMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    NavigationLink {
                        TabCustomizationView()
                    } label: {
                        Label("Customize Tabs", systemImage: "square.grid.2x2")
                    }

                    Picker("Temperature Unit", selection: Binding(
                        get: { UserSettings.shared.preferredTemperatureUnit },
                        set: { UserSettings.shared.preferredTemperatureUnit = $0 }
                    )) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("Choose your preferred temperature unit for displaying kiln schedules")
                }

                // MARK: - Catalog & Display
                Section("Catalog & Display") {
                    NavigationLink {
                        CatalogInfoView(viewModel: catalogUpdateViewModel)
                    } label: {
                        HStack {
                            Label("Catalog Updates", systemImage: "arrow.down.circle")

                            Spacer()

                            if let updateMessage = catalogUpdateViewModel.updateAvailableMessage {
                                Text(updateMessage)
                                    .font(.caption)
                                    .foregroundColor(Color.accentColor)
                            } else {
                                Text("v\(catalogUpdateViewModel.currentVersion)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    HStack {
                        Picker("Default Catalog Sort Order", selection: defaultSortOptionBinding) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Picker("Default Inventory Sort Order", selection: defaultInventorySortOptionBinding) {
                            Text("Name").tag("Name")
                            Text("Inventory Count").tag("Inventory Count")
                            Text("Buy Count").tag("Buy Count")
                            Text("Sell Count").tag("Sell Count")
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle("Expand Manufacturer Descriptions by Default", isOn: Binding(
                        get: { UserSettings.shared.expandManufacturerDescriptionsByDefault },
                        set: { UserSettings.shared.expandManufacturerDescriptionsByDefault = $0 }
                    ))
                    .help("When enabled, manufacturer descriptions in item detail views will be fully expanded by default")

                    Toggle("Expand My Notes by Default", isOn: Binding(
                        get: { UserSettings.shared.expandUserNotesByDefault },
                        set: { UserSettings.shared.expandUserNotesByDefault = $0 }
                    ))
                    .help("When enabled, your personal notes in item detail views will be fully expanded by default")

                    Picker("Project Thumbnail Style", selection: Binding(
                        get: { UserSettings.shared.thumbnailDisplayMode },
                        set: { UserSettings.shared.thumbnailDisplayMode = $0 }
                    )) {
                        ForEach(UserSettings.ThumbnailDisplayMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .help("Choose how project thumbnails are displayed: Fit preserves aspect ratio, Fill crops to square")

                    Toggle("Show Ratings in Catalog", isOn: $showRatingsInCatalog)
                        .help("When enabled, star ratings and review counts will be displayed in catalog and inventory lists")
                }

                // MARK: - Filtering
                Section("Filtering") {
                    NavigationLink {
                        COEFilterView()
                    } label: {
                        Label("COE Filter", systemImage: "flame")
                    }

                    NavigationLink {
                        ManufacturerFilterView()
                    } label: {
                        Label("Manufacturer Filter", systemImage: "building.2")
                    }

                    Toggle("Show User Tags in Filters", isOn: Binding(
                        get: { UserSettings.shared.showUserTagsInFilter },
                        set: { UserSettings.shared.showUserTagsInFilter = $0 }
                    ))
                    .help("When enabled, user-created tags will appear in the tag filter menu")

                    Toggle("Show Technical Tags in Filters", isOn: Binding(
                        get: { UserSettings.shared.showTechnicalTagsInFilter },
                        set: { UserSettings.shared.showTechnicalTagsInFilter = $0 }
                    ))
                    .help("When enabled, technical property tags (reducing, seeded, reactive, striker, uv, cfl, luster, etc.) will appear in the tag filter menu")
                }

                // MARK: - Content & Customization
                Section {
                    NavigationLink {
                        AuthorSettingsView()
                    } label: {
                        Label("Author Information", systemImage: "person.circle")
                    }

                    NavigationLink {
                        TerminologySettingsView()
                    } label: {
                        Label("Glass Working Terminology", systemImage: "text.bubble")
                    }

                    NavigationLink {
                        RatingSettingsView()
                    } label: {
                        Label("Manage Ratings", systemImage: "star")
                    }

                    HStack {
                        Text("Inventory Owner")
                        Spacer()
                        TextField("Optional", text: Binding(
                            get: { UserSettings.shared.inventoryOwner ?? "" },
                            set: { UserSettings.shared.inventoryOwner = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .multilineTextAlignment(.trailing)
                    }
                    .help("Optional name to display on inventory labels (e.g., studio name or artist name)")
                } header: {
                    Text("Content & Customization")
                } footer: {
                    Text("Customize how you interact with your content. The inventory owner will appear on printed labels when set.")
                }

                // MARK: - Media & Data
                Section("Media & Data") {
                    NavigationLink {
                        ImageQualitySettingsView()
                    } label: {
                        Label("Image Quality & Cache", systemImage: "photo.on.rectangle.angled")
                    }

                    NavigationLink {
                        DataExportView()
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                }

                // MARK: - Kiln
                Section("Kiln") {
                    NavigationLink {
                        KilnRatesSettingsView()
                    } label: {
                        Label("Kiln Max Rates", systemImage: "gauge.with.dots.needle.67percent")
                    }
                }

                // MARK: - Subscription
                Section("Subscription") {
                    NavigationLink {
                        SubscriptionStatusView(viewModel: subscriptionViewModel)
                    } label: {
                        HStack {
                            Label("Manage Subscription", systemImage: subscriptionIcon)
                            Spacer()
                            Text(subscriptionBadge)
                                .font(.caption.bold())
                                .foregroundColor(subscriptionBadgeColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(subscriptionBadgeBackground)
                                .cornerRadius(6)
                        }
                    }
                }
                .task {
                    // Load subscription status when settings view appears
                    await subscriptionViewModel.loadSubscriptionStatus()
                }

                // MARK: - Advanced
                Section("Advanced") {
                    NavigationLink {
                        DebugSettingsView()
                    } label: {
                        Label("Debug Settings", systemImage: "ladybug")
                    }

                    NavigationLink {
                        SentryTestView()
                    } label: {
                        Label("Test Sentry Logging", systemImage: "ant.circle")
                    }

                    // Subscription tier override for testing
                    Toggle(isOn: Binding(
                        get: { DebugConfig.debugOverrideSubscriptionTier },
                        set: { DebugConfig.debugOverrideSubscriptionTier = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Override Subscription Tier")
                                .font(.body)
                            Text("Test premium features without purchase")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if DebugConfig.debugOverrideSubscriptionTier {
                        Picker("Debug Tier", selection: Binding(
                            get: { DebugConfig.debugSubscriptionTierValue },
                            set: { DebugConfig.debugSubscriptionTierValue = $0 }
                        )) {
                            Text("Free").tag(0)
                            Text("Premium").tag(1)
                        }
                        .pickerStyle(.segmented)

                        // Show current tier status
                        HStack {
                            Image(systemName: entitlementService.currentTier == .premium ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(entitlementService.currentTier == .premium ? .green : .secondary)
                            Text("Current Tier: \(entitlementService.currentTier == .premium ? "Premium" : "Free")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - SortOption Extension
extension SortOption {
    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .manufacturer:
            return "Manufacturer"
        case .code:
            return "Code"
        case .rating:
            return "Rating"
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}

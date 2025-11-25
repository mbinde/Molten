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
    @AppStorage("defaultUnits") private var defaultUnitsRawValue = DefaultUnits.grams.rawValue
    @AppStorage("defaultDimensionUnits") private var defaultDimensionUnitsRawValue = DefaultDimensionUnits.metric.rawValue
    @AppStorage("showRatingsInCatalog") private var showRatingsInCatalog = true
    @AppStorage("appearanceMode") private var appearanceModeString: String = "system"
    @Environment(EntitlementService.self) private var entitlementService
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private var selectedAppearanceMode: Binding<UserSettings.AppearanceMode> {
        Binding(
            get: { UserSettings.AppearanceMode(rawValue: appearanceModeString) ?? .system },
            set: { appearanceModeString = $0.rawValue }
        )
    }

    private let catalogService: CatalogService
    private let subscriptionService: SubscriptionServiceProtocol
    @State private var subscriptionViewModel: SubscriptionViewModel
    @State private var catalogUpdateViewModel: CatalogUpdateViewModel
    @State private var thumbnailDisplayMode: UserSettings.ThumbnailDisplayMode = UserSettings.shared.thumbnailDisplayMode
    @State private var colorChipDisplayMode: UserSettings.ColorChipDisplayMode = UserSettings.shared.colorChipDisplayMode

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
            get: { DefaultUnits(rawValue: defaultUnitsRawValue) ?? .grams },
            set: { defaultUnitsRawValue = $0.rawValue }
        )
    }

    private var defaultDimensionUnitsBinding: Binding<DefaultDimensionUnits> {
        Binding(
            get: { DefaultDimensionUnits(rawValue: defaultDimensionUnitsRawValue) ?? .metric },
            set: { defaultDimensionUnitsRawValue = $0.rawValue }
        )
    }

    private var thumbnailDisplayModeBinding: Binding<UserSettings.ThumbnailDisplayMode> {
        Binding(
            get: { thumbnailDisplayMode },
            set: {
                thumbnailDisplayMode = $0
                UserSettings.shared.thumbnailDisplayMode = $0
            }
        )
    }

    private var colorChipDisplayModeBinding: Binding<UserSettings.ColorChipDisplayMode> {
        Binding(
            get: { colorChipDisplayMode },
            set: {
                colorChipDisplayMode = $0
                UserSettings.shared.colorChipDisplayMode = $0
            }
        )
    }

    // Subscription computed properties
    private var subscriptionBadge: String {
        subscriptionViewModel.hasProAccess ? "Pro" : "Free"
    }

    private var subscriptionBadgeColor: Color {
        subscriptionViewModel.hasProAccess ? .white : .blue
    }

    private var subscriptionBadgeBackground: Color {
        subscriptionViewModel.hasProAccess ? .yellow : .blue.opacity(0.2)
    }

    private var colorScheme: ColorScheme? {
        guard let mode = UserSettings.AppearanceMode(rawValue: appearanceModeString) else {
            return nil
        }
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - General
                Section("General") {
                    Picker("Appearance", selection: selectedAppearanceMode) {
                        ForEach(UserSettings.AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    NavigationLink {
                        TabCustomizationView()
                    } label: {
                        Text("Customize Tabs")
                    }
                    .accessibilityIdentifier("settings_customize_tabs")

                }

                // MARK: - Catalog and Inventory Settings
                Section("Catalog and Inventory Settings") {
                    Picker("Weight Unit", selection: defaultUnitsBinding) {
                        ForEach(DefaultUnits.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Dimension Unit", selection: defaultDimensionUnitsBinding) {
                        ForEach(DefaultDimensionUnits.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    NavigationLink {
                        CatalogInfoView(viewModel: catalogUpdateViewModel)
                    } label: {
                        HStack {
                            Text("Catalog Updates")

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
                    .accessibilityIdentifier("settings_catalog_updates")

                    VStack(alignment: .leading, spacing: 4) {
                        Picker("Show Color Chips", selection: colorChipDisplayModeBinding) {
                            ForEach(UserSettings.ColorChipDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(colorChipDisplayMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
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

                    Toggle("Show Ratings in Catalog", isOn: $showRatingsInCatalog)
                        .help("When enabled, star ratings and review counts will be displayed in catalog and inventory lists")
                        .accessibilityIdentifier("settings_show_ratings")
                }

                // MARK: - Sorting and Filtering
                Section("Sorting and Filtering") {
                    HStack {
                        Picker("Default Catalog Sort Order", selection: defaultSortOptionBinding) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
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
                
                // MARK: - Reduce Catalog Size
                Section("Reduce Catalog Size") {
                    NavigationLink {
                        COEFilterView()
                    } label: {
                        Text("COE Filter")
                    }
                    
                    NavigationLink {
                        ManufacturerFilterView()
                    } label: {
                        Text("Manufacturer Filter")
                    }
                    Toggle("Apply these filters to Inventory and Shopping List", isOn: Binding(
                        get: { UserSettings.shared.applyFiltersToInventory },
                        set: { UserSettings.shared.applyFiltersToInventory = $0 }
                    ))
                    .help("When enabled, the COE filter and Manufacturer filter show here will also limit what is shown in your inventory and your shopping list. This may make some of your items in those two lists invisible unless you re-enable their COEs or Manufacturers here.")
                }

                // MARK: - Content & Customization
                Section {
                    NavigationLink {
                        AuthorSettingsView()
                    } label: {
                        Text("Author Information")
                    }

                    NavigationLink {
                        TerminologySettingsView()
                    } label: {
                        Text("Glass Working Terminology")
                    }

                    NavigationLink {
                        RatingSettingsView()
                    } label: {
                        Text("Manage Ratings")
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
                    .help("Optional name to display on inventory labels (e.g., store name, studio name or artist name)")
                } header: {
                    Text("Content & Customization")
                }

                // MARK: - Projects and Logs
                if FeatureFlags.ENABLE_PROJECTS {
                    Section("Projects and Logs") {
                        VStack(alignment: .leading, spacing: 4) {
                            Picker("Project Thumbnail Style", selection: thumbnailDisplayModeBinding) {
                                ForEach(UserSettings.ThumbnailDisplayMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)

                            Text(thumbnailDisplayMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: - Kiln
                if FeatureFlags.ENABLE_KILN_SCHEDULES {
                    Section("Kiln") {
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

                        NavigationLink {
                            KilnRatesSettingsView()
                        } label: {
                            Text("Kiln Max Rates")
                        }
                    }
                }

                // MARK: - Media & Data
                Section("Media & Data") {
                    NavigationLink {
                        ImageQualitySettingsView()
                    } label: {
                        Text("Image Quality & Cache")
                    }

                    NavigationLink {
                        DataExportView()
                    } label: {
                        Text("Export Data")
                    }

                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        HStack {
                            Text("Automatic Backups")
                            Spacer()
                            if BackupPreferences().isEnabled {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                // MARK: - Subscription
                Section("Subscription") {
                    NavigationLink {
                        SubscriptionStatusView(viewModel: subscriptionViewModel)
                    } label: {
                        HStack {
                            Text("Manage Subscription")
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
                        Text("Debug Settings")
                    }

                    NavigationLink {
                        SentryTestView()
                    } label: {
                        Text("Test Sentry Logging")
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
                        Text("About")
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .preferredColorScheme(colorScheme)
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
            return "SKU"
        case .rating:
            return "Rating"
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}

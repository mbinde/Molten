//
//  ViewUtilities.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import SwiftUI
import CoreData

/// Utilities for common view patterns and operations

// MARK: - Core Data Operations

struct CoreDataOperations {
    
    /// Safely delete items with animation and error handling
    static func deleteItems<T: NSManagedObject>(
        _ items: [T],
        at offsets: IndexSet,
        in context: NSManagedObjectContext,
        with animation: Animation = .default
    ) {
        withAnimation(animation) {
            offsets.forEach { index in
                if index < items.count {
                    context.delete(items[index])
                }
            }
            
            do {
                try CoreDataHelpers.safeSave(context: context, description: "deleted \(offsets.count) items")
            } catch {
                print("❌ Error in bulk delete operation: \(error)")
            }
        }
    }
    
    /// Delete all items of a specific type
    static func deleteAll<T: NSManagedObject>(
        ofType type: T.Type,
        from items: [T],
        in context: NSManagedObjectContext,
        with animation: Animation = .default
    ) {
        withAnimation(animation) {
            items.forEach { item in
                context.delete(item)
            }
            
            do {
                try CoreDataHelpers.safeSave(context: context, description: "deleted all \(items.count) \(String(describing: type)) items")
            } catch {
                print("❌ Error in delete all operation: \(error)")
            }
        }
    }
    
    /// Create and save a new managed object
    static func createAndSave<T: NSManagedObject>(
        _ type: T.Type,
        in context: NSManagedObjectContext,
        configure: (T) -> Void
    ) throws -> T {
        let newItem = T(context: context)
        configure(newItem)
        
        try CoreDataHelpers.safeSave(context: context, description: "new \(String(describing: type))")
        return newItem
    }
}

// MARK: - Empty State Views

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String?
    let buttonAction: (() -> Void)?
    let features: [FeatureDescription]?
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil,
        features: [FeatureDescription]? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
        self.features = features
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let buttonTitle = buttonTitle, let action = buttonAction {
                Button {
                    action()
                } label: {
                    Label(buttonTitle, systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top)
            }
            
            if let features = features {
                Spacer()
                
                FeatureListView(features: features)
            }
        }
        .padding()
    }
}

struct SearchEmptyStateView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("No items match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Feature Description

struct FeatureDescription {
    let title: String
    let icon: String
}

struct FeatureListView: View {
    let features: [FeatureDescription]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(features.indices, id: \.self) { index in
                    Label(features[index].title, systemImage: features[index].icon)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Loading States

struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView(message)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Async Operation Handler

struct AsyncOperationHandler {
    
    /// Standardized async operation with loading state management
    static func perform(
        operation: @escaping () async throws -> Void,
        operationName: String,
        loadingState: Binding<Bool>
    ) {
        Task { @MainActor in
            // Atomic check and set to prevent race condition
            guard !loadingState.wrappedValue else {
                print("⚠️ Already loading data, skipping \(operationName) request")
                return
            }
            
            // Immediately set loading state after successful guard check
            loadingState.wrappedValue = true
            
            do {
                try await operation()
                print("✅ \(operationName) completed successfully")
            } catch {
                print("❌ \(operationName) failed: \(error)")
            }
            
            // Always reset loading state
            loadingState.wrappedValue = false
        }
    }
}

// MARK: - Swipe Actions

struct SwipeActionsBuilder {
    
    /// Create delete and favorite swipe actions for inventory items
    /// Note: Requires InventoryItem to be defined in your Core Data model
    @ViewBuilder
    static func inventoryItemActions<Item>(
        item: Item,
        onDelete: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void
    ) -> some View {
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
        
        // TODO: Implement favorite functionality in InventoryService
        Button {
            onToggleFavorite()
        } label: {
            Label("Favorite", systemImage: "heart")
        }
        .tint(.pink)
    }
}

// MARK: - Alert Builders

struct AlertBuilders {
    
    /// Standard deletion confirmation alert
    static func deletionConfirmation(
        title: String,
        message: String,
        itemCount: Int,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> Alert {
        Alert(
            title: Text(title),
            message: Text(message.replacingOccurrences(of: "{count}", with: "\(itemCount)")),
            primaryButton: .cancel(),
            secondaryButton: .destructive(Text("Delete")) {
                onConfirm()
            }
        )
    }
    
    /// Standard error alert
    static func error(
        message: String,
        isPresented: Binding<Bool>
    ) -> Alert {
        Alert(
            title: Text("Error"),
            message: Text(message),
            dismissButton: .default(Text("OK"))
        )
    }
}

// MARK: - Common View Modifiers

extension View {
    
    /// Apply standard navigation setup for list views
    func standardListNavigation(
        title: String,
        searchText: Binding<String>,
        searchPrompt: String,
        primaryAction: @escaping () -> Void,
        primaryActionIcon: String = "plus"
    ) -> some View {
        self
            .navigationTitle(title)
            .searchable(text: searchText, prompt: searchPrompt)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        primaryAction()
                    } label: {
                        Label("Add Item", systemImage: primaryActionIcon)
                    }
                }
            }
    }
    
    /// Apply loading overlay
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay {
            LoadingOverlay(isLoading: isLoading, message: message)
        }
    }
}

// MARK: - Bundle Utilities

struct BundleUtilities {
    
    /// Debug bundle contents with consistent error handling
    static func debugContents() -> [String] {
        guard let bundlePath = Bundle.main.resourcePath else {
            print("❌ Could not get bundle resource path")
            return []
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            print("📁 Bundle contents:")
            for item in contents.sorted() {
                print("   - \(item)")
            }
            
            // Check specifically for JSON files
            let jsonFiles = contents.filter { $0.hasSuffix(".json") }
            print("📄 JSON files found: \(jsonFiles)")
            
            return contents
        } catch {
            print("❌ Error reading bundle contents: \(error)")
            return []
        }
    }
}
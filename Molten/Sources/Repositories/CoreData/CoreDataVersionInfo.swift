//
//  CoreDataVersionInfo.swift
//  Flameworker
//
//  Created by Assistant on 10/4/25.
//

import Foundation
import CoreData

/// Service to provide Core Data model version information for troubleshooting
class CoreDataVersionInfo {
    static let shared = CoreDataVersionInfo()
    
    private init() {}
    
    /// Gets the current Core Data model version using multiple detection strategies
    var currentModelVersion: String {
        // Strategy 1: Try to get explicit version identifiers
        if let explicitVersion = getExplicitVersionIdentifier(), !explicitVersion.isEmpty {
            return explicitVersion
        }
        
        // Strategy 2: Try to get version from store metadata
        if let storeVersion = modelVersionFromMetadata, !storeVersion.isEmpty {
            return storeVersion
        }
        
        // Strategy 3: Try to get version from bundle/model file structure
        if let bundleVersion = modelVersionFromBundle, !bundleVersion.isEmpty {
            return bundleVersion
        }
        
        // Strategy 4: Fallback to app version as model indicator
        return fallbackModelVersion
    }
    
    /// Display-friendly version that never returns empty
    var displayVersion: String {
        let version = currentModelVersion
        return version.isEmpty ? fallbackModelVersion : version
    }
    
    /// Attempts to get explicit version identifiers from the model
    private func getExplicitVersionIdentifier() -> String? {
        guard let modelURL = Bundle.main.url(forResource: "Molten", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            return nil
        }
        
        // Try to get version identifiers
        if let versionIdentifiers = model.versionIdentifiers as? Set<String>,
           !versionIdentifiers.isEmpty {
            return versionIdentifiers.sorted().joined(separator: ", ")
        }
        
        return nil
    }
    
    /// Gets model version from store metadata
    var modelVersionFromMetadata: String? {
        do {
            let storeURL = PersistenceController.shared.container.persistentStoreDescriptions.first?.url
            if let url = storeURL {
                let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url)
                
                // Look for version-related metadata keys
                if let versionHash = metadata[NSStoreModelVersionHashesKey] as? [String: Any] {
                    // Create a simple version indicator based on hash count/complexity
                    return "v\(versionHash.keys.count)"
                }
                
                if let version = metadata[NSStoreModelVersionIdentifiersKey] as? Set<String> {
                    return version.sorted().joined(separator: ", ")
                }
            }
        } catch {
            print("Could not read store metadata: \(error)")
        }
        return nil
    }
    
    /// Gets version information from bundle structure
    var modelVersionFromBundle: String? {
        guard let modelURL = Bundle.main.url(forResource: "Molten", withExtension: "momd") else {
            return nil
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: modelURL, includingPropertiesForKeys: nil)
            
            // Look for versioned model files (.mom files)
            let momFiles = contents.filter { $0.pathExtension == "mom" }
            
            if momFiles.count > 1 {
                // Multiple versions exist, try to determine current
                return "Multi-version (\(momFiles.count) versions)"
            } else if momFiles.count == 1 {
                // Single version, try to extract version from filename
                let filename = momFiles.first?.deletingPathExtension().lastPathComponent ?? ""
                if !filename.isEmpty && filename != "Flameworker" {
                    return filename
                }
            }
            
            // Check for VersionInfo.plist
            if let versionInfoURL = contents.first(where: { $0.lastPathComponent == "VersionInfo.plist" }) {
                do {
                    let data = try Data(contentsOf: versionInfoURL)
                    if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        if let version = plist["NSManagedObjectModel_CurrentVersionName"] as? String {
                            return version
                        }
                    }
                } catch {
                    print("Could not read VersionInfo.plist: \(error)")
                }
            }
        } catch {
            print("Could not read model bundle contents: \(error)")
        }
        
        return nil
    }
    
    /// Fallback version based on app version and model complexity
    var fallbackModelVersion: String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        // Get entity count as a rough indicator of model complexity/version
        if let modelURL = Bundle.main.url(forResource: "Molten", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: modelURL) {
            let entityCount = model.entities.count
            
            // Create a version indicator based on entity count
            // This is a heuristic - more entities typically means later model version
            if entityCount >= 10 {
                return "Flameworker Model v2 (App \(appVersion))"
            } else if entityCount >= 5 {
                return "Flameworker Model v1 (App \(appVersion))"
            } else {
                return "Flameworker Model (App \(appVersion))"
            }
        }
        
        return "Flameworker Model (Build \(buildVersion))"
    }
    
    /// Gets a hash of the current model for unique identification
    var currentModelHash: String {
        guard let modelURL = Bundle.main.url(forResource: "Molten", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            return "Unknown Hash"
        }
        
        // Create a hash based on model entities and their properties
        var hashComponents: [String] = []
        
        for entity in model.entities {
            hashComponents.append(entity.name ?? "")
            
            for property in entity.properties {
                hashComponents.append("\(entity.name ?? "").\(property.name)")
                if let attribute = property as? NSAttributeDescription {
                    hashComponents.append(String(attribute.attributeType.rawValue))
                }
            }
        }
        
        let combinedString = hashComponents.sorted().joined(separator: "|")
        let hash = combinedString.hash
        return String(format: "%08X", abs(hash))
    }
    
    /// Formats version information for display in settings
    var formattedVersionInfo: String {
        let modelVersion = currentModelVersion
        let modelHash = currentModelHash
        
        return """
        Model Version: \(modelVersion)
        Hash: \(modelHash)
        """
    }
    
    /// Checks if migration is currently available/needed
    func isMigrationAvailable(in context: NSManagedObjectContext) async throws -> Bool {
        return try await CoreDataMigrationService.shared.checkIfUnitsMigrationNeeded(in: context)
    }
    
    /// Gets detailed troubleshooting information
    var troubleshootingInfo: String {
        let modelVersion = currentModelVersion
        let modelHash = currentModelHash
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        return """
        App Version: \(bundleVersion) (\(buildVersion))
        Core Data Model: \(modelVersion)
        Model Hash: \(modelHash)
        Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")
        """
    }
}
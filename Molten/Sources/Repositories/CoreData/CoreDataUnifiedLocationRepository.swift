//
//  CoreDataUnifiedLocationRepository.swift
//  Molten
//
//  Core Data implementation for unified location repository
//

import Foundation
@preconcurrency import CoreData

class CoreDataUnifiedLocationRepository: @unchecked Sendable, UnifiedLocationRepository {
    private let persistenceController: PersistenceController

    nonisolated init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Fetch Operations

    func fetchAll() async throws -> [UnifiedLocationModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let locations = try context.fetch(request)

            // Extract values immediately in explicit loop (Swift 6 concurrency requirement)
            var models: [UnifiedLocationModel] = []
            for location in locations {
                // Safe to access Core Data properties here - we're inside context.perform
                if let model = self.convertToModel(location, in: context) {
                    models.append(model)
                }
            }
            return models
        }
    }

    func fetch(stableId: String) async throws -> UnifiedLocationModel? {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            request.predicate = NSPredicate(format: "stable_id == %@", stableId)
            request.fetchLimit = 1

            guard let location = try context.fetch(request).first else {
                return nil
            }

            return self.convertToModel(location, in: context)
        }
    }

    func search(text: String) async throws -> [UnifiedLocationModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            request.predicate = NSPredicate(
                format: "name CONTAINS[cd] %@ OR city CONTAINS[cd] %@ OR state CONTAINS[cd] %@",
                text, text, text
            )
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let locations = try context.fetch(request)

            // Extract values immediately in explicit loop (Swift 6 concurrency requirement)
            var models: [UnifiedLocationModel] = []
            for location in locations {
                // Safe to access Core Data properties here - we're inside context.perform
                if let model = self.convertToModel(location, in: context) {
                    models.append(model)
                }
            }
            return models
        }
    }

    func fetchLocationsSellingTechnique(_ technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            request.predicate = NSPredicate(format: "ANY retailCapabilities.technique == %@", technique.rawValue)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let locations = try context.fetch(request)

            // Extract values immediately in explicit loop (Swift 6 concurrency requirement)
            var models: [UnifiedLocationModel] = []
            for location in locations {
                // Safe to access Core Data properties here - we're inside context.perform
                if let model = self.convertToModel(location, in: context) {
                    models.append(model)
                }
            }
            return models
        }
    }

    func fetchLocationsTeachingTechnique(_ technique: TechniqueType) async throws -> [UnifiedLocationModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            request.predicate = NSPredicate(format: "ANY educationCapabilities.technique == %@", technique.rawValue)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let locations = try context.fetch(request)

            // Extract values immediately in explicit loop (Swift 6 concurrency requirement)
            var models: [UnifiedLocationModel] = []
            for location in locations {
                // Safe to access Core Data properties here - we're inside context.perform
                if let model = self.convertToModel(location, in: context) {
                    models.append(model)
                }
            }
            return models
        }
    }

    func fetchLocationsOfferingService(_ service: ServiceType) async throws -> [UnifiedLocationModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            request.predicate = NSPredicate(format: "ANY serviceCapabilities.service_type == %@", service.rawValue)
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let locations = try context.fetch(request)

            // Extract values immediately in explicit loop (Swift 6 concurrency requirement)
            var models: [UnifiedLocationModel] = []
            for location in locations {
                // Safe to access Core Data properties here - we're inside context.perform
                if let model = self.convertToModel(location, in: context) {
                    models.append(model)
                }
            }
            return models
        }
    }

    func fetchLocationsNear(latitude: Double, longitude: Double, radiusMeters: Double) async throws -> [UnifiedLocationModel] {
        let allLocations = try await fetchAll()

        // Calculate radius in degrees (approximate)
        let radiusDegrees = radiusMeters / 111_000.0 // ~111km per degree

        return allLocations.filter { location in
            let latDiff = abs(location.latitude - latitude)
            let lonDiff = abs(location.longitude - longitude)

            return latDiff < radiusDegrees && lonDiff < radiusDegrees
        }
    }

    func count() async throws -> Int {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            return try context.count(for: request)
        }
    }

    // MARK: - Save Operations

    func save(_ location: UnifiedLocationModel) async throws {
        let context = persistenceController.container.newBackgroundContext()

        try await context.perform {
            // Fetch or create location
            let request = NSFetchRequest<Location>(entityName: "Location")
            request.predicate = NSPredicate(format: "stable_id == %@", location.stable_id)
            request.fetchLimit = 1

            let entity: Location
            if let existing = try context.fetch(request).first {
                entity = existing
            } else {
                entity = Location(context: context)
                entity.stable_id = location.stable_id
            }

            // Update basic fields
            entity.name = location.name
            entity.address_line1 = location.addressLine1
            entity.address_line2 = location.addressLine2
            entity.city = location.city
            entity.state = location.state
            entity.zip = location.zip
            entity.latitude = location.latitude
            entity.longitude = location.longitude
            entity.website_url = location.websiteUrl
            entity.phone = location.phone
            entity.hours_json = location.hoursJson
            entity.hero_image_path = location.heroImagePath
            entity.notes = location.notes
            entity.is_verified = location.isVerified

            // Update capabilities (delete and recreate for simplicity)
            if let existingRetail = entity.retailCapabilities as? Set<LocationRetail> {
                existingRetail.forEach { context.delete($0) }
            }
            if let existingEducation = entity.educationCapabilities as? Set<LocationEducation> {
                existingEducation.forEach { context.delete($0) }
            }
            if let existingServices = entity.serviceCapabilities as? Set<LocationServices> {
                existingServices.forEach { context.delete($0) }
            }

            // Add new capabilities
            for retail in location.retailCapabilities {
                let retailEntity = LocationRetail(context: context)
                retailEntity.id = retail.id
                retailEntity.technique = retail.technique.rawValue
                retailEntity.notes = retail.notes
                retailEntity.location = entity
            }

            for education in location.educationCapabilities {
                let educationEntity = LocationEducation(context: context)
                educationEntity.id = education.id
                educationEntity.technique = education.technique.rawValue
                educationEntity.class_level = education.classLevel
                educationEntity.notes = education.notes
                educationEntity.location = entity
            }

            for service in location.servicesCapabilities {
                let serviceEntity = LocationServices(context: context)
                serviceEntity.id = service.id
                serviceEntity.service_type = service.serviceType.rawValue
                serviceEntity.notes = service.notes
                serviceEntity.location = entity
            }

            try CoreDataErrorHandler.save(context: context)
        }
    }

    func saveAll(_ locations: [UnifiedLocationModel]) async throws {
        for location in locations {
            try await save(location)
        }
    }

    // MARK: - Delete Operations

    func delete(stableId: String) async throws {
        let context = persistenceController.container.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            request.predicate = NSPredicate(format: "stable_id == %@", stableId)

            let locations = try context.fetch(request)
            locations.forEach { context.delete($0) }

            try CoreDataErrorHandler.save(context: context)
        }
    }

    func deleteAll() async throws {
        let context = persistenceController.container.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<Location>(entityName: "Location")
            let locations = try context.fetch(request)
            locations.forEach { context.delete($0) }

            try CoreDataErrorHandler.save(context: context)
        }
    }

    // MARK: - Private Helpers

    private nonisolated func convertToModel(_ entity: NSManagedObject, in context: NSManagedObjectContext) -> UnifiedLocationModel? {
        // Use value(forKey:) to avoid Swift 6 concurrency issues with @MainActor-isolated properties
        guard let stableId = entity.value(forKey: "stable_id") as? String,
              let name = entity.value(forKey: "name") as? String else {
            return nil
        }

        // Convert retail capabilities (explicit loop for Swift 6 concurrency)
        var retailCapabilities: [RetailCapability] = []
        if let retailSet = entity.value(forKey: "retailCapabilities") as? Set<NSManagedObject> {
            for retail in retailSet {
                if let techniqueStr = retail.value(forKey: "technique") as? String,
                   let technique = TechniqueType(rawValue: techniqueStr) {
                    let id = retail.value(forKey: "id") as? UUID ?? UUID()
                    let notes = retail.value(forKey: "notes") as? String
                    retailCapabilities.append(RetailCapability(
                        id: id,
                        technique: technique,
                        notes: notes
                    ))
                }
            }
        }

        // Convert education capabilities (explicit loop for Swift 6 concurrency)
        var educationCapabilities: [EducationCapability] = []
        if let educationSet = entity.value(forKey: "educationCapabilities") as? Set<NSManagedObject> {
            for education in educationSet {
                if let techniqueStr = education.value(forKey: "technique") as? String,
                   let technique = TechniqueType(rawValue: techniqueStr) {
                    let id = education.value(forKey: "id") as? UUID ?? UUID()
                    let classLevel = education.value(forKey: "class_level") as? String
                    let notes = education.value(forKey: "notes") as? String
                    educationCapabilities.append(EducationCapability(
                        id: id,
                        technique: technique,
                        classLevel: classLevel,
                        notes: notes
                    ))
                }
            }
        }

        // Convert service capabilities (explicit loop for Swift 6 concurrency)
        var servicesCapabilities: [ServicesCapability] = []
        if let servicesSet = entity.value(forKey: "serviceCapabilities") as? Set<NSManagedObject> {
            for service in servicesSet {
                if let serviceTypeStr = service.value(forKey: "service_type") as? String,
                   let serviceType = ServiceType(rawValue: serviceTypeStr) {
                    let id = service.value(forKey: "id") as? UUID ?? UUID()
                    let notes = service.value(forKey: "notes") as? String
                    servicesCapabilities.append(ServicesCapability(
                        id: id,
                        serviceType: serviceType,
                        notes: notes
                    ))
                }
            }
        }

        return UnifiedLocationModel(
            stable_id: stableId,
            name: name,
            addressLine1: entity.value(forKey: "address_line1") as? String,
            addressLine2: entity.value(forKey: "address_line2") as? String,
            city: entity.value(forKey: "city") as? String,
            state: entity.value(forKey: "state") as? String,
            zip: entity.value(forKey: "zip") as? String,
            latitude: (entity.value(forKey: "latitude") as? Double) ?? 0.0,
            longitude: (entity.value(forKey: "longitude") as? Double) ?? 0.0,
            websiteUrl: entity.value(forKey: "website_url") as? String,
            phone: entity.value(forKey: "phone") as? String,
            hoursJson: entity.value(forKey: "hours_json") as? String,
            heroImagePath: entity.value(forKey: "hero_image_path") as? String,
            notes: entity.value(forKey: "notes") as? String,
            isVerified: (entity.value(forKey: "is_verified") as? Bool) ?? false,
            retailCapabilities: retailCapabilities,
            educationCapabilities: educationCapabilities,
            servicesCapabilities: servicesCapabilities
        )
    }

    // MARK: - JSON Loading

    func loadLocationsFromJSON(_ data: Data) async throws -> Int {
        let decoder = JSONDecoder()
        let wrappedData = try decoder.decode(WrappedStoresData.self, from: data)

        var loadedCount = 0

        for storeData in wrappedData.stores {
            // Convert StoreData to UnifiedLocationModel with retail capabilities
            let location = self.convertStoreDataToUnifiedLocation(storeData)

            // Use the existing save() method which handles create/update
            try await save(location)
            loadedCount += 1
        }

        return loadedCount
    }

    func loadLocationsFromJSONFile(at fileURL: URL) async throws -> Int {
        let data = try Data(contentsOf: fileURL)
        return try await loadLocationsFromJSON(data)
    }

    // MARK: - Private Helpers for JSON Loading

    /// Convert StoreData format to UnifiedLocationModel with retail, education, and service capabilities
    private nonisolated func convertStoreDataToUnifiedLocation(_ storeData: StoreData) -> UnifiedLocationModel {
        var retailCapabilities: [RetailCapability] = []
        var educationCapabilities: [EducationCapability] = []
        var servicesCapabilities: [ServicesCapability] = []

        // Convert retail capability flags (prefer new format, fall back to legacy)
        if (storeData.retail_supports_casting ?? storeData.supports_casting) == true {
            retailCapabilities.append(RetailCapability(technique: .casting))
        }
        if (storeData.retail_supports_flameworking_hard ?? storeData.supports_flameworking_hard) == true {
            retailCapabilities.append(RetailCapability(technique: .flameworkinghard))
        }
        if (storeData.retail_supports_flameworking_soft ?? storeData.supports_flameworking_soft) == true {
            retailCapabilities.append(RetailCapability(technique: .flameworkingsoft))
        }
        if (storeData.retail_supports_fusing ?? storeData.supports_fusing) == true {
            retailCapabilities.append(RetailCapability(technique: .fusing))
        }
        if (storeData.retail_supports_glass_blowing ?? storeData.supports_glass_blowing) == true {
            retailCapabilities.append(RetailCapability(technique: .glassBlowing))
        }
        if (storeData.retail_supports_stained_glass ?? storeData.supports_stained_glass) == true {
            retailCapabilities.append(RetailCapability(technique: .stainedGlass))
        }
        if (storeData.retail_supports_other ?? storeData.supports_other) == true {
            retailCapabilities.append(RetailCapability(technique: .other))
        }

        // Convert education capability flags (new format)
        if storeData.classes_supports_casting == true {
            educationCapabilities.append(EducationCapability(technique: .casting))
        }
        if storeData.classes_supports_flameworking_hard == true {
            educationCapabilities.append(EducationCapability(technique: .flameworkinghard))
        }
        if storeData.classes_supports_flameworking_soft == true {
            educationCapabilities.append(EducationCapability(technique: .flameworkingsoft))
        }
        if storeData.classes_supports_fusing == true {
            educationCapabilities.append(EducationCapability(technique: .fusing))
        }
        if storeData.classes_supports_glass_blowing == true {
            educationCapabilities.append(EducationCapability(technique: .glassBlowing))
        }
        if storeData.classes_supports_stained_glass == true {
            educationCapabilities.append(EducationCapability(technique: .stainedGlass))
        }
        if storeData.classes_supports_other == true {
            educationCapabilities.append(EducationCapability(technique: .other))
        }

        // Convert service capability flags (new format)
        // Services are technique-agnostic - just check if any rental is supported
        let hasAnyRental = (storeData.rentals_supports_casting == true) ||
                          (storeData.rentals_supports_flameworking_hard == true) ||
                          (storeData.rentals_supports_flameworking_soft == true) ||
                          (storeData.rentals_supports_fusing == true) ||
                          (storeData.rentals_supports_glass_blowing == true) ||
                          (storeData.rentals_supports_stained_glass == true) ||
                          (storeData.rentals_supports_other == true)

        if hasAnyRental {
            servicesCapabilities.append(ServicesCapability(serviceType: .kilnRental))
        }

        return UnifiedLocationModel(
            stable_id: storeData.stable_id,
            name: storeData.name,
            addressLine1: storeData.address_line1,
            addressLine2: storeData.address_line2,
            city: storeData.city,
            state: storeData.state,
            zip: storeData.zip,
            latitude: storeData.latitude ?? 0.0,
            longitude: storeData.longitude ?? 0.0,
            websiteUrl: storeData.website_url,
            phone: storeData.phone,
            hoursJson: storeData.hours_json,
            heroImagePath: storeData.hero_image_path,
            notes: storeData.notes,
            isVerified: storeData.is_verified ?? false,
            retailCapabilities: retailCapabilities,
            educationCapabilities: educationCapabilities,
            servicesCapabilities: servicesCapabilities
        )
    }

}

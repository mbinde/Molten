//
//  MockLogbookRepository.swift
//  Molten
//
//  Mock implementation of LogbookRepository for testing
//

import Foundation

/// Mock implementation of LogbookRepository for testing
actor MockLogbookRepository: LogbookRepository {
    private var logs: [UUID: LogbookModel] = [:]
    private var imageRepository: UserImageRepository?

    init(imageRepository: UserImageRepository? = nil) {
        self.imageRepository = imageRepository
    }

    // MARK: - CRUD Operations

    func createLog(_ log: LogbookModel) async throws -> LogbookModel {
        logs[log.id] = log
        return log
    }

    func getLog(id: UUID) async throws -> LogbookModel? {
        return logs[id]
    }

    func getAllLogs() async throws -> [LogbookModel] {
        return Array(logs.values).sorted { $0.dateCreated > $1.dateCreated }
    }

    func getLogs(status: ProjectStatus?) async throws -> [LogbookModel] {
        if let status = status {
            return Array(logs.values).filter { $0.status == status }.sorted { $0.dateCreated > $1.dateCreated }
        } else {
            return try await getAllLogs()
        }
    }

    func updateLog(_ log: LogbookModel) async throws {
        guard logs[log.id] != nil else {
            throw ProjectRepositoryError.logNotFound
        }
        logs[log.id] = log
    }

    func deleteLog(id: UUID) async throws {
        guard logs[id] != nil else {
            throw ProjectRepositoryError.logNotFound
        }
        logs.removeValue(forKey: id)
    }

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        let filtered = Array(logs.values).filter { log in
            // Check if log matches the date range:
            // Include only if completionDate OR startDate is in range
            // Exclude entries where both are nil (no fallback to dateCreated)

            var dateInRange = false

            // Check completionDate
            if let completionDate = log.completionDate {
                if completionDate >= start && completionDate <= end {
                    dateInRange = true
                }
            }

            // Check startDate (OR logic - if either is in range, include)
            if let startDate = log.startDate {
                if startDate >= start && startDate <= end {
                    dateInRange = true
                }
            }

            return dateInRange
        }.sorted { log1, log2 in
            // Sort by priority: completionDate > startDate > dateCreated
            // Most recent first (descending order)
            let date1: Date
            if let d = log1.completionDate {
                date1 = d
            } else if let d = log1.startDate {
                date1 = d
            } else {
                date1 = log1.dateCreated
            }

            let date2: Date
            if let d = log2.completionDate {
                date2 = d
            } else if let d = log2.startDate {
                date2 = d
            } else {
                date2 = log2.dateCreated
            }

            // Note: Using > comparison for descending order (most recent first)
            return date1 > date2
        }
        return filtered
    }

    func getSoldLogs() async throws -> [LogbookModel] {
        let filtered = Array(logs.values).filter { $0.status == .sold }.sorted { log1, log2 in
            // Logs with sale dates should come before logs without sale dates
            switch (log1.saleDate, log2.saleDate) {
            case (nil, nil):
                // Both have no sale date, sort by dateCreated descending
                return log1.dateCreated > log2.dateCreated
            case (nil, _):
                // log1 has no sale date, log2 does - log2 comes first
                return false
            case (_, nil):
                // log1 has sale date, log2 doesn't - log1 comes first
                return true
            case (let date1?, let date2?):
                // Both have sale dates, sort by sale date descending (most recent first)
                return date1 > date2
            }
        }
        return filtered
    }

    func getTotalRevenue() async throws -> Decimal {
        let soldLogs = try await getSoldLogs()
        return soldLogs.reduce(Decimal(0)) { total, log in
            total + (log.pricePoint ?? 0)
        }
    }

    // MARK: - Search

    func searchLogs(query: String) async throws -> [LogbookModel] {
        let lowercaseQuery = query.lowercased()
        let allLogs = Array(logs.values)

        // Search in logbook fields
        let matches = allLogs.filter { log in
            // Search title
            if log.title.lowercased().contains(lowercaseQuery) {
                return true
            }

            // Search notes
            if let notes = log.notes, notes.lowercased().contains(lowercaseQuery) {
                return true
            }

            // Search techniques
            if let techniques = log.techniquesUsed {
                for technique in techniques {
                    if technique.lowercased().contains(lowercaseQuery) {
                        return true
                    }
                }
            }

            return false
        }

        var matchIds = Set(matches.map { $0.id })

        // Add OCR text search if imageRepository is available
        if let imageRepository = imageRepository {
            for log in allLogs {
                let ocrText = try? await imageRepository.getOCRText(
                    ownerType: .projectLog,
                    ownerId: log.id.uuidString
                )

                if let ocrText = ocrText, !ocrText.isEmpty, ocrText.lowercased().contains(lowercaseQuery) {
                    matchIds.insert(log.id)
                }
            }
        }

        // Return final matches
        let finalMatches = allLogs.filter { matchIds.contains($0.id) }
        return finalMatches.sorted { $0.dateCreated > $1.dateCreated }
    }

    // MARK: - Test Helpers

    func reset() {
        logs.removeAll()
    }

    func getLogCount() async -> Int {
        return logs.count
    }
}

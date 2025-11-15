//
//  MockLogbookRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of LogbookRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of LogbookRepository for testing
/// Stores logbook entries in memory using a dictionary
final class MockLogbookRepository: LogbookRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var logs: [UUID: LogbookModel] = [:]

    // MARK: - CRUD Operations

    func createLog(_ log: LogbookModel) async throws -> LogbookModel {
        logs[log.id] = log
        return log
    }

    func getLog(id: UUID) async throws -> LogbookModel? {
        return logs[id]
    }

    func getAllLogs() async throws -> [LogbookModel] {
        let logsArray = Array(logs.values)

        // Extract dates and pair with logs for sorting
        var logsWithDates: [(log: LogbookModel, date: Date)] = []
        for log in logsArray {
            let date = await log.dateCreated
            logsWithDates.append((log, date))
        }

        // Sort by date descending
        logsWithDates.sort { $0.date > $1.date }

        return logsWithDates.map { $0.log }
    }

    func getLogs(status: ProjectStatus?) async throws -> [LogbookModel] {
        guard let status = status else {
            return try await getAllLogs()
        }
        var filtered: [LogbookModel] = []
        for log in logs.values {
            let logStatus = await log.status
            if logStatus == status {
                filtered.append(log)
            }
        }

        // Extract dates and pair with logs for sorting
        var logsWithDates: [(log: LogbookModel, date: Date)] = []
        for log in filtered {
            let date = await log.dateCreated
            logsWithDates.append((log, date))
        }

        // Sort by date descending
        logsWithDates.sort { $0.date > $1.date }

        return logsWithDates.map { $0.log }
    }

    func updateLog(_ log: LogbookModel) async throws {
        let logId = await log.id
        guard logs[logId] != nil else {
            throw ProjectRepositoryError.logNotFound
        }
        logs[logId] = log
    }

    func deleteLog(id: UUID) async throws {
        guard logs[id] != nil else {
            throw ProjectRepositoryError.logNotFound
        }
        logs.removeValue(forKey: id)
    }

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        var filtered: [LogbookModel] = []
        for log in logs.values {
            // Use startDate if available, otherwise fall back to dateCreated
            let logStartDate = await log.startDate
            let logDateCreated = await log.dateCreated
            let logDate = logStartDate ?? logDateCreated
            if logDate >= start && logDate <= end {
                filtered.append(log)
            }
        }

        // Extract dates and pair with logs for sorting
        var logsWithDates: [(log: LogbookModel, date: Date)] = []
        for log in filtered {
            let date = await log.dateCreated
            logsWithDates.append((log, date))
        }

        // Sort by date descending
        logsWithDates.sort { $0.date > $1.date }

        return logsWithDates.map { $0.log }
    }

    func getSoldLogs() async throws -> [LogbookModel] {
        var filtered: [LogbookModel] = []
        for log in logs.values {
            let logStatus = await log.status
            if logStatus == .sold {
                filtered.append(log)
            }
        }

        // Extract dates and pair with logs for sorting
        // Use saleDate if available, otherwise fall back to dateCreated
        var logsWithDates: [(log: LogbookModel, date: Date)] = []
        for log in filtered {
            let saleDate = await log.saleDate
            let dateCreated = await log.dateCreated
            let date = saleDate ?? dateCreated
            logsWithDates.append((log, date))
        }

        // Sort by date descending (saleDate takes precedence over dateCreated)
        logsWithDates.sort { $0.date > $1.date }

        return logsWithDates.map { $0.log }
    }

    func getTotalRevenue() async throws -> Decimal {
        var total: Decimal = 0
        for log in logs.values {
            let logStatus = await log.status
            let pricePoint = await log.pricePoint
            // Only sum prices for sold items
            if logStatus == .sold, let pricePoint = pricePoint {
                total += pricePoint
            }
        }
        return total
    }

    // MARK: - Search

    func searchLogs(query: String) async throws -> [LogbookModel] {
        let lowercasedQuery = query.lowercased()
        var filtered: [LogbookModel] = []

        for log in logs.values {
            let logTitle = await log.title
            let logNotes = await log.notes
            let logTechniques = await log.techniquesUsed

            let titleMatch = logTitle.lowercased().contains(lowercasedQuery)
            let notesMatch = logNotes?.lowercased().contains(lowercasedQuery) ?? false

            var techniquesMatch = false
            if let techniques = logTechniques {
                for technique in techniques {
                    if technique.lowercased().contains(lowercasedQuery) {
                        techniquesMatch = true
                        break
                    }
                }
            }

            if titleMatch || notesMatch || techniquesMatch {
                filtered.append(log)
            }
        }

        // Extract dates and pair with logs for sorting
        var logsWithDates: [(log: LogbookModel, date: Date)] = []
        for log in filtered {
            let date = await log.dateCreated
            logsWithDates.append((log, date))
        }

        // Sort by date descending
        logsWithDates.sort { $0.date > $1.date }

        return logsWithDates.map { $0.log }
    }

    // MARK: - Test Helpers

    /// Get count of stored logs (test helper)
    func getLogCount() async -> Int {
        return logs.count
    }

    /// Clear all logs (test helper)
    func clearAll() async {
        logs.removeAll()
    }

    /// Reset (alias for clearAll)
    func reset() async {
        await clearAll()
    }
}

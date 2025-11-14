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
@MainActor
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
        return Array(logs.values).sorted { $0.dateCreated > $1.dateCreated }
    }

    func getLogs(status: ProjectStatus?) async throws -> [LogbookModel] {
        guard let status = status else {
            return try await getAllLogs()
        }
        return logs.values
            .filter { $0.status == status }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    func updateLog(_ log: LogbookModel) async throws {
        guard logs[log.id] != nil else {
            throw NSError(domain: "MockLogbookRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Log not found with id: \(log.id)"
            ])
        }
        logs[log.id] = log
    }

    func deleteLog(id: UUID) async throws {
        guard logs[id] != nil else {
            throw NSError(domain: "MockLogbookRepository", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Log not found with id: \(id)"
            ])
        }
        logs.removeValue(forKey: id)
    }

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        return logs.values
            .filter { $0.dateCreated >= start && $0.dateCreated <= end }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    func getSoldLogs() async throws -> [LogbookModel] {
        return logs.values
            .filter { $0.status == .sold }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    func getTotalRevenue() async throws -> Decimal {
        return logs.values
            .compactMap { $0.pricePoint }
            .reduce(0, +)
    }

    // MARK: - Search

    func searchLogs(query: String) async throws -> [LogbookModel] {
        let lowercasedQuery = query.lowercased()
        return logs.values
            .filter { log in
                log.title.lowercased().contains(lowercasedQuery) ||
                (log.notes?.lowercased().contains(lowercasedQuery) ?? false) ||
                (log.techniquesUsed?.contains(where: { $0.lowercased().contains(lowercasedQuery) }) ?? false)
            }
            .sorted { (a: LogbookModel, b: LogbookModel) in a.dateCreated > b.dateCreated }
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

//
//  MockProjectLogRepository.swift
//  Flameworker
//
//  Mock implementation of ProjectLogRepository for testing
//

import Foundation

/// Mock implementation of ProjectLogRepository for testing
class MockProjectLogRepository: ProjectLogRepository {
    private var logs: [UUID: ProjectLogModel] = [:]

    nonisolated init() {}

    // MARK: - CRUD Operations

    func createLog(_ log: ProjectLogModel) async throws -> ProjectLogModel {
        logs[log.id] = log
        return log
    }

    func getLog(id: UUID) async throws -> ProjectLogModel? {
        return logs[id]
    }

    func getAllLogs() async throws -> [ProjectLogModel] {
        return Array(logs.values).sorted { $0.dateCreated > $1.dateCreated }
    }

    func getLogs(status: ProjectStatus?) async throws -> [ProjectLogModel] {
        if let status = status {
            return logs.values.filter { $0.status == status }.sorted { $0.dateCreated > $1.dateCreated }
        } else {
            return try await getAllLogs()
        }
    }

    func updateLog(_ log: ProjectLogModel) async throws {
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

    func getLogsByDateRange(start: Date, end: Date) async throws -> [ProjectLogModel] {
        return logs.values.filter { log in
            // Use projectDate if available, otherwise fall back to dateCreated
            let dateToCheck = log.projectDate ?? log.dateCreated
            return dateToCheck >= start && dateToCheck <= end
        }.sorted { log1, log2 in
            let date1 = log1.projectDate ?? log1.dateCreated
            let date2 = log2.projectDate ?? log2.dateCreated
            return date1 > date2
        }
    }

    func getSoldLogs() async throws -> [ProjectLogModel] {
        return logs.values.filter { $0.status == .sold }.sorted { log1, log2 in
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
    }

    func getTotalRevenue() async throws -> Decimal {
        let soldLogs = try await getSoldLogs()
        return soldLogs.reduce(Decimal(0)) { total, log in
            total + (log.pricePoint ?? 0)
        }
    }

    // MARK: - Test Helpers

    func reset() {
        logs.removeAll()
    }

    func getLogCount() -> Int {
        return logs.count
    }
}

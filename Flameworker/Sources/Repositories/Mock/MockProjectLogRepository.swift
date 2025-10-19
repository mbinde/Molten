//
//  MockProjectLogRepository.swift
//  Flameworker
//
//  Mock implementation of ProjectLogRepository for testing
//

import Foundation

/// Mock implementation of ProjectLogRepository for testing
actor MockProjectLogRepository: ProjectLogRepository {
    private var logs: [UUID: ProjectLogModel] = [:]

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
            guard let projectDate = log.projectDate else { return false }
            return projectDate >= start && projectDate <= end
        }.sorted { log1, log2 in
            guard let date1 = log1.projectDate, let date2 = log2.projectDate else {
                return log1.dateCreated > log2.dateCreated
            }
            return date1 > date2
        }
    }

    func getSoldLogs() async throws -> [ProjectLogModel] {
        return logs.values.filter { $0.status == .sold }.sorted { log1, log2 in
            guard let date1 = log1.saleDate, let date2 = log2.saleDate else {
                return log1.dateCreated > log2.dateCreated
            }
            return date1 > date2
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

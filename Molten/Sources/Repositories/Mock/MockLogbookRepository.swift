//
//  MockLogbookRepository.swift
//  Molten
//
//  Mock implementation of LogbookRepository for testing
//

import Foundation

/// Mock implementation of LogbookRepository for testing
class MockLogbookRepository: @unchecked Sendable, LogbookRepository {
    nonisolated(unsafe) private var logs: [UUID: LogbookModel] = [:]
    private let queue = DispatchQueue(label: "mock.projectlog.repository", attributes: .concurrent)

    nonisolated init() {}

    // MARK: - CRUD Operations

    func createLog(_ log: LogbookModel) async throws -> LogbookModel {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.logs[log.id] = log
                continuation.resume(returning: log)
            }
        }
    }

    func getLog(id: UUID) async throws -> LogbookModel? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.logs[id])
            }
        }
    }

    func getAllLogs() async throws -> [LogbookModel] {
        await withCheckedContinuation { continuation in
            queue.async {
                let sorted = Array(self.logs.values).sorted { $0.dateCreated > $1.dateCreated }
                continuation.resume(returning: sorted)
            }
        }
    }

    func getLogs(status: ProjectStatus?) async throws -> [LogbookModel] {
        if let status = status {
            return await withCheckedContinuation { continuation in
                queue.async {
                    let values = Array(self.logs.values); let filtered = values.filter { $0.status == status }.sorted { $0.dateCreated > $1.dateCreated }
                    continuation.resume(returning: filtered)
                }
            }
        } else {
            return try await getAllLogs()
        }
    }

    func updateLog(_ log: LogbookModel) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) {
                guard self.logs[log.id] != nil else {
                    continuation.resume(throwing: ProjectRepositoryError.logNotFound)
                    return
                }
                self.logs[log.id] = log
                continuation.resume()
            }
        }
    }

    func deleteLog(id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) {
                guard self.logs[id] != nil else {
                    continuation.resume(throwing: ProjectRepositoryError.logNotFound)
                    return
                }
                self.logs.removeValue(forKey: id)
                continuation.resume()
            }
        }
    }

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        await withCheckedContinuation { continuation in
            queue.async {
                let values = Array(self.logs.values); let filtered = values.filter { log in
                    // Check if either startDate or completionDate falls within the range
                    // If neither is set, use dateCreated
                    let startDateInRange = log.startDate.map { $0 >= start && $0 <= end } ?? false
                    let completionDateInRange = log.completionDate.map { $0 >= start && $0 <= end } ?? false
                    let createdDateInRange = log.dateCreated >= start && log.dateCreated <= end

                    return startDateInRange || completionDateInRange || (log.startDate == nil && log.completionDate == nil && createdDateInRange)
                }.sorted { log1, log2 in
                    // Sort by completion date, then start date, then created date
                    let date1 = log1.completionDate ?? log1.startDate ?? log1.dateCreated
                    let date2 = log2.completionDate ?? log2.startDate ?? log2.dateCreated
                    return date1 > date2
                }
                continuation.resume(returning: filtered)
            }
        }
    }

    func getSoldLogs() async throws -> [LogbookModel] {
        await withCheckedContinuation { continuation in
            queue.async {
                let values = Array(self.logs.values); let filtered = values.filter { $0.status == .sold }.sorted { log1, log2 in
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
                continuation.resume(returning: filtered)
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

    nonisolated func reset() {
        queue.async(flags: .barrier) {
            self.logs.removeAll()
        }
    }

    nonisolated func getLogCount() async -> Int {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.logs.count)
            }
        }
    }
}

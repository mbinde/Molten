//
//  LogbookRepository.swift
//  Molten
//
//  Protocol for Logbook data persistence operations
//

import Foundation

nonisolated protocol LogbookRepository {
    // MARK: - CRUD Operations

    func createLog(_ log: LogbookModel) async throws -> LogbookModel
    func getLog(id: UUID) async throws -> LogbookModel?
    func getAllLogs() async throws -> [LogbookModel]
    func getLogs(status: ProjectStatus?) async throws -> [LogbookModel]
    func updateLog(_ log: LogbookModel) async throws
    func deleteLog(id: UUID) async throws

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel]
    func getSoldLogs() async throws -> [LogbookModel]
    func getTotalRevenue() async throws -> Decimal
}

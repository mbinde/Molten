//
//  ProjectLogRepository.swift
//  Flameworker
//
//  Protocol for ProjectLog data persistence operations
//

import Foundation

protocol ProjectLogRepository {
    // MARK: - CRUD Operations

    func createLog(_ log: ProjectLogModel) async throws -> ProjectLogModel
    func getLog(id: UUID) async throws -> ProjectLogModel?
    func getAllLogs() async throws -> [ProjectLogModel]
    func getLogs(status: ProjectStatus?) async throws -> [ProjectLogModel]
    func updateLog(_ log: ProjectLogModel) async throws
    func deleteLog(id: UUID) async throws

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [ProjectLogModel]
    func getSoldLogs() async throws -> [ProjectLogModel]
    func getTotalRevenue() async throws -> Decimal
}

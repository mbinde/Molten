//
//  DefaultWorkspaceProvider.swift
//  Molten
//
//  Provides the default workspace ID for use by repositories and services.
//  Lazily creates the default workspace if it doesn't exist.
//

import Foundation
import OSLog

/// Provides the default workspace UUID, creating the workspace if needed.
/// Thread-safe and caches the ID after first retrieval.
@MainActor
final class DefaultWorkspaceProvider: Sendable {

    // MARK: - Dependencies

    private let workspaceRepository: WorkspaceRepository
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "workspace-provider")

    // MARK: - Cached State

    /// Cached default workspace ID (set once, never changes during app lifetime)
    private var cachedDefaultWorkspaceId: UUID?

    // MARK: - Initialization

    init(workspaceRepository: WorkspaceRepository) {
        self.workspaceRepository = workspaceRepository
    }

    // MARK: - Public API

    /// Get the default workspace ID, creating the workspace if it doesn't exist.
    /// Caches the result for subsequent calls.
    /// - Returns: The UUID of the default workspace
    func getDefaultWorkspaceId() async throws -> UUID {
        // Return cached value if available
        if let cached = cachedDefaultWorkspaceId {
            return cached
        }

        // Get or create the default workspace
        let workspace = try await workspaceRepository.getOrCreateDefaultWorkspace()
        cachedDefaultWorkspaceId = workspace.id

        log.info("Default workspace ID: \(workspace.id)")
        return workspace.id
    }

    /// Clear the cached workspace ID (useful for testing)
    func clearCache() {
        cachedDefaultWorkspaceId = nil
    }
}

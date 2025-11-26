//
//  WorkspaceRepository.swift
//  Molten
//
//  Repository protocol for Workspace data persistence operations
//

import Foundation

/// Repository protocol for Workspace data persistence operations
/// Handles workspace management for multi-inventory-set support
nonisolated protocol WorkspaceRepository: Sendable {

    // MARK: - Basic CRUD Operations

    /// Fetch all workspaces
    /// - Returns: Array of WorkspaceModel instances
    func fetchAllWorkspaces() async throws -> [WorkspaceModel]

    /// Fetch a workspace by its ID
    /// - Parameter id: The UUID of the workspace
    /// - Returns: WorkspaceModel if found, nil otherwise
    func fetchWorkspace(byId id: UUID) async throws -> WorkspaceModel?

    /// Fetch a workspace by its name
    /// - Parameter name: The name of the workspace (e.g., "default")
    /// - Returns: WorkspaceModel if found, nil otherwise
    func fetchWorkspace(byName name: String) async throws -> WorkspaceModel?

    /// Create a new workspace
    /// - Parameter workspace: The WorkspaceModel to create
    /// - Returns: The created WorkspaceModel
    func createWorkspace(_ workspace: WorkspaceModel) async throws -> WorkspaceModel

    /// Update an existing workspace
    /// - Parameter workspace: The WorkspaceModel with updated values
    /// - Returns: The updated WorkspaceModel
    func updateWorkspace(_ workspace: WorkspaceModel) async throws -> WorkspaceModel

    /// Delete a workspace by its ID
    /// - Parameter id: The UUID of the workspace to delete
    func deleteWorkspace(byId id: UUID) async throws

    // MARK: - Default Workspace

    /// Get or create the default workspace
    /// If no workspace named "default" exists, creates one
    /// - Returns: The default WorkspaceModel
    func getOrCreateDefaultWorkspace() async throws -> WorkspaceModel
}

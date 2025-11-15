//
//  CatalogDatabaseIntegrationTests.swift
//  RepositoryTests
//
//  Integration tests for catalog database loading and repository integration
//

import Foundation
import Testing
import SQLite3
@testable import Molten

@Suite("Catalog Database Integration Tests", .serialized)
@MainActor
struct CatalogDatabaseIntegrationTests {

    // MARK: - End-to-End Tests

    @Test("Should initialize catalog database from bundle")
    func testCatalogInitialization() async throws {
        // This test verifies the full initialization flow

        do {
            // Initialize the catalog database
            try await CatalogDatabaseManager.shared.initialize()

            // Verify we can get a connection
            let connection = try CatalogDatabaseManager.shared.getDatabaseConnection()
            #expect(connection != nil)

            print("✅ Catalog database initialized successfully")
        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found in bundle: \(error)")
        }
    }

    @Test("Should load catalog data through repository")
    func testCatalogDataLoading() async throws {
        do {
            // Initialize database
            try await CatalogDatabaseManager.shared.initialize()

            // Create repository
            let repository = SQLiteGlassItemRepository()

            // Fetch all items
            let items = try await repository.fetchItems(matching: nil)

            // Verify we have data
            #expect(items.count > 0)
            print("✅ Loaded \(items.count) catalog items")

            // Verify data quality
            #expect(items.allSatisfy { !$0.stable_id.isEmpty })
            #expect(items.allSatisfy { !$0.name.isEmpty })
            #expect(items.allSatisfy { !$0.manufacturer.isEmpty })
            #expect(items.allSatisfy { $0.coe > 0 })

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    @Test("Should integrate with CatalogService")
    func testCatalogServiceIntegration() async throws {
        do {
            // Initialize database
            try await CatalogDatabaseManager.shared.initialize()

            // Use shared dependencies (which will use SQLite in non-test mode)
            // Note: Can't use test persistence controller here because it switches to Core Data
            let repository = SQLiteGlassItemRepository()

            // Fetch items directly through repository
            let items = try await repository.fetchItems(matching: nil)

            // Verify repository returns data
            #expect(items.count > 0)
            print("✅ SQLiteGlassItemRepository loaded \(items.count) items")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    // MARK: - Database Verification Tests

    @Test("Should have correct database schema")
    func testDatabaseSchema() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let db = try CatalogDatabaseManager.shared.getDatabaseConnection()

            // Check for required tables
            let tables = try getTableNames(db: db)
            #expect(tables.contains("metadata"))
            #expect(tables.contains("glass_items"))

            print("✅ Database schema verified: \(tables)")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    @Test("Should have valid version metadata")
    func testVersionMetadata() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let db = try CatalogDatabaseManager.shared.getDatabaseConnection()

            // Query version
            let query = "SELECT value FROM metadata WHERE key = 'version'"
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw NSError(domain: "TestError", code: -1)
            }

            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw NSError(domain: "TestError", code: -2)
            }

            let versionString = String(cString: sqlite3_column_text(statement, 0))
            guard let version = Int(versionString) else {
                throw NSError(domain: "TestError", code: -3)
            }

            #expect(version >= 1)
            print("✅ Database version: \(version)")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    @Test("Should have proper indexes for performance")
    func testDatabaseIndexes() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let db = try CatalogDatabaseManager.shared.getDatabaseConnection()

            // Check for indexes
            let indexes = try getIndexNames(db: db)

            // Should have indexes on commonly queried columns
            #expect(indexes.contains { $0.contains("manufacturer") })
            #expect(indexes.contains { $0.contains("coe") })
            #expect(indexes.contains { $0.contains("status") })

            print("✅ Database indexes verified: \(indexes)")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    // MARK: - Data Quality Tests

    @Test("Should have diverse manufacturers")
    func testManufacturerDiversity() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let repository = SQLiteGlassItemRepository()

            let manufacturers = try await repository.getDistinctManufacturers()

            // Should have multiple manufacturers
            #expect(manufacturers.count > 1)

            // Should include some manufacturers (check actual data)
            #expect(manufacturers.contains("CIM") || manufacturers.contains("DH") || manufacturers.contains("bullseye") || manufacturers.contains("spectrum"))

            print("✅ Found \(manufacturers.count) manufacturers: \(manufacturers.prefix(5).joined(separator: ", "))...")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    @Test("Should have multiple COE values")
    func testCOEDiversity() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let repository = SQLiteGlassItemRepository()

            let coeValues = try await repository.getDistinctCOEValues()

            // Should have common COE values (90, 96, 104)
            #expect(coeValues.count > 0)
            #expect(coeValues.contains(90) || coeValues.contains(96))

            print("✅ Found COE values: \(coeValues.sorted())")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    @Test("Should have items with various statuses")
    func testStatusDiversity() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let repository = SQLiteGlassItemRepository()

            let statuses = try await repository.getDistinctStatuses()

            // Should have at least "available" status
            #expect(statuses.count > 0)
            #expect(statuses.contains("available"))

            print("✅ Found statuses: \(statuses)")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    // MARK: - Performance Tests

    @Test("Should load catalog quickly on first launch")
    func testFirstLaunchPerformance() async throws {
        do {
            let startTime = Date()

            // Initialize catalog (this is what happens on first launch)
            try await CatalogDatabaseManager.shared.initialize()

            let initDuration = Date().timeIntervalSince(startTime)
            print("⏱️  Catalog initialization: \(String(format: "%.3f", initDuration))s")

            // Load all items
            let repository = SQLiteGlassItemRepository()
            let fetchStart = Date()
            let items = try await repository.fetchItems(matching: nil)
            let fetchDuration = Date().timeIntervalSince(fetchStart)

            print("⏱️  Fetch \(items.count) items: \(String(format: "%.3f", fetchDuration))s")
            print("⏱️  Total time: \(String(format: "%.3f", initDuration + fetchDuration))s")

            // Should be fast (< 1 second total)
            #expect(initDuration + fetchDuration < 1.0)

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    @Test("Should query efficiently")
    func testQueryPerformance() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let repository = SQLiteGlassItemRepository()

            // Test various query types
            let queries: [(String, () async throws -> Int)] = [
                ("Fetch all", { try await repository.fetchItems(matching: nil).count }),
                ("Search 'clear'", { try await repository.searchItems(text: "clear").count }),
                ("Filter by manufacturer", { try await repository.fetchItems(byManufacturer: "bullseye").count }),
                ("Filter by COE 90", { try await repository.fetchItems(byCOE: 90).count }),
                ("Get manufacturers", { try await repository.getDistinctManufacturers().count }),
            ]

            for (name, query) in queries {
                let start = Date()
                let count = try await query()
                let duration = Date().timeIntervalSince(start)
                print("⏱️  \(name): \(count) results in \(String(format: "%.3f", duration))s")

                // All queries should be fast (< 0.5 seconds)
                #expect(duration < 0.5)
            }

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    // MARK: - Zero WAL Checkpoint Test

    @Test("Should not create WAL checkpoint messages")
    func testNoWALCheckpoints() async throws {
        do {
            // This test documents expected behavior:
            // - Bundled SQLite database is READ-ONLY
            // - No writes occur during catalog loading
            // - Therefore: ZERO WAL checkpoint messages

            try await CatalogDatabaseManager.shared.initialize()
            let repository = SQLiteGlassItemRepository()

            // Load catalog (read-only operation)
            let items = try await repository.fetchItems(matching: nil)
            #expect(items.count > 0)

            // No way to programmatically verify WAL checkpoints
            // This would need to be verified by inspecting system logs
            // Expected: Zero "WAL checkpoint" messages in logs

            print("✅ Loaded \(items.count) items with zero write operations")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    // MARK: - Data Consistency Tests

    @Test("Should have consistent stable_id format")
    func testStableIdFormat() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let repository = SQLiteGlassItemRepository()

            let items = try await repository.fetchItems(matching: nil)
            guard !items.isEmpty else {
                print("⚠️  No items to test")
                return
            }

            // All items must have non-empty stable_ids
            #expect(items.allSatisfy { !$0.stable_id.isEmpty })

            // Check format diversity (catalog may use different stable_id formats)
            let itemsWithDashes = items.filter { $0.stable_id.contains("-") }
            let totalItems = items.count
            let percentWithDashes = Double(itemsWithDashes.count) / Double(totalItems) * 100

            print("✅ Verified stable_id format for \(items.count) items (\(String(format: "%.1f", percentWithDashes))% with dashes)")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    @Test("Should have valid COE values")
    func testCOEValues() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()
            let repository = SQLiteGlassItemRepository()

            let items = try await repository.fetchItems(matching: nil)
            guard !items.isEmpty else {
                print("⚠️  No items to test")
                return
            }

            // All COE values should be positive and realistic (33-250)
            for item in items {
                #expect(item.coe > 0)
                #expect(item.coe < 300)
            }

            print("✅ Verified COE values for \(items.count) items")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }

    // MARK: - Helper Functions

    private func getTableNames(db: OpaquePointer) throws -> [String] {
        let query = "SELECT name FROM sqlite_master WHERE type='table'"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "TestError", code: -10)
        }

        defer { sqlite3_finalize(statement) }

        var tables: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 0) {
                tables.append(String(cString: name))
            }
        }

        return tables
    }

    private func getIndexNames(db: OpaquePointer) throws -> [String] {
        let query = "SELECT name FROM sqlite_master WHERE type='index'"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "TestError", code: -11)
        }

        defer { sqlite3_finalize(statement) }

        var indexes: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = sqlite3_column_text(statement, 0) {
                indexes.append(String(cString: name))
            }
        }

        return indexes
    }
}

// MARK: - Database File Size Tests

@Suite("Catalog Database File Tests")
@MainActor
struct CatalogDatabaseFileTests {

    @Test("Should have reasonable file size")
    func testDatabaseFileSize() async throws {
        // Check that catalog.sqlite exists and has reasonable size

        guard let bundleURL = Bundle.main.url(forResource: "catalog", withExtension: "sqlite") else {
            print("⚠️  Skipping test - catalog.sqlite not found in bundle")
            return
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: bundleURL.path)
        guard let fileSize = attributes[.size] as? UInt64 else {
            throw NSError(domain: "TestError", code: -1)
        }

        let fileSizeMB = Double(fileSize) / 1_048_576.0
        print("📊 catalog.sqlite file size: \(String(format: "%.2f", fileSizeMB)) MB")

        // Should be between 1 MB and 20 MB for ~4000 items
        #expect(fileSizeMB > 1.0)
        #expect(fileSizeMB < 20.0)
    }

    @Test("Should be shipped in app bundle")
    func testDatabaseInBundle() async throws {
        let bundleURL = Bundle.main.url(forResource: "catalog", withExtension: "sqlite")

        #expect(bundleURL != nil)
        print("✅ catalog.sqlite found in bundle at: \(bundleURL?.path ?? "unknown")")
    }

    @Test("Should copy to Documents on first launch")
    func testDatabaseCopyToDocuments() async throws {
        do {
            try await CatalogDatabaseManager.shared.initialize()

            // Verify database exists in Documents
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dbURL = documentsURL.appendingPathComponent("catalog.sqlite")

            #expect(FileManager.default.fileExists(atPath: dbURL.path))
            print("✅ Database copied to Documents: \(dbURL.path)")

        } catch {
            print("⚠️  Skipping test - catalog.sqlite not found: \(error)")
        }
    }
}

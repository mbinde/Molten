//
//  PurchaseRecordRepositoryTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Purchase Record Repository Tests")
struct PurchaseRecordRepositoryTests {
    
    @Test("Should create PurchaseRecordModel with required properties")
    func testPurchaseRecordModelCreation() async throws {
        // This test will fail initially as PurchaseRecordModel doesn't exist yet
        let record = PurchaseRecordModel(
            id: "purchase-123",
            supplier: "Glass Supply Co",
            price: 45.99,
            dateAdded: Date(),
            notes: "Monthly glass rod purchase"
        )
        
        #expect(record.id == "purchase-123")
        #expect(record.supplier == "Glass Supply Co")
        #expect(record.price == 45.99)
        #expect(record.notes == "Monthly glass rod purchase")
    }
    
    @Test("Should fetch purchase records through repository protocol")
    func testPurchaseRecordRepositoryFetch() async throws {
        // This test will fail initially as PurchaseRecordRepository doesn't exist yet
        let mockRepo = MockPurchaseRecordRepository()
        let testRecords = [
            PurchaseRecordModel(
                supplier: "Bullseye Glass",
                price: 125.50,
                notes: "Glass rods and sheets"
            ),
            PurchaseRecordModel(
                supplier: "Spectrum Glass", 
                price: 89.99,
                notes: "Specialty colors"
            )
        ]
        
        mockRepo.addTestRecords(testRecords)
        
        let fetchedRecords = try await mockRepo.fetchRecords(from: Date.distantPast, to: Date.distantFuture)
        
        #expect(fetchedRecords.count == 2)
        #expect(fetchedRecords.first?.supplier == "Bullseye Glass")
    }
    
    @Test("Should calculate total spending for date range")
    func testTotalSpendingCalculation() async throws {
        let mockRepo = MockPurchaseRecordRepository()
        let testRecords = [
            PurchaseRecordModel(supplier: "Supplier A", price: 100.00),
            PurchaseRecordModel(supplier: "Supplier B", price: 50.50),
            PurchaseRecordModel(supplier: "Supplier C", price: 25.25)
        ]
        
        mockRepo.addTestRecords(testRecords)
        
        let totalSpending = try await mockRepo.calculateTotalSpending(from: Date.distantPast, to: Date.distantFuture)
        
        #expect(totalSpending == 175.75) // 100.00 + 50.50 + 25.25
    }
    
    @Test("Should work with PurchaseService layer")
    func testPurchaseServiceIntegration() async throws {
        let mockRepo = MockPurchaseRecordRepository()
        let purchaseService = PurchaseRecordService(repository: mockRepo)
        
        let testRecord = PurchaseRecordModel(
            supplier: "Glass Supply Co",
            price: 99.99,
            notes: "Monthly glass purchase"
        )
        
        let createdRecord = try await purchaseService.createRecord(testRecord)
        #expect(createdRecord.id.isEmpty == false)
        #expect(createdRecord.supplier == "Glass Supply Co")
        #expect(createdRecord.price == 99.99)
        
        let allRecords = try await purchaseService.getAllRecords()
        #expect(allRecords.count == 1)
        
        let totalSpending = try await purchaseService.getTotalSpending(from: Date.distantPast, to: Date.distantFuture)
        #expect(totalSpending == 99.99)
        
        let suppliers = try await purchaseService.getDistinctSuppliers()
        #expect(suppliers.contains("Glass Supply Co"))
    }
}

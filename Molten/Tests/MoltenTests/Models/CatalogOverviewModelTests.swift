//
//  CatalogOverviewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 2025-11-12.
//  Tests for CatalogOverviewModel factory method
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Molten

@MainActor
@Suite("CatalogOverviewModel Tests")
struct CatalogOverviewModelTests {

    @Test("Should create overview model with statistics")
    func testFactoryMethod() {
        let overview = CatalogOverviewModel.from(
            totalItems: 100,
            totalManufacturers: 10,
            totalTags: 50,
            itemsWithInventory: 75,
            lowStockItems: 5,
            systemType: "GlassItem"
        )

        #expect(overview.totalItems == 100)
        #expect(overview.totalManufacturers == 10)
        #expect(overview.totalTags == 50)
        #expect(overview.itemsWithInventory == 75)
        #expect(overview.lowStockItems == 5)
        #expect(overview.systemType == "GlassItem")
    }

    @Test("Should handle zero values")
    func testZeroValues() {
        let overview = CatalogOverviewModel.from(
            totalItems: 0,
            totalManufacturers: 0,
            totalTags: 0,
            itemsWithInventory: 0,
            lowStockItems: 0,
            systemType: "GlassItem"
        )

        #expect(overview.totalItems == 0)
        #expect(overview.totalManufacturers == 0)
        #expect(overview.totalTags == 0)
        #expect(overview.itemsWithInventory == 0)
        #expect(overview.lowStockItems == 0)
    }
}

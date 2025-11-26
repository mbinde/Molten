import Foundation
import Testing
@testable import Molten

@Suite("Debug CatalogViewModel")
@MainActor
struct DebugCatalogViewModelTests {
    
    @Test("Debug manufacturer counts")
    func debugManufacturerCounts() async throws {
        // Create test items
        let glassItem = GlassItemModel(
            stable_id: "bullseye-001-glass",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            mfr_notes: nil,
            coe: 90,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        let catalogItem = UnifiedCatalogItem(glassItem: glassItem)
        let completeItem = CompleteInventoryItemModel(
            catalogItem: catalogItem,
            inventory: [],
            tags: [],
            userTags: []
        )
        
        let toolItem = ToolItemModel(
            stable_id: "ennion-T01-tool",
            name: "Glass Cutter",
            sku: "T01",
            manufacturer: "ennion",
            mfr_notes: nil,
            url: nil,
            mfr_status: "available",
            image_url: nil,
            image_path: nil
        )
        let toolCatalogItem = UnifiedCatalogItem(toolItem: toolItem)
        let completeTool = CompleteInventoryItemModel(
            catalogItem: toolCatalogItem,
            inventory: [],
            tags: [],
            userTags: []
        )
        
        let items = [completeItem, completeTool]
        
        // Create ViewModel
        let viewModel = CatalogViewModel(
            catalogService: AppDependencies.shared.catalogService
        )
        
        print("=== DEBUG START ===")
        print("Items created: \(items.count)")
        for item in items {
            print("  - \(item.catalogItem.name): type=\(item.catalogItem.itemType.rawValue), manufacturer=\(item.catalogItem.manufacturer)")
        }
        
        // Set items
        viewModel.items = items
        print("\nAfter setting items:")
        print("  viewModel.items.count = \(viewModel.items.count)")
        print("  viewModel.selectedProductTypes = \(viewModel.selectedProductTypes)")
        
        // Set filter
        viewModel.selectedProductTypes = ["glass"]
        print("\nAfter setting filter to ['glass']:")
        print("  viewModel.selectedProductTypes = \(viewModel.selectedProductTypes)")
        
        // Check manufacturer counts
        let counts = viewModel.manufacturerCounts
        print("\nManufacturer counts:")
        for (manufacturer, count) in counts {
            print("  - \(manufacturer): \(count)")
        }
        print("  Total manufacturers: \(counts.count)")
        print("  Keys: \(Array(counts.keys))")
        
        print("=== DEBUG END ===")
        
        #expect(counts.keys.contains("bullseye"), "Should contain bullseye")
    }
}

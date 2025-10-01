# New JSON Fields Support

This document outlines the support added for three new fields in the CatalogItem JSON parsing: `stock_type`, `image_url`, and `manufacturer_url`.

## New Fields

### 1. `stock_type` (String, Optional)
Represents the current stock status of the catalog item.
- Common values: `"in_stock"`, `"out_of_stock"`, `"limited_stock"`, `"discontinued"`
- Supports both `snake_case` (`stock_type`) and `camelCase` (`stockType`) JSON keys

### 2. `image_url` (String, Optional)
URL pointing to the product image.
- Should be a valid URL string
- Supports both `snake_case` (`image_url`) and `camelCase` (`imageUrl`) JSON keys

### 3. `manufacturer_url` (String, Optional)
URL pointing to the manufacturer's website or product page.
- Should be a valid URL string
- Supports both `snake_case` (`manufacturer_url`) and `camelCase` (`manufacturerUrl`) JSON keys

## JSON Examples

### Snake Case Format (Recommended)
```json
[
    {
        "code": "GLR-001",
        "name": "Clear Glass Rod",
        "manufacturer": "Effetre",
        "stock_type": "in_stock",
        "image_url": "https://example.com/images/glr-001.jpg",
        "manufacturer_url": "https://effetre.com/products/clear-glass-rod"
    }
]
```

### Camel Case Format (Also Supported)
```json
[
    {
        "code": "GLR-002",
        "name": "Blue Glass Rod",
        "manufacturer": "Effetre",
        "stockType": "limited_stock",
        "imageUrl": "https://example.com/images/glr-002.jpg",
        "manufacturerUrl": "https://effetre.com/products/blue-glass-rod"
    }
]
```

### Mixed Format with Optional Fields
```json
[
    {
        "code": "GLR-003",
        "name": "Red Glass Rod",
        "manufacturer": "Effetre",
        "stock_type": "out_of_stock"
        // image_url and manufacturer_url are optional
    },
    {
        "code": "GLR-004",
        "name": "Green Glass Rod",
        "manufacturer": "Effetre",
        "imageUrl": "https://example.com/images/glr-004.jpg"
        // Only image_url provided, others optional
    }
]
```

## Implementation Details

### Files Modified
1. **`CatalogDataModels.swift`**
   - Added three new optional properties to `CatalogItemData`
   - Updated custom `init(from decoder:)` to handle new fields
   - Updated regular initializer with default parameters
   - Added new coding keys for both snake_case and camelCase variants

2. **`CatalogItemManager.swift`**
   - Updated `updateCatalogItemAttributes()` to set new attributes
   - Enhanced `shouldUpdateExistingItem()` to check for changes in new fields
   - Updated temporary data creation for comparison logic

3. **`TestUtilities.swift`**
   - Updated sample JSON to include the new fields for testing

4. **`DataLoadingServiceTests.swift`**
   - Enhanced existing tests to verify new fields
   - Added comprehensive test for different JSON key formats
   - Added Core Data integration test for new fields

### Backward Compatibility
- All new fields are optional, so existing JSON files will continue to work
- The system gracefully handles missing fields by setting them to `nil`
- Core Data integration uses `CoreDataHelpers.setAttributeIfExists()` to avoid crashes if the Core Data model doesn't have these attributes yet

### Error Handling
- JSON parsing will not fail if new fields are missing
- Invalid URL formats are accepted as strings (validation can be added later if needed)
- Empty strings are treated as valid values (can be filtered out in business logic if needed)

## Testing

The implementation includes comprehensive tests that verify:
- JSON parsing with snake_case keys
- JSON parsing with camelCase keys  
- Handling of optional/missing fields
- Core Data integration without crashes
- Backward compatibility with existing JSON formats

## Usage in Code

After parsing, the new fields are available on `CatalogItemData` instances:

```swift
let catalogItem: CatalogItemData = // ... decoded from JSON
print("Stock Status: \(catalogItem.stock_type ?? "Unknown")")
print("Image URL: \(catalogItem.image_url ?? "No image")")
print("Manufacturer URL: \(catalogItem.manufacturer_url ?? "No URL")")
```

## Core Data Integration

The new fields are automatically handled by the existing Core Data integration:
- They are stored using `CoreDataHelpers.setAttributeIfExists()`
- They participate in the update comparison logic
- They work with merge operations without requiring Core Data model changes

Note: To fully utilize these fields in the UI, you may need to add corresponding attributes to your Core Data model and update your SwiftUI views accordingly.
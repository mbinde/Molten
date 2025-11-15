# Image Sync Strategy

This document explains how Molten manages product images with network awareness and checksum validation.

## Overview

Molten uses a three-tier image strategy:
1. **Bundled thumbnails** - Shipped with the app for offline access
2. **Cached thumbnails** - Downloaded from R2 and cached locally
3. **On-demand full images** - Downloaded when viewing item details (WiFi only)

## Network Awareness

The app respects user network conditions and preferences:

- **WiFi**: Download all images freely
- **Cellular**: Only if user enables "Allow cellular downloads" (default: OFF)
- **Offline**: Use bundled and cached images only

## When Images Are Downloaded

### 1. After Catalog Update (WiFi or Cellular if enabled)

When the app downloads a new catalog, it:

```swift
let syncService = ImageSyncService()
try await syncService.syncThumbnailsAfterCatalogUpdate(catalogItems: items)
```

This will:
- Fetch the image manifest to get current ETags
- Compare with locally cached ETags
- Download **only thumbnails** that are new or have changed
- Respect network conditions (WiFi vs cellular)
- Rate limit downloads to be network-friendly

### 2. When Viewing an Item (WiFi only)

When viewing item details, full-size images are loaded:

```swift
let syncService = ImageSyncService()
let image = await syncService.loadImageForViewing(
    itemCode: item.itemCode,
    manufacturer: item.manufacturer,
    imagePath: item.imagePath
)
```

This will:
- First check local cache (fast)
- If not cached and on **WiFi**, download full-size image
- If on cellular, return nil (show thumbnail instead)

### 3. Background Refresh (WiFi only, daily)

The app can periodically check for updated images:

```swift
let syncService = ImageSyncService()
try await syncService.performBackgroundImageRefresh()
```

This will:
- Only run on WiFi
- Check if 24 hours have passed since last check
- Fetch manifest and compare ETags
- Download **only thumbnails** that have changed
- Rate limit downloads

## Cost of Checking for Updates

**Q: How expensive is it to check if images have changed?**

**A: Very cheap!** Here's why:

1. **One manifest request**: A single JSON API call returns all images with their ETags
   - Size: ~500KB for 7,768 images
   - Contains: filename, ETag, size, lastModified for each image

2. **Local ETag comparison**: We compare the manifest ETags with locally stored ETags
   - No network required for comparison
   - O(n) operation on image list

3. **Only download what changed**: We only download images where ETags differ
   - If nothing changed: 0 bytes transferred (after manifest)
   - If 10 images changed: ~100KB transferred (thumbnails)

**Cost breakdown:**
- **Manifest fetch**: ~500KB (once per day max)
- **Per-image comparison**: Free (local operation)
- **Downloads**: Only changed images

## Implementation Details

### ETag Storage

Each cached image has an associated `.etag` file:

```
~/Library/Application Support/Molten/DownloadedImages/
├── BB-650001_thumb.jpg
├── BB-650001_thumb.jpg.etag    <- Contains ETag from R2
├── BB-650001.jpg
└── BB-650001.jpg.etag
```

### Checksum Validation Flow

```
1. Fetch manifest
   ↓
2. For each image in manifest:
   ↓
3. Read local ETag from cache
   ↓
4. Compare with manifest ETag
   ↓
5. If different or missing:
   ↓
6. Download image
   ↓
7. Save image + ETag to cache
```

### Network Decision Tree

```
User wants to view item with image
         ↓
    Is cached?
    ↙       ↘
  YES       NO
   ↓         ↓
Return    What network?
cached    ↙    ↓    ↘
        WiFi  Cell  Offline
         ↓     ↓      ↓
      Download? Return
         ↓     (based on nil
      Return  preference)
      image
```

## Integration Examples

### After Catalog Download

```swift
// In your catalog download service
class CatalogDataLoadingService {
    private let imageSyncService = ImageSyncService()

    func loadCatalog() async throws {
        // 1. Download catalog data (CatalogItemData from JSON)
        let items: [CatalogItemData] = try await downloadCatalogJSON()

        // 2. Sync thumbnails for new/changed items
        try await imageSyncService.syncThumbnailsAfterCatalogUpdate(
            catalogItems: items
        )

        // 3. Save to database
        try await saveCatalogToDatabase(items)
    }
}
```

### In Item Detail View

```swift
struct ItemDetailView: View {
    @State private var fullImage: UIImage?
    private let imageSyncService = ImageSyncService()

    var body: some View {
        VStack {
            if let image = fullImage {
                Image(uiImage: image)
            } else {
                Image(uiImage: item.thumbnailImage) // Bundled or cached
            }
        }
        .task {
            // Load full image on WiFi
            fullImage = await imageSyncService.loadImageForViewing(
                itemCode: item.itemCode,
                manufacturer: item.manufacturer,
                imagePath: item.imagePath
            )
        }
    }
}
```

### Background Refresh (BGTaskScheduler)

```swift
import BackgroundTasks

func scheduleImageRefresh() {
    let request = BGProcessingTaskRequest(identifier: "com.molten.imageRefresh")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false

    try? BGTaskScheduler.shared.submit(request)
}

func handleImageRefresh(task: BGProcessingTask) {
    Task {
        let syncService = ImageSyncService()
        try? await syncService.performBackgroundImageRefresh()
        task.setTaskCompleted(success: true)
    }
}
```

## User Preferences

Users can control cellular downloads:

```swift
let syncService = ImageSyncService()

// Enable cellular downloads
syncService.allowCellularDownloads = true

// Disable cellular downloads (default)
syncService.allowCellularDownloads = false
```

This affects:
- ✅ Catalog update thumbnail sync
- ❌ Item detail full image loading (always WiFi only)
- ❌ Background refresh (always WiFi only)

## Testing

Integration tests are provided in `ImageDownloadIntegrationTests.swift`:

```bash
# Run image sync tests
xcodebuild test \
  -project Molten.xcodeproj \
  -scheme Molten \
  -testPlan IntegrationTests
```

Key tests:
- `testFetchManifest()` - Verifies manifest API works
- `testDownloadAndCacheImage()` - Tests download and cache flow
- `testETagStorageAndValidation()` - Tests checksum validation
- `testDetectChangedImages()` - Tests update detection

## Performance Characteristics

| Operation | Network Cost | Time | Frequency |
|-----------|-------------|------|-----------|
| Manifest fetch | ~500KB | ~1s | Once per day max |
| ETag comparison | 0 bytes | <100ms | After manifest fetch |
| Thumbnail download | ~10KB each | ~0.5s each | Only changed images |
| Full image download | ~100KB each | ~2s each | On-demand, WiFi only |

## Best Practices

1. **Always check cache first** - Cached images are instant
2. **Respect network conditions** - Use `shouldDownloadImages()` before downloads
3. **Rate limit downloads** - Don't hammer the network
4. **Check for updates daily** - Balance freshness vs network usage
5. **Prefer thumbnails** - Full images only when needed
6. **Handle offline gracefully** - Always have bundled fallbacks

## Future Enhancements

1. **Smart preloading** - Predict which images user will view next
2. **Background refresh scheduling** - Use BGTaskScheduler for periodic checks
3. **Batch download optimization** - Download multiple images in parallel
4. **Storage management** - Auto-cleanup old cached images
5. **Analytics** - Track cache hit rate and download patterns

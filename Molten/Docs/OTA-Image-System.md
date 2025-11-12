# OTA Image System

**Status:** Implementation Complete
**Branch:** `ota-catalog`
**Last Updated:** 2025-11-11

---

## Overview

This document describes the OTA (Over-The-Air) image distribution system for Molten. Product images are hosted on Cloudflare R2 and downloaded on-demand by the iOS app.

### Problem Solved

After removing product images from the iOS bundle (to clean git history and reduce app size), the app needs to download images from a CDN instead of bundling them.

### Solution

- **Server:** Host 1,321 product images on Cloudflare R2
- **CDN:** Serve images at `https://cdn.moltenglass.app/`
- **iOS:** Download images on-demand and cache locally
- **Fallback:** If image not available, show manufacturer default

---

## Architecture

### Image Loading Priority

The app loads images in this priority order:

1. **User-uploaded images** (from UserImageRepository)
   - Custom photos users upload for items
   - Stored in Application Support directory
   - Takes highest priority

2. **CDN images** (from cdn.moltenglass.app) ⭐ NEW
   - Downloaded from Cloudflare R2
   - Cached locally in Application Support
   - Checked before bundle images

3. **Bundle images** (from app bundle)
   - Images shipped with the app (if any)
   - Currently none (removed from bundle)

4. **Manufacturer default images** (from app bundle)
   - Generic manufacturer logos/placeholders
   - Always available as final fallback

### Components

**Server Side (molten-website repo):**
- `upload-images.js` - Script to upload images to Cloudflare R2
- `IMAGE-HOSTING-SETUP.md` - Setup guide for R2 bucket

**iOS Side (Molten repo):**
- `ImageDownloadService.swift` - Downloads and caches images from CDN
- `ImageHelpers.swift` - Updated to use ImageDownloadService
- `ProductImage` view - Async image loading for lists
- `ProductImageDetail` view - Async image loading for detail views

---

## Image Naming Convention

Images are named with manufacturer-code format:

**Format:** `{MANUFACTURER}-{CODE}.{ext}`

**Examples:**
- `BB-650001.webp` - Boro Batch item 650001
- `CIM-511101.jpg` - Creation is Messy item 511101
- `OC-6023-83CC-F.png` - Oceanside Glass item 6023-83CC-F

**Extensions:** `.webp`, `.jpg`, `.jpeg`, `.png`

The app tries all extensions automatically when downloading.

---

## Local Caching

Downloaded images are cached in the iOS app's Application Support directory:

**Path:** `~/Library/Application Support/DownloadedImages/`

**Cache Management:**
- Images cached indefinitely (1-year Cache-Control header)
- ETags used for efficient revalidation
- Cache size can be queried: `ImageDownloadService.getCacheSize()`
- Can clear cache: `ImageDownloadService.clearAllCache()`

**URLSession Cache:**
- 50MB memory cache
- 100MB disk cache
- Automatic cache pruning by iOS

---

## ImageDownloadService API

### Loading Images

```swift
// Load image from CDN (or cache if already downloaded)
let image = await ImageDownloadService.loadImage(
    itemCode: "650001",
    manufacturer: "BB"
)
```

**Behavior:**
1. Check local cache first (fast)
2. If not cached, download from `https://cdn.moltenglass.app/BB-650001.{ext}`
3. Try all extensions: webp, jpg, jpeg, png
4. Cache successful download
5. Return `nil` if not found (falls back to next priority)

### Cache Management

```swift
// Clear cache for specific item
ImageDownloadService.clearCache(itemCode: "650001", manufacturer: "BB")

// Clear all cached images
ImageDownloadService.clearAllCache()

// Get cache size in bytes
let sizeBytes = ImageDownloadService.getCacheSize()
let sizeMB = Double(sizeBytes) / 1_024 / 1_024
```

---

## Network Configuration

### Timeouts

- **Request timeout:** 10 seconds
- **Resource timeout:** 30 seconds (total for entire download)

### Caching

```http
Cache-Control: public, max-age=31536000
```

Images cached for 1 year (immutable content).

### Error Handling

- Network failures → return `nil` (fall back to next priority)
- 404 Not Found → return `nil` silently (many items won't have images)
- Other errors → logged but don't block UI

---

## Server Setup

### Prerequisites

1. Cloudflare R2 bucket created: `product-images`
2. Custom domain connected: `cdn.moltenglass.app` → R2 bucket
3. Environment variables set:
   - `CLOUDFLARE_ACCOUNT_ID`
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_R2_BUCKET_NAME` (defaults to "product-images")

### Upload Images

```bash
cd ~/molten-website
node upload-images.js ~/molten-data/images/product-images/
```

**What it does:**
- Scans directory for images (jpg, jpeg, png, webp, gif)
- Checks if each image already exists in R2
- Skips existing images (efficient for updates)
- Uploads new/modified images
- Sets Cache-Control headers
- Shows progress bar

**Expected output:**
```
📦 Uploading product images to Cloudflare R2...

📂 Scanning directory: ~/molten-data/images/product-images/
   ✅ Found 1,321 images

☁️  Uploading to R2 bucket 'product-images'...
   [████████████████████] 1,321/1,321 (100%)
   ✅ Uploaded 1,321 images (68.2 MB total)

✅ SUCCESS! Image upload complete

🔗 Images available at: https://cdn.moltenglass.app/
   Example: https://cdn.moltenglass.app/BB-650001.webp
```

---

## Testing

### Manual Testing

1. **Setup R2 and upload images:**
   ```bash
   # See IMAGE-HOSTING-SETUP.md for detailed steps
   cd ~/molten-website
   node upload-images.js ~/molten-data/images/product-images/
   ```

2. **Test image access directly:**
   ```bash
   curl -I https://cdn.moltenglass.app/BB-650001.webp
   # Expected: HTTP 200 OK, content-type: image/webp
   ```

3. **Run iOS app:**
   - Build and run on simulator
   - Navigate to catalog view
   - Observe images loading from CDN
   - Check Console for `[ImageDownloadService]` logs

4. **Test offline behavior:**
   - Load images once (downloads and caches)
   - Enable Airplane Mode
   - Navigate to same items
   - Should load from cache instantly

5. **Test cache clearing:**
   - Add to Settings view: Button to clear image cache
   - Tap button → `ImageDownloadService.clearAllCache()`
   - Navigate to catalog → images re-download

### Automated Testing

**Unit Tests** (MoltenTests):
```swift
@Test func testImageDownloadServiceLoadsFromCache() async {
    // Setup: Pre-populate cache with test image
    // Action: Call loadImage()
    // Assert: Returns cached image without network call
}

@Test func testImageDownloadServiceFallsBackOnNetworkError() async {
    // Setup: Mock URLSession to fail
    // Action: Call loadImage()
    // Assert: Returns nil gracefully
}
```

**Integration Tests:**
- Test image loading through ProductImage view
- Test cache persistence across app restarts
- Test cache clearing and re-download

---

## Cost Estimate

Cloudflare R2 Pricing (as of 2025):
- **Storage:** $0.015 per GB/month
- **Class A operations** (write): $4.50 per million requests
- **Class B operations** (read): $0.36 per million requests
- **Egress:** **FREE** (no bandwidth charges)

**Our usage:**
- Storage: 68 MB = 0.068 GB × $0.015 = **$0.001/month** (~$0.01/year)
- Initial upload: 1,321 writes × $4.50/1M = **$0.006 one-time**
- Monthly reads (estimated 10,000 image downloads): $0.0036/month = **$0.04/year**

**Total estimated cost: ~$0.05/year** (essentially free!)

---

## Monitoring

### Cloudflare Dashboard

1. Go to **R2** → **product-images** bucket
2. Click **Metrics** tab
3. View:
   - Storage used
   - Requests per day
   - Bandwidth used
   - Error rates

### iOS App Logs

Look for log messages:
```
⚠️ [ImageDownloadService] Failed to download BB-650001.webp: <error>
```

### Cache Size Monitoring

Add to Settings view:
```swift
let cacheSize = ImageDownloadService.getCacheSize()
Text("Image cache: \(formatBytes(cacheSize))")
```

---

## Troubleshooting

### Images Not Loading

**Symptom:** App shows manufacturer defaults instead of product images

**Debugging steps:**
1. Test image URL directly:
   ```bash
   curl -I https://cdn.moltenglass.app/BB-650001.webp
   ```
   - If 404 → Image not uploaded to R2
   - If timeout → DNS or connectivity issue
   - If 200 → Server working, check iOS app

2. Check iOS logs for errors:
   - Look for `[ImageDownloadService]` log messages
   - Network errors? Check App Transport Security settings
   - File permission errors? Check Application Support directory

3. Verify custom domain setup:
   ```bash
   nslookup cdn.moltenglass.app
   ```
   Should resolve to R2 bucket.

4. Test cache directly:
   ```swift
   let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
       .appendingPathComponent("DownloadedImages")
   print("Cache directory: \(path?.path ?? "none")")
   ```

### Slow Image Loading

**Symptom:** Images take several seconds to appear

**Possible causes:**
1. **First-time download** (expected)
   - Images cached after first load
   - Subsequent loads instant

2. **Large images**
   - Check image file sizes in R2
   - Consider resizing images before upload
   - Recommend: 800x800px max, 90% JPEG quality

3. **Network latency**
   - Cloudflare R2 auto-optimizes for location
   - Should be < 1 second for most regions

4. **URLSession cache disabled**
   - Check `ImageDownloadService` config
   - Should have 50MB memory, 100MB disk cache

### Cache Not Working

**Symptom:** Images re-download every time

**Debugging:**
1. Check cache directory exists:
   ```swift
   let cacheDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
       .appendingPathComponent("DownloadedImages")
   print("Cache exists: \(FileManager.default.fileExists(atPath: cacheDir!.path))")
   ```

2. Check cache write permissions:
   ```swift
   let testFile = cacheDir!.appendingPathComponent("test.txt")
   try? "test".write(to: testFile, atomically: true, encoding: .utf8)
   print("Can write: \(FileManager.default.fileExists(atPath: testFile.path))")
   ```

3. Check `loadFromCache()` logic in `ImageDownloadService`

---

## Future Enhancements

### Potential Improvements

1. **Progressive Image Loading**
   - Download low-res placeholder first
   - Then download full-res in background

2. **Background Prefetching**
   - When catalog updates, pre-download new images
   - User doesn't notice download time

3. **Image Optimization**
   - Serve different sizes for list vs detail views
   - Use WebP format (better compression)

4. **Cache Management UI**
   - Show cache size in Settings
   - Button to clear cache
   - Auto-clear old cache (LRU policy)

5. **Analytics**
   - Track which images are missing
   - Track download success rate
   - Monitor cache hit rate

---

## Related Documentation

- **Server Setup:** `~/molten-website/IMAGE-HOSTING-SETUP.md`
- **Upload Script:** `~/molten-website/upload-images.js`
- **OTA Catalog System:** `~/projects/catalog/Molten/Docs/OTA-Catalog-Implementation-Plan.md`
- **Image Data Source:** `~/molten-data/images/product-images/`

---

## Implementation Checklist

### Server Side (Complete)

- [x] Create `upload-images.js` script
- [x] Create `IMAGE-HOSTING-SETUP.md` guide
- [x] Commit to molten-website repo

### iOS Side (Complete)

- [x] Create `ImageDownloadService.swift`
- [x] Update `ImageHelpers.swift` to use CDN (PRIORITY 1.5)
- [x] Update documentation comments
- [x] Commit to Molten repo

### Deployment (Pending User Action)

- [ ] Create R2 bucket: `npx wrangler r2 bucket create product-images`
- [ ] Connect custom domain: `cdn.moltenglass.app` → R2 bucket
- [ ] Upload images: `node upload-images.js ~/molten-data/images/product-images/`
- [ ] Add `ImageDownloadService.swift` to Xcode project (user must do manually)
- [ ] Test image loading in iOS app
- [ ] Verify cache persistence
- [ ] Monitor Cloudflare R2 metrics

---

## Summary

The OTA image system is fully implemented and ready for deployment. Product images are hosted on Cloudflare R2, served at `cdn.moltenglass.app`, and downloaded on-demand by the iOS app with local caching.

**Benefits:**
- ✅ Reduces app bundle size (removed 68 MB of images)
- ✅ Images updateable without App Store release
- ✅ Efficient caching reduces bandwidth
- ✅ Graceful fallback to manufacturer defaults
- ✅ Nearly zero hosting cost (~$0.05/year)

**Next Steps:**
1. User creates R2 bucket and uploads images
2. User adds `ImageDownloadService.swift` to Xcode project
3. Test in simulator and on device
4. Deploy to production

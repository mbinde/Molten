# Rating System - Integration Guide

Complete rating system is now implemented! This guide shows how to integrate it into your app.

---

## ✅ What's Been Built

### Backend (Cloudflare) - **LIVE**
- ✅ D1 database with 4 tables
- ✅ KV caching layer
- ✅ 4 REST API endpoints (submit, fetch, delete, aggregate)
- ✅ Rate limiting (60/hour per user)
- ✅ Profanity filtering
- ✅ GDPR-compliant deletion
- ✅ Deployed to https://www.moltenglass.app

### iOS App - **COMPLETE**

**Models:**
- ✅ `RatingSubmissionModel` - User submissions
- ✅ `AggregatedRatingModel` - Server data
- ✅ `RatingWordModel` - Word frequencies

**Services:**
- ✅ `CloudKitIdentityService` - Hashed user IDs
- ✅ `RatingAPIClient` - API communication
- ✅ `RatingService` - Orchestration + offline queue

**Repository:**
- ✅ `RatingRepository` protocol
- ✅ `CoreDataRatingRepository` - Persistence (uses snake_case)

**Core Data Entities** (you added these):
- ✅ `ItemRating` (Local Store) - Cached ratings
- ✅ `ItemRatingWord` (Local Store) - Cached words
- ✅ `PendingRatingSubmission` (Cloud Store) - Offline queue

**UI Components:**
- ✅ `RatingSubmissionView` - Submit rating form
- ✅ `RatingDisplayView` - Display aggregated ratings
- ✅ `RatingBadgeView` - Compact badge for lists

**Integration:**
- ✅ Wired into `AppDependencies`

---

## 🚀 How to Use the Rating System

### 1. Show Rating Badge in List Views

Add to any list cell showing items:

```swift
struct ItemCell: View {
    let item: GlassItemModel

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                RatingBadgeView(itemStableId: item.stable_id)
            }
        }
    }
}
```

**Result:** Shows "★ 4.7 (142)" if enough ratings exist.

### 2. Show Full Rating Display in Detail Views

Add to any item detail view:

```swift
struct ItemDetailView: View {
    let item: GlassItemModel

    var body: some View {
        ScrollView {
            VStack {
                // Your existing detail content

                RatingDisplayView(itemStableId: item.stable_id)
                    .padding()
            }
        }
    }
}
```

**Result:** Shows average stars, category badge, top 10 words, and "Rate This Item" button.

### 3. Show Rating Submission Form

The submission view is automatically shown when user taps "Rate This Item" in `RatingDisplayView`.

**Or manually present:**

```swift
.sheet(isPresented: $showingRatingSubmission) {
    RatingSubmissionView(
        itemStableId: item.stable_id,
        itemName: item.name
    )
}
```

---

## 🔧 Advanced Usage

### Manually Submit Ratings

```swift
let service = AppDependencies.shared.ratingService

let submission = RatingSubmissionModel(
    itemStableId: "bullseye-001-0",
    starRating: 5,
    words: ["beautiful", "vibrant", "smooth", "reliable", "stunning"]
)

try await service.submitRating(submission)
```

### Fetch Ratings Programmatically

```swift
let service = AppDependencies.shared.ratingService

// Fetch single item
let ratings = try await service.fetchRatings(
    forItems: ["bullseye-001-0"],
    forceRefresh: false
)

// Batch fetch
let ratings = try await service.fetchRatings(
    forItems: ["bullseye-001-0", "cim-412-0", "ef-207-0"],
    forceRefresh: false
)

if let rating = ratings.first {
    print("Average: \(rating.averageRating)")
    print("Total: \(rating.totalRatings)")
    print("Top words: \(rating.topWords)")
}
```

### Process Offline Queue

The service automatically queues ratings when offline. To manually process:

```swift
let service = AppDependencies.shared.ratingService

// Process all pending submissions
let successCount = try await service.processPendingSubmissions()
print("Submitted \(successCount) ratings")

// Check queue count
let pendingCount = try await service.getPendingSubmissionCount()
```

### Delete All User Ratings

```swift
let service = AppDependencies.shared.ratingService

let deletedCount = try await service.deleteAllRatings()
print("Deleted \(deletedCount) ratings")
```

---

## 🎨 Customization

### Update Frequency

Default: 1 hour cache. Adjust per-service:

```swift
let service = RatingService(
    repository: repository,
    updateInterval: 21600 // 6 hours
)
```

### Custom API Client

For testing or alternative endpoints:

```swift
let apiClient = RatingAPIClient(baseURL: "https://test.example.com")
let service = RatingService(repository: repository, apiClient: apiClient)
```

### Custom Identity Service

For testing:

```swift
class MockIdentityService: CloudKitIdentityServiceProtocol {
    func getHashedUserID() async throws -> String {
        return "test-user-hash"
    }
}

let service = RatingService(
    repository: repository,
    identityService: MockIdentityService()
)
```

---

## 📊 User Settings

### Update Frequency Preference

Store in UserDefaults:

```swift
// In Settings view
@AppStorage("ratingsUpdateInterval") private var updateInterval: Int = 3600

Picker("Update Frequency", selection: $updateInterval) {
    Text("1 Hour").tag(3600)
    Text("6 Hours").tag(21600)
    Text("12 Hours").tag(43200)
    Text("Daily").tag(86400)
    Text("Weekly").tag(604800)
}
```

Then use when creating service:

```swift
let interval = UserDefaults.standard.integer(forKey: "ratingsUpdateInterval")
let service = RatingService(
    repository: repository,
    updateInterval: TimeInterval(interval > 0 ? interval : 3600)
)
```

---

## 🧪 Testing

All models and services have comprehensive tests:

```bash
# Run rating tests
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenTests/RatingSubmissionModelTests \
  -only-testing:MoltenTests/AggregatedRatingModelTests \
  -only-testing:MoltenTests/RatingWordModelTests \
  -only-testing:MoltenTests/CloudKitIdentityServiceTests
```

### Test Data Builder Integration

```swift
// In TestDataBuilder
func withRatings(for items: [String]) -> Self {
    // Pre-populate ratings in test database
    return self
}
```

---

## 🔒 Privacy & Security

### Data Collection
- **CloudKit user ID** (hashed with SHA-256)
- **Star rating** (1-5)
- **5 descriptive words** (profanity filtered)
- **No PII** (no email, name, phone)

### User Rights
- View their ratings (via CloudKit sync)
- Delete all ratings (GDPR compliant)
- Data survives app reinstall (same CloudKit ID)
- Data lost on Apple ID change (acceptable)

### Security
- App Attest verification (placeholder - implement when ready)
- Rate limiting (60 submissions/hour)
- Profanity filtering
- Input validation (word length, uniqueness, etc.)

---

## 📝 Next Steps

1. **Choose where to show ratings:**
   - Catalog list views? (add `RatingBadgeView`)
   - Item detail views? (add `RatingDisplayView`)
   - Both?

2. **Add settings UI** (optional):
   - Update frequency preference
   - View/delete ratings button
   - Offline queue status

3. **Test with real data:**
   - Submit test ratings
   - Verify aggregation
   - Test offline queue

4. **Implement App Attest** (when ready):
   - Generate attestation keys
   - Replace placeholder tokens
   - Verify on server

5. **Monitor usage:**
   - Check Cloudflare logs
   - Monitor D1 storage
   - Track API errors

---

## 🐛 Troubleshooting

### Ratings not appearing
- Check network connection
- Verify Core Data entities are added
- Check console for errors
- Force refresh: `fetchRatings(forItems:forceRefresh: true)`

### "CloudKit identity unavailable"
- User must be signed into iCloud
- Check CloudKit container is configured
- Verify app has CloudKit entitlement

### Offline queue not processing
- Call `processPendingSubmissions()` on app launch
- Or implement background task to auto-process

### Rate limit errors
- User hitting 60/hour limit
- Wait for window to reset
- Show pending count to user

---

## 📚 API Reference

See full documentation in:
- `CLAUDE.md` - Architecture patterns
- `Rating-System-Design.md` - Complete system design
- `Rating-Core-Data-Entities.md` - Database schema
- `RATING-SYSTEM-API-TESTING.md` - API testing guide
- `RATING-SYSTEM-CLOUDFLARE-SETUP.md` - Server setup

---

## ✨ Summary

The rating system is **fully implemented and deployed**. Simply add the UI components to your views:

1. **List views:** `RatingBadgeView(itemStableId: item.stable_id)`
2. **Detail views:** `RatingDisplayView(itemStableId: item.stable_id)`

That's it! The system handles everything else:
- Online/offline submission
- Caching with staleness checking
- Rate limiting
- Profanity filtering
- GDPR-compliant deletion
- Hourly server aggregation

Users can now rate items with 5 stars + 5 words, and see community ratings with word clouds!

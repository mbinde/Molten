# Sentry Error Tracking Reference

Complete reference for Sentry error tracking in Molten. This document provides an accurate record of what's being logged to Sentry for dashboard setup and alerting.

---

## What's Being Tracked

### 1. Catalog Downloads (`operation:catalog-download`)

**Location:** `CatalogUpdateService.swift:123-127, 245-251`

**Success Events (Level: Info)**
```swift
logger.info("Catalog download completed successfully", context: [
    "operation": "catalog-download",
    "version": String,           // e.g., "1.2.3"
    "item_count": Int,           // e.g., 2659
    "file_size_mb": Double       // e.g., 25.5
])
```

**Failure Events (Level: Error)**
```swift
logger.error("Catalog download failed", context: [
    "operation": "catalog-download",
    "version": String,           // Version attempted
    "progress": Double,          // 0.0-1.0, how far download got
    "error_type": String,        // e.g., "URLError", "NetworkTimeout"
    "file_size_mb": Double       // File size in MB
], error: Error)
```

**When It Logs:**
- ✅ **Success**: Every successful catalog download and installation
- ❌ **Error**: Network failures, checksum mismatches, database replacement failures
- Also logs during update check failures (see below)

**Update Check Failures (Level: Error)**
```swift
logger.error("Catalog update check failed", context: [
    "operation": "catalog-update-check",
    "error_type": String
], error: Error)
```

---

### 2. Rating Cache Rebuilds (`operation:rating-cache-rebuild`)

**Location:** `RatingService.swift:121-125, 131-136, 139-146`

**Success Events (Level: Info)**
```swift
logger.info("Rating cache updated successfully", context: [
    "operation": "rating-cache-rebuild",
    "items_updated": Int,        // Number of ratings updated
    "forced_refresh": Bool       // true if cache was force-refreshed
])
```

**Degraded Mode (Level: Warning)**
```swift
logger.warning("Rating fetch failed, using stale cache", context: [
    "operation": "rating-cache-rebuild",
    "items_requested": Int,      // How many ratings were requested
    "stale_items_returned": Int  // How many stale ratings returned
])
```

**Failure Events (Level: Error)**
```swift
logger.error("Rating cache rebuild failed", context: [
    "operation": "rating-cache-rebuild",
    "items_requested": Int,      // How many ratings were requested
    "had_cached_data": Bool,     // Whether cache existed to fall back on
    "error_type": String         // Type of error encountered
], error: Error)
```

**When It Logs:**
- ✅ **Success**: Cache successfully updated from API
- ⚠️ **Warning**: Network failed but stale cache exists (degraded mode)
- ❌ **Error**: Complete failure with no cache to fall back on

---

### 3. CloudKit Sync (`operation:cloudkit-sync`)

**Location:** `CloudKitSyncMonitor.swift:170-175, 185-190, 198-204`

**Quota Exceeded (Level: Error)**
```swift
logger.error("CloudKit quota exceeded", context: [
    "operation": "cloudkit-sync",
    "sync_type": String,         // "import" or "export"
    "error_code": Int            // 10 (CKError.quotaExceeded)
], error: Error)
```

**Offline/Network Unavailable (Level: Warning)**
```swift
logger.warning("CloudKit sync offline", context: [
    "operation": "cloudkit-sync",
    "sync_type": String,         // "import" or "export"
    "error_code": Int            // 3 (networkUnavailable) or 4 (networkFailure)
])
```

**Generic Sync Failures (Level: Error)**
```swift
logger.error("CloudKit sync failed", context: [
    "operation": "cloudkit-sync",
    "sync_type": String,         // "import" or "export"
    "error_domain": String,      // e.g., "CKErrorDomain"
    "error_code": Int,           // CloudKit error code
    "error_type": String         // Type name of error
], error: Error)
```

**When It Logs:**
- ❌ **Error**: Quota exceeded, sync failures (non-network)
- ⚠️ **Warning**: Device offline or network unavailable
- **Note**: Success is NOT logged (would be too noisy)

---

## Testing

**Location:** Settings → Debug → Test Sentry Logging (`SentryTestView.swift`)

The test view sends sample events with `"test": true` in the context so you can filter them out:

```
Sentry filter to exclude tests: !test:true
```

**Available Tests:**
- Catalog download error
- Catalog download success
- Rating cache error
- Rating cache success
- Rating cache degraded (warning)
- CloudKit sync error
- CloudKit quota exceeded
- CloudKit offline

---

## Common Queries

### All Catalog Failures
```
operation:catalog-download AND level:error
```

### All Rating Cache Issues
```
operation:rating-cache-rebuild AND (level:error OR level:warning)
```

### CloudKit Quota Problems
```
operation:cloudkit-sync AND error_code:10
```

### All Network/Offline Errors
```
(operation:cloudkit-sync AND error_code:3) OR
(operation:cloudkit-sync AND error_code:4) OR
(operation:rating-cache-rebuild AND level:warning)
```

### Production Errors Only (exclude tests)
```
level:error AND !test:true
```

### Last 24 Hours
```
timestamp:>now-24h
```

---

## Recommended Alerts

### Alert 1: Catalog Download Failures
```
Name: "Catalog Download Failing"
Condition: event count > 3 in 1 hour
Filter: operation:catalog-download AND level:error AND !test:true
Action: Email notification
Priority: High
```

**Why:** If catalog downloads fail > 3 times/hour, API or CDN is likely having issues.

---

### Alert 2: Rating Cache Problems
```
Name: "Rating Cache Issues"
Condition: event count > 10 in 1 hour
Filter: operation:rating-cache-rebuild AND level:error AND !test:true
Action: Email notification
Priority: Medium
```

**Why:** Rating API should be reliable. Many failures indicate API downtime.

---

### Alert 3: CloudKit Quota Exceeded
```
Name: "iCloud Quota Exceeded"
Condition: any event
Filter: operation:cloudkit-sync AND error_code:10 AND !test:true
Action: Email notification
Priority: Critical
```

**Why:** Users hitting quota limits can't sync. Needs immediate attention.

---

### Alert 4: CloudKit Sync Failures
```
Name: "CloudKit Sync Degraded"
Condition: event count > 20 in 6 hours
Filter: operation:cloudkit-sync AND level:error AND !test:true
Action: Email notification
Priority: Medium
```

**Why:** CloudKit should generally work. Many failures = infrastructure problems.

---

## Dashboard Widgets

### Widget 1: Catalog Downloads (Last 24h)
```
Query: operation:catalog-download AND !test:true
Visualization: Line chart
Group by: level
Y-axis: Event count
```

Shows success vs failure rate over time.

---

### Widget 2: Rating Cache Health
```
Query: operation:rating-cache-rebuild AND !test:true
Visualization: Pie chart
Group by: level (info, warning, error)
```

Shows proportion of successful vs degraded vs failed cache rebuilds.

---

### Widget 3: CloudKit Sync Status
```
Query: operation:cloudkit-sync AND !test:true
Visualization: Stacked bar chart
Group by: sync_type, level
Y-axis: Event count
```

Shows import vs export failures separately.

---

### Widget 4: Error Rate by Operation
```
Query: level:error AND !test:true
Visualization: Line chart (hourly buckets)
Group by: operation
```

Shows which operations are failing most frequently.

---

### Widget 5: Top Error Types
```
Query: level:error AND !test:true
Visualization: Table
Group by: error_type
Columns: error_type, count, last_seen
Limit: 10
```

Shows most common error types across all operations.

---

### Widget 6: Catalog Download Progress on Failure
```
Query: operation:catalog-download AND level:error AND !test:true
Visualization: Histogram
Field: progress
Buckets: 0-0.25, 0.25-0.5, 0.5-0.75, 0.75-1.0
```

Shows at what point in the download process failures occur.

---

## Context Fields Reference

### Common Fields (All Operations)

| Field | Type | Description |
|-------|------|-------------|
| `operation` | String | Operation identifier (catalog-download, rating-cache-rebuild, cloudkit-sync) |
| `error_type` | String | Error class name (e.g., "URLError", "CKError") |
| `test` | Bool | true if from test view, false/absent otherwise |

### Catalog Download Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | String | Catalog version (e.g., "1.2.3") |
| `item_count` | Int | Number of items in catalog (success only) |
| `file_size_mb` | Double | File size in megabytes |
| `progress` | Double | Download progress 0.0-1.0 (failures only) |

### Rating Cache Fields

| Field | Type | Description |
|-------|------|-------------|
| `items_updated` | Int | Ratings updated (success only) |
| `items_requested` | Int | Ratings requested |
| `forced_refresh` | Bool | Whether cache was force-refreshed (success only) |
| `stale_items_returned` | Int | Stale ratings returned (degraded mode only) |
| `had_cached_data` | Bool | Whether cache existed (failures only) |

### CloudKit Sync Fields

| Field | Type | Description |
|-------|------|-------------|
| `sync_type` | String | "import" or "export" |
| `error_code` | Int | CloudKit error code (10=quota, 3=offline, 4=network) |
| `error_domain` | String | Error domain (usually "CKErrorDomain") |

---

## CloudKit Error Codes

| Code | Name | Meaning |
|------|------|---------|
| 2 | `internalError` | CloudKit internal error |
| 3 | `networkUnavailable` | No network connection |
| 4 | `networkFailure` | Network request failed |
| 6 | `serviceUnavailable` | CloudKit service down |
| 10 | `quotaExceeded` | iCloud storage quota exceeded |
| 11 | `requestRateLimited` | Too many requests |

---

## Investigation Playbook

### "Why are catalog downloads failing?"

**Query:** `operation:catalog-download AND level:error`

**Look at:**
- `error_type`: Network vs checksum vs database errors?
- `progress`: Failing early (network) or late (database)?
- `file_size_mb`: Large files timing out?
- Timeline: Clustered (outage) or scattered (user network)?

**Common Issues:**
- `progress: 0.0-0.3` → Network connection/DNS issues
- `progress: 0.9-1.0` → Database replacement failures
- `error_type: "ChecksumMismatch"` → Corrupted downloads or CDN issues

---

### "Are users hitting iCloud quota limits?"

**Query:** `operation:cloudkit-sync AND error_code:10`

**Look at:**
- Event frequency: How many users affected?
- `sync_type`: Import (downloading) or export (uploading)?
- Timeline: New users (initial sync) or existing (data growth)?

**Actions:**
- Monitor frequency for quota limit warnings
- Consider user notification for quota issues
- Check if sync failures correlate with app updates (data model changes)

---

### "Is the rating API down?"

**Query:** `operation:rating-cache-rebuild AND level:error`

**Look at:**
- `had_cached_data`: Are users impacted or falling back to cache?
- Timeline: Outage window or intermittent?
- `error_type`: API timeout vs network vs parsing?

**Also check:**
```
operation:rating-cache-rebuild AND level:warning
```

If many warnings (stale cache used), API is down but users aren't blocked.

---

## Changelog

### Version 1.0 (2025-11-15)
- Initial Sentry integration
- Added catalog download tracking
- Added rating cache tracking
- Added CloudKit sync tracking
- Created test view for validation

---

## See Also

- `Molten/Docs/Logging-and-Error-Tracking.md` - General logging architecture
- `SentryTestView.swift` - Test view for sending sample events
- `CatalogUpdateService.swift` - Catalog download implementation
- `RatingService.swift` - Rating cache implementation
- `CloudKitSyncMonitor.swift` - CloudKit sync monitoring

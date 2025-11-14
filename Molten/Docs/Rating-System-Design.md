# Rating System Design

## Overview
Community-driven rating system where users can submit 1-5 star ratings and five descriptive words for all items (glass, tools, coatings).

## Architecture

### Client (iOS App)
- **Storage**: Core Data (Local Store - no CloudKit sync)
- **Identity**: CloudKit user record ID (hashed)
- **Verification**: App Attest for request authentication
- **Update Frequency**: User-configurable (1 hour to 1 week)

### Server (Cloudflare)
- **API**: Workers (REST endpoints)
- **Storage**: D1 (SQLite) for individual submissions
- **Cache**: KV for aggregated results (edge-cached)
- **Aggregation**: Cron Triggers (periodic)

---

## Core Data Schema

### ItemRating Entity
**Configuration:**
- Store: Local Store (no CloudKit sync)
- Code Generation: Category
- Syncable: YES

**Attributes:**
- `itemStableId: String` - Links to Item.stable_id
- `averageRating: Double` - Average star rating (1.0-5.0)
- `totalRatings: Int64` - Total number of ratings submitted
- `lastUpdated: Date` - When aggregated data was last fetched from server

**Indexes:**
- `itemStableId` (for fast lookups)

### ItemRatingWord Entity
**Configuration:**
- Store: Local Store (no CloudKit sync)
- Code Generation: Category
- Syncable: YES

**Attributes:**
- `itemStableId: String` - Links to Item.stable_id
- `word: String` - The word (lowercased, trimmed)
- `frequency: Int64` - How many times this word was submitted
- `rank: Int16` - Sort order (1 = most frequent)

**Indexes:**
- Compound: `itemStableId + rank` (for fast ordered fetches)

**Notes:**
- Store top 50 words per item (server returns top 50)
- Client displays top 10-15 as simple list
- Server stores ALL words (no artificial limit)
- Follows existing `ItemTags` pattern (separate rows, not JSON)

---

## Server Schema

### D1 Database (SQLite)

**Table: rating_submissions**
```sql
CREATE TABLE rating_submissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_stable_id TEXT NOT NULL,
  cloudkit_user_id_hash TEXT NOT NULL,
  star_rating INTEGER NOT NULL CHECK(star_rating >= 1 AND star_rating <= 5),
  submitted_at INTEGER NOT NULL, -- Unix timestamp
  app_attest_token TEXT NOT NULL,

  INDEX idx_item (item_stable_id),
  INDEX idx_user (cloudkit_user_id_hash),
  INDEX idx_submitted (submitted_at)
);
```

**Table: word_submissions**
```sql
CREATE TABLE word_submissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_stable_id TEXT NOT NULL,
  cloudkit_user_id_hash TEXT NOT NULL,
  word TEXT NOT NULL,
  position INTEGER NOT NULL CHECK(position >= 1 AND position <= 5),
  submitted_at INTEGER NOT NULL, -- Unix timestamp

  INDEX idx_item_word (item_stable_id, word),
  INDEX idx_user (cloudkit_user_id_hash)
);
```

**Table: rate_limits**
```sql
CREATE TABLE rate_limits (
  cloudkit_user_id_hash TEXT PRIMARY KEY,
  submission_count INTEGER NOT NULL DEFAULT 0,
  window_start INTEGER NOT NULL, -- Unix timestamp (hourly window)

  INDEX idx_window (window_start)
);
```

**Notes:**
- Each rating submission creates 1 row in `rating_submissions`
- Each rating submission creates 5 rows in `word_submissions` (one per word)
- User can submit one rating per item (server enforces via cloudkit_user_id_hash)
- Updating rating replaces previous submission (delete old, insert new)
- Free-form word input with profanity filter (1-30 chars, alphanumeric + basic punctuation)
- Rate limiting: 60 submissions per hour per user (tracked in `rate_limits` table)

### KV Store

**Key Pattern:** `ratings:aggregated:{item_stable_id}`

**Value (JSON):**
```json
{
  "itemStableId": "bullseye-001-0",
  "averageRating": 4.7,
  "totalRatings": 142,
  "topWords": [
    {"word": "beautiful", "frequency": 89, "rank": 1},
    {"word": "vibrant", "frequency": 67, "rank": 2},
    {"word": "smooth", "frequency": 45, "rank": 3},
    ...
  ],
  "lastAggregated": 1699564800
}
```

**TTL:** 1 week (refreshed by cron job)

---

## API Endpoints

### POST /api/ratings/submit
**Request:**
```json
{
  "itemStableId": "bullseye-001-0",
  "cloudkitUserIdHash": "sha256(cloudkit_user_id)",
  "starRating": 5,
  "words": ["beautiful", "vibrant", "smooth", "reliable", "stunning"],
  "appAttestToken": "..."
}
```

**Response:**
```json
{
  "success": true,
  "message": "Rating submitted"
}
```

**Validation:**
- App Attest token must be valid
- Star rating 1-5
- Exactly 5 words (1-30 chars each, alphanumeric + basic punctuation)
- Profanity filter applied to words
- User can only have one rating per item (upsert behavior)
- Rate limit: 60 submissions per hour per user

### GET /api/ratings/fetch?items={stable_id1,stable_id2,...}
**Response:**
```json
{
  "ratings": [
    {
      "itemStableId": "bullseye-001-0",
      "averageRating": 4.7,
      "totalRatings": 142,
      "topWords": [
        {"word": "beautiful", "frequency": 89, "rank": 1},
        ...
      ],
      "lastAggregated": 1699564800
    }
  ]
}
```

**Notes:**
- Batch fetch (up to 100 items per request)
- Returns from KV cache (edge-cached, fast)
- Missing items return null (no ratings yet)

### DELETE /api/ratings/delete
**Request:**
```json
{
  "cloudkitUserIdHash": "sha256(cloudkit_user_id)",
  "appAttestToken": "..."
}
```

**Response:**
```json
{
  "success": true,
  "deletedCount": 12
}
```

**Notes:**
- Deletes all ratings/words for this user
- Triggers re-aggregation for affected items

---

## Aggregation Cron Job

**Schedule:** Every 1 hour

**Process:**
1. Identify items with new ratings since last aggregation (check `submitted_at`)
2. For each item:
   - Calculate average star rating
   - Count total ratings
   - Aggregate word frequencies (top 20)
3. Update KV cache with new aggregated data
4. Record last aggregation timestamp

**Optimization:**
- Only re-aggregate items with changes
- Batch KV writes (up to 1000 keys per batch)

---

## Privacy & Deletion

**User Identity:**
- CloudKit user record ID (hashed with SHA-256)
- No PII stored (no email, name, phone)
- Survives app reinstalls and device upgrades
- Only breaks when user changes Apple ID (acceptable - their CloudKit data is already lost)

**Deletion:**
- User can delete all ratings via in-app button
- Server deletes all records matching `cloudkit_user_id_hash`
- Affected items are re-aggregated
- If user deletes app and reinstalls, same CloudKit ID = can still delete

**GDPR Compliance:**
- No PII stored (hashed CloudKit ID is pseudonymous)
- User can delete via app
- If user changes Apple ID, old ratings become orphaned but anonymous

---

## Update Frequency Settings

**Options:**
- 1 hour (most current, higher data usage)
- 6 hours
- 12 hours
- 24 hours (daily)
- 1 week (default)

**Implementation:**
- Store in UserDefaults: `ratingsUpdateIntervalHours: Int`
- Background fetch checks `lastUpdated` in `ItemRating` entities
- Only fetch if `lastUpdated + interval` has passed

---

## TDD Implementation Order

1. **Models & Core Data**
   - `ItemRating` and `ItemRatingWord` entities
   - `RatingSubmissionModel` and `AggregatedRatingModel` (domain models)

2. **Services**
   - `CloudKitIdentityService` (get hashed user ID)
   - `AppAttestService` (generate attestation tokens)
   - `RatingService` (orchestrate submit/fetch/delete)

3. **Repositories**
   - `RatingRepository` protocol
   - `CoreDataRatingRepository` (persist aggregated ratings locally)
   - `MockRatingRepository` (for tests)

4. **Server**
   - Workers endpoints (submit, fetch, delete)
   - D1 schema migration
   - KV caching layer
   - Aggregation cron job

5. **UI**
   - Rating submission view (stars + 3 word inputs)
   - Rating display view (average stars + word cloud)
   - Settings for update frequency

---

## Offline Queue

**Implementation:**
- Store pending submissions in Core Data (Cloud Store)
- Entity: `PendingRatingSubmission`
- Attributes:
  - `itemStableId: String`
  - `starRating: Int16`
  - `word1, word2, word3, word4, word5: String`
  - `createdAt: Date`
  - `attempts: Int16` (retry tracking)
- Background task monitors network and submits queue when online
- Remove from queue on successful submission
- Max 3 retry attempts, then mark as failed (user can manually retry)

---

## Open Questions

1. **Profanity filter**: Use iOS-native content filtering or third-party library?
2. **Migration**: How to handle schema changes in D1? Version the API?
3. **Analytics**: Track submission success/failure rates for monitoring?
4. **Moderation**: Admin interface for reviewing flagged words/ratings?

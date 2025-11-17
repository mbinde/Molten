# Expiring Shares Implementation Guide

## Overview

Expiring shares are time-limited aliases to the user's main inventory share. Each expiring share has:
- Its own unique 6-character share code
- Custom display name and notes
- Fixed expiration time (cannot be extended)
- Reference to the main share's inventory data

## Core Data Entity

### ExpiringShareRecord (Cloud Store)

Add this entity to the Molten.xcdatamodel (Cloud configuration):

**Attributes:**
- `id` (UUID, required) - Unique identifier
- `shareCode` (String, required, indexed) - 6-character share code
- `mainShareCode` (String, required, indexed) - Reference to main share
- `displayName` (String, required) - Display name for this share
- `shareNotes` (String, optional) - Public notes for this share
- `expiresAt` (Date, required, indexed) - When this share expires
- `createdAt` (Date, required) - When this share was created

**Important:**
- Add to "Cloud" configuration (syncs via CloudKit)
- Index `shareCode`, `mainShareCode`, and `expiresAt` for performance

## Server API

### Data Model (Server-side)

```typescript
interface ExpiringShareRecord {
  shareCode: string;          // 6-character code for THIS alias
  mainShareCode: string;      // Reference to main share
  displayName: string;        // Display name for this alias
  shareNotes?: string;        // Notes for this alias
  expiresAt: string;          // ISO 8601 timestamp
  createdAt: string;          // ISO 8601 timestamp
  createdIp: string;          // IP that created this
}
```

### API Endpoints

#### 1. Create Expiring Share

**POST `/api/v1/share/expiring`**

Request:
```json
{
  "mainShareCode": "ABC123",
  "displayName": "GAS 2025 Share",
  "shareNotes": "Available during conference only",
  "expirationDuration": 86400  // seconds (1 day)
}
```

Response (201):
```json
{
  "shareCode": "XYZ789",
  "expiresAt": "2025-01-20T15:30:00Z"
}
```

**Logic:**
1. Verify main share exists
2. Generate new unique share code
3. Calculate expiration (now + duration)
4. Store expiring share record
5. Return new share code

**Rate Limiting:** 20 creates per hour per IP

#### 2. Get Expiring Shares for Main Share

**GET `/api/v1/share/:mainShareCode/expiring`**

Response (200):
```json
{
  "expiringShares": [
    {
      "shareCode": "XYZ789",
      "displayName": "GAS 2025 Share",
      "shareNotes": "Available during conference only",
      "expiresAt": "2025-01-20T15:30:00Z",
      "createdAt": "2025-01-19T15:30:00Z"
    }
  ]
}
```

#### 3. Delete Expiring Share

**DELETE `/api/v1/share/expiring/:shareCode`**

Response (204): No content

#### 4. Download via Expiring Share

**GET `/api/v1/share/:shareCode`** (existing endpoint)

**Updated Logic:**
1. Try to fetch as regular share
2. If not found, try to fetch as expiring share
3. If expiring share:
   - Check if expired → return 410 Gone
   - Fetch main share data
   - Return main share snapshot with expiring share's metadata
   - Increment expiring share's access count

**Response (200):**
```json
{
  "snapshotData": "<base64>",
  "publicKey": "<base64>",
  "displayName": "GAS 2025 Share",  // From expiring share
  "shareNotes": "Available during conference only",  // From expiring share
  "expiresAt": "2025-01-20T15:30:00Z"  // From expiring share
}
```

### Cleanup Job

Server should run periodic cleanup (daily) to delete:
1. Expired expiring shares
2. Expiring shares whose main share no longer exists

## iOS Implementation

### Files Created

1. **ExpiringShare.swift** - Data model ✅
2. **CoreDataExpiringShareRepository.swift** - Local storage ✅
3. **CreateExpiringShareView.swift** - UI for creating
4. **ExpiringSharesListView.swift** - UI for viewing list
5. **InventorySharingAPIClient+ExpiringShares.swift** - API methods

### User Flow

#### Creating an Expiring Share

1. User taps "Create Temporary Share" in InventorySharingView
2. Sheet presents CreateExpiringShareView:
   - Text field for display name
   - Text field for notes (optional)
   - Picker for duration (1 hour, 6 hours, 12 hours, 1 day, 3 days, 1 week, 2 weeks)
   - Preview of expiration time
3. User taps "Create"
4. App calls API to create share
5. New share code is displayed
6. Share is saved locally
7. Sheet dismisses

#### Viewing Expiring Shares

In InventorySharingView, below main share:

```
┌─────────────────────────────────────┐
│ My Inventory                        │
├─────────────────────────────────────┤
│ Your Share Code                     │
│ ABC-123                      [Copy] │
│                                     │
│ Display Name: John's Glass          │
│ Notes: Main share                   │
│                                     │
│ [Update Inventory on Server]        │
│ [Delete Share]                      │
├─────────────────────────────────────┤
│ Temporary Shares                    │
├─────────────────────────────────────┤
│ XYZ-789                             │
│ GAS 2025 Share                      │
│ Expires in 2 days              [×]  │
│                                     │
│ [Create Temporary Share]            │
└─────────────────────────────────────┘
```

#### Automatic Cleanup

- When user opens InventorySharingView, expired shares are automatically deleted
- When main share is deleted, all expiring shares are deleted
- When user refreshes main share, expiring shares remain valid

## Testing

### Manual Test Cases

1. **Create expiring share** - verify new code is generated
2. **Download via expiring share** - verify returns main share data with expiring metadata
3. **Delete expiring share** - verify it's removed
4. **Main share deletion** - verify expiring shares are cascaded
5. **Expiration** - verify expired shares return 410 Gone
6. **Multiple expiring shares** - verify multiple aliases work
7. **Different metadata** - verify each share has unique display name/notes

### API Testing

```bash
# Create main share first
curl -X POST https://www.moltenglass.app/api/v1/share \
  -H "Content-Type: application/json" \
  -d '{"shareCode":"ABC123","snapshotData":"...","publicKey":"..."}'

# Create expiring share
curl -X POST https://www.moltenglass.app/api/v1/share/expiring \
  -H "Content-Type: application/json" \
  -d '{"mainShareCode":"ABC123","displayName":"Test","expirationDuration":3600}'

# Download via expiring code
curl https://www.moltenglass.app/api/v1/share/XYZ789

# List expiring shares
curl https://www.moltenglass.app/api/v1/share/ABC123/expiring

# Delete expiring share
curl -X DELETE https://www.moltenglass.app/api/v1/share/expiring/XYZ789
```

## Security Considerations

1. **Rate limiting** - 20 expiring share creates per hour per IP
2. **No extension** - Cannot extend expiration (must create new share)
3. **Server-enforced expiration** - Client cannot bypass expiration
4. **App Attest** - All create/delete operations require App Attest assertion
5. **Cascade deletion** - Expiring shares deleted when main share deleted

## Future Enhancements

1. **Usage analytics** - Track how many times each expiring share was accessed
2. **Revocation** - Allow user to revoke (delete) expiring share before expiration
3. **Custom durations** - Allow user to set custom expiration time
4. **Notifications** - Notify user when expiring share is about to expire

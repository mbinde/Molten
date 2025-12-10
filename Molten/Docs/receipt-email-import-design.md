# Receipt Email Import - Design Doc

## Overview

Allow Pro users to forward purchase receipts to Molten, which parses them, matches items to the catalog, and presents extracted glass items for review/import into their inventory.

## User Flow

1. **Setup (in-app)**
   - User enables receipt import in Settings (Pro-gated)
   - Generates unique receipt user ID (separate from sharing ID)
   - User chooses identification method:
     - **Option A**: Register their email address (can forward from that address)
     - **Option B**: Generate unique ingestion address (`receipts+{userId}@moltenglass.app`)
   - Can configure both simultaneously

2. **Sending Receipts**
   - User forwards receipt email to `receipts@moltenglass.app` (Option A) or their unique address (Option B)

3. **Review & Import**
   - App polls for pending receipts
   - User sees list of parsed items matched to catalog entries, with quantities and prices
   - User reviews, edits matches if needed, then imports to inventory
   - User can thumbs up/down the parse quality

## System Components

### Email Worker (`receipts@moltenglass.app`)

Receives forwarded emails and:
1. Identifies user via:
   - Plus-addressed userId (`receipts+abc123@...`), OR
   - Lookup of forwarding sender's email in registered emails table (verified only)
2. Rejects if no user match:
   - Sends bounce reply explaining email not recognized
   - Throttled: max 1 bounce per sender email per day (avoid spam)
3. Stores raw email in R2 for processing
4. Queues parse job (or parses inline if fast enough)

### Email Verification Flow

1. User registers email in app → API stores with `verified=false`, generates token
2. Worker sends verification email via Cloudflare Email Sending:
   - From: `noreply@moltenglass.app`
   - Contains link: `https://moltenglass.app/verify-email?token={token}`
3. User clicks link → verifies token → marks email as verified
4. Only verified emails are matched against incoming receipts

### Receipt Parser

Input: Raw email (HTML + plain text)
Output: Structured data
```
{
  retailer: "Mountain Glass Arts",
  order_id: "12345",
  order_date: "2024-01-15",
  items: [
    {
      raw_name: "Effetre 006 Super Clear",
      raw_sku: "EFF-006",
      qty: 5,
      unit_price: 4.50,
      catalog_match: {
        stable_id: "A3F9K2",
        confidence: 0.95
      }
    },
    ...
  ],
  shipping: 12.50,
  total: 35.00
}
```

Parser strategy: Start with retailer-specific templates for major vendors, fall back to LLM extraction for unknown formats.

### Catalog Matching

- Reads catalog.sqlite from Cloudflare KV/R2 (same source app uses)
- First identifies manufacturer from retailer/email context or item text
- Matches parsed items to catalog entries by manufacturer + one of:
  - SKU code (exact match, highest confidence)
  - Product name (fuzzy match)
- All matches scoped to manufacturer (SKUs and names are not unique across manufacturers)
- Returns confidence score (0-1) for each match
- Unmatched items flagged for manual selection in app

### Data Storage (D1)

**receipt_users**
| id | created_at |

**registered_emails**
| user_id | email | verified | verification_token | token_expires_at | created_at |

- Users can register multiple email addresses per account
- Emails must be verified before they're used for receipt matching
- Verification via Cloudflare Email Sending (Workers outbound email)

**receipts**
| id | user_id | status | retailer | order_id | order_date | parsed_data (JSON) | raw_email_r2_key | created_at | downloaded_at | user_rating | parse_issues (JSON) |

Status: `pending_review` | `imported` | `dismissed`

- `downloaded_at`: timestamp when app fetched this receipt
- `user_rating`: null, `good`, or `bad` (thumbs up/down)
- `parse_issues`: any errors/warnings encountered during parse

### Rate Limiting

Per user:
- 30 receipts per minute
- 100 receipts per hour
- 500 receipts per day

Excess emails rejected (with bounce reply suggesting they slow down).

### API Endpoints

`POST /api/v1/receipts/register`
- Creates new receipt user, returns user_id and unique ingestion address

`GET /api/v1/receipts/pending?user_id={id}`
- Returns pending receipts for user (those not yet downloaded)
- App polls this

`GET /api/v1/receipts/{id}?user_id={id}`
- Returns full receipt detail
- Sets `downloaded_at` timestamp

`POST /api/v1/receipts/{id}/status`
- Update status: `imported` or `dismissed`

`POST /api/v1/receipts/{id}/rating`
- Submit user rating: `good` or `bad`

`POST /api/v1/receipts/emails`
- Register forwarding email address for user
- Sends verification email with token link

`POST /api/v1/receipts/emails/verify?token={token}`
- Verifies email address via token from email link

`DELETE /api/v1/receipts/emails/{email}`
- Remove registered email

`GET /api/v1/receipts/config?user_id={id}`
- Returns user's unique ingestion address and registered emails

### Admin/QA Endpoints

`GET /api/v1/admin/receipts/issues`
- Returns receipts with parse_issues or bad ratings
- For manual review and parser improvement

## Data Retention

- Raw emails: indefinite (stored in R2)
- Parsed receipts: indefinite
- Track `downloaded_at` for potential future cleanup policy

---

## Implementation Plan

### Phase 1: Infrastructure Setup
1. Create D1 database with tables: `receipt_users`, `registered_emails`, `receipts`, `bounce_log`
2. Create R2 bucket for raw email storage
3. Set up Cloudflare Email Worker for `receipts@moltenglass.app`
4. Configure Email Sending for outbound (verification emails, bounce replies)

### Phase 2: Email Worker (Ingest)
1. Parse incoming email to extract sender, plus-address, raw content
2. User identification logic (plus-address OR verified email lookup)
3. Rate limiting checks (30/min, 100/hr, 500/day per user)
4. Bounce reply logic with 1/day throttle per sender
5. Store raw email in R2, create `receipts` row with status `pending_parse`

### Phase 3: Receipt Parser
1. Build retailer detection (from email sender domain, subject, body patterns)
2. Create retailer-specific parsers for major vendors (start with 3-5 top retailers)
3. LLM fallback parser for unknown formats
4. Extract: retailer, order_id, order_date, line items (name, sku, qty, price), shipping, total
5. Store parse_issues for any warnings/errors

### Phase 4: Catalog Matching
1. Load catalog.sqlite from KV
2. Manufacturer identification from retailer/item context
3. SKU exact match (scoped to manufacturer)
4. Name fuzzy match (scoped to manufacturer)
5. Confidence scoring
6. Update receipt with parsed_data including matches

### Phase 5: API Endpoints
1. `POST /api/v1/receipts/register` - create user, return ID + unique address
2. `POST /api/v1/receipts/emails` - register email, send verification
3. `POST /api/v1/receipts/emails/verify` - verify token
4. `DELETE /api/v1/receipts/emails/{email}` - remove email
5. `GET /api/v1/receipts/config` - get user config
6. `GET /api/v1/receipts/pending` - list pending receipts
7. `GET /api/v1/receipts/{id}` - get receipt detail, mark downloaded
8. `POST /api/v1/receipts/{id}/status` - update status
9. `POST /api/v1/receipts/{id}/rating` - submit rating
10. `GET /api/v1/admin/receipts/issues` - admin QA endpoint

### Phase 6: Admin Web UI
1. Receipt list view (filterable by status, user, has issues)
2. Receipt detail: raw email preview, parsed data, catalog matches with confidence
3. Side-by-side raw email vs parsed output for debugging
4. Re-run parser button for testing changes
5. Basic auth or token protection

### Phase 7: iOS App
1. Settings UI: enable receipt import, show unique address, manage registered emails
2. Email registration flow with verification
3. Pending receipts list view
4. Receipt detail view with matched items
5. Review/edit matches before import
6. Thumbs up/down rating UI
7. Import to inventory action

### Phase 8: Polish & QA
1. Email templates (verification, bounce)
2. Error handling and edge cases
3. Add more retailer-specific parsers based on real usage
4. Monitor admin endpoint for parse issues, iterate on parsers

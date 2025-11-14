# Rating System: Two-Tier Moderation Strategy

## Overview

The rating system uses a **two-tier moderation approach** to balance user experience, privacy, and accuracy:

1. **Tier 1 (Client-side)**: Fast, private word list filtering (ProfanityList.swift)
2. **Tier 2 (Server-side)**: Daily batch ML moderation with Perspective API

## Tier 1: Client-Side Filtering

**Location**: `ProfanityList.swift`

**What it does**:
- Checks submissions against 100+ word comprehensive word list
- Blocks obviously inappropriate content immediately
- Provides instant feedback (no network delay)
- Works offline

**Limitations**:
- Only catches known words/patterns
- Can't detect context or subtle toxicity
- Humans are creative at bypassing word lists

## Tier 2: Server-Side Batch Moderation

### Database Schema Changes

Add moderation tracking to D1 database:

```sql
-- Add moderation columns to rating_submissions
ALTER TABLE rating_submissions ADD COLUMN moderation_status TEXT DEFAULT 'pending';
-- Values: 'pending', 'approved', 'rejected'

ALTER TABLE rating_submissions ADD COLUMN moderation_checked_at INTEGER;
-- Unix timestamp of when moderation was performed

ALTER TABLE rating_submissions ADD COLUMN toxicity_score REAL;
-- Perspective API toxicity score (0.0 - 1.0)

ALTER TABLE rating_submissions ADD COLUMN profanity_score REAL;
-- Perspective API profanity score (0.0 - 1.0)

-- Create index for efficient batch queries
CREATE INDEX idx_moderation_pending ON rating_submissions(moderation_status, created_at);
```

### Cloudflare Worker: Batch Moderation Endpoint

**Endpoint**: `POST /admin/moderate-submissions`

**Trigger**: Cloudflare Cron (daily at 3am UTC)

**Cron Configuration** (`wrangler.toml`):
```toml
[triggers]
crons = ["0 3 * * *"]  # Run at 3am UTC daily
```

**Implementation** (Cloudflare Worker):

```typescript
import { Hono } from 'hono';

const app = new Hono();

// Perspective API configuration
const PERSPECTIVE_API_KEY = env.PERSPECTIVE_API_KEY; // Store in Worker secret
const PERSPECTIVE_URL = 'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';

// Thresholds
const TOXICITY_THRESHOLD = 0.7;  // 70% confidence = toxic
const PROFANITY_THRESHOLD = 0.7; // 70% confidence = profane

interface PerspectiveRequest {
  comment: { text: string };
  languages: string[];
  requestedAttributes: {
    TOXICITY: {};
    SEVERE_TOXICITY: {};
    PROFANITY: {};
  };
}

interface PerspectiveResponse {
  attributeScores: {
    TOXICITY: { summaryScore: { value: number } };
    SEVERE_TOXICITY: { summaryScore: { value: number } };
    PROFANITY: { summaryScore: { value: number } };
  };
}

/**
 * Batch moderate pending submissions using Perspective API
 * Runs daily via Cloudflare Cron
 */
app.post('/admin/moderate-submissions', async (c) => {
  const db = c.env.DB; // D1 database binding

  // 1. Fetch pending submissions (limit to 1000 per day to avoid API costs)
  const pendingSubmissions = await db.prepare(`
    SELECT id, word1, word2, word3, word4, word5
    FROM rating_submissions
    WHERE moderation_status = 'pending'
    ORDER BY created_at ASC
    LIMIT 1000
  `).all();

  if (pendingSubmissions.results.length === 0) {
    return c.json({ message: 'No pending submissions to moderate' });
  }

  let approvedCount = 0;
  let rejectedCount = 0;
  const errors: string[] = [];

  // 2. Process each submission
  for (const submission of pendingSubmissions.results) {
    const words = [
      submission.word1,
      submission.word2,
      submission.word3,
      submission.word4,
      submission.word5,
    ];

    try {
      // 3. Call Perspective API
      const perspectiveRequest: PerspectiveRequest = {
        comment: { text: words.join(' ') },
        languages: ['en'],
        requestedAttributes: {
          TOXICITY: {},
          SEVERE_TOXICITY: {},
          PROFANITY: {},
        },
      };

      const response = await fetch(
        `${PERSPECTIVE_URL}?key=${PERSPECTIVE_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(perspectiveRequest),
        }
      );

      if (!response.ok) {
        errors.push(`API error for submission ${submission.id}: ${response.status}`);
        continue;
      }

      const data: PerspectiveResponse = await response.json();

      const toxicityScore = data.attributeScores.TOXICITY.summaryScore.value;
      const profanityScore = data.attributeScores.PROFANITY.summaryScore.value;

      // 4. Determine moderation decision
      const isRejected =
        toxicityScore >= TOXICITY_THRESHOLD ||
        profanityScore >= PROFANITY_THRESHOLD;

      const status = isRejected ? 'rejected' : 'approved';

      // 5. Update database
      await db.prepare(`
        UPDATE rating_submissions
        SET
          moderation_status = ?,
          moderation_checked_at = ?,
          toxicity_score = ?,
          profanity_score = ?
        WHERE id = ?
      `).bind(
        status,
        Math.floor(Date.now() / 1000),
        toxicityScore,
        profanityScore,
        submission.id
      ).run();

      if (isRejected) {
        rejectedCount++;
      } else {
        approvedCount++;
      }

      // 6. Rate limiting: Wait 100ms between API calls (max 10 req/sec)
      await new Promise(resolve => setTimeout(resolve, 100));

    } catch (error) {
      errors.push(`Error processing submission ${submission.id}: ${error.message}`);
    }
  }

  return c.json({
    processed: pendingSubmissions.results.length,
    approved: approvedCount,
    rejected: rejectedCount,
    errors: errors.length > 0 ? errors : undefined,
  });
});

// Cron trigger handler
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    // Trigger batch moderation
    await fetch(`https://your-worker.workers.dev/admin/moderate-submissions`, {
      method: 'POST',
    });
  },
};
```

### Aggregation Logic Update

Update the aggregation logic to **only include approved submissions**:

```typescript
app.get('/api/ratings/:itemStableId', async (c) => {
  const { itemStableId } = c.param();
  const db = c.env.DB;

  // Only aggregate approved submissions
  const result = await db.prepare(`
    SELECT
      AVG(star_rating) as average_rating,
      COUNT(*) as total_ratings
    FROM rating_submissions
    WHERE item_stable_id = ?
      AND moderation_status = 'approved'  -- ✅ Only approved submissions
  `).bind(itemStableId).first();

  // Word frequency calculation (also filter by moderation_status)
  const words = await db.prepare(`
    SELECT word, COUNT(*) as frequency
    FROM (
      SELECT word1 as word FROM rating_submissions WHERE item_stable_id = ? AND moderation_status = 'approved'
      UNION ALL
      SELECT word2 FROM rating_submissions WHERE item_stable_id = ? AND moderation_status = 'approved'
      UNION ALL
      SELECT word3 FROM rating_submissions WHERE item_stable_id = ? AND moderation_status = 'approved'
      UNION ALL
      SELECT word4 FROM rating_submissions WHERE item_stable_id = ? AND moderation_status = 'approved'
      UNION ALL
      SELECT word5 FROM rating_submissions WHERE item_stable_id = ? AND moderation_status = 'approved'
    )
    GROUP BY word
    ORDER BY frequency DESC
    LIMIT 10
  `).bind(itemStableId, itemStableId, itemStableId, itemStableId, itemStableId).all();

  // ... return aggregated results
});
```

## Benefits of This Approach

### User Experience
- ✅ **Instant feedback** from client-side filtering (no API latency)
- ✅ **Works offline** (client-side list always available)
- ✅ **No false rejections** from overly aggressive real-time ML

### Privacy
- ✅ **Server sees anonymized batch data** (not tied to individual users in real-time)
- ✅ **No real-time user tracking** (moderation happens asynchronously)
- ✅ **On-device first pass** (most obviously inappropriate content never reaches server)

### Cost
- ✅ **Batch API calls** are cheaper than per-submission calls
- ✅ **Rate limiting** (max 1000 submissions/day = ~$0.30/month at Perspective API pricing)
- ✅ **Client-side filtering** reduces API calls for obvious cases

### Accuracy
- ✅ **ML catches creative obfuscation** (f**k, sh1t, etc.)
- ✅ **Context-aware toxicity detection** (not just word matching)
- ✅ **Regularly updated models** (Google maintains Perspective API)

## Monitoring & Alerts

Add monitoring to track moderation effectiveness:

```typescript
// Store moderation stats in KV for dashboard
await env.KV.put('moderation_stats', JSON.stringify({
  last_run: new Date().toISOString(),
  approved_24h: approvedCount,
  rejected_24h: rejectedCount,
  rejection_rate: rejectedCount / (approvedCount + rejectedCount),
}), { expirationTtl: 86400 * 7 }); // Keep for 7 days

// Alert if rejection rate is unusually high (>10%)
if (rejectedCount / (approvedCount + rejectedCount) > 0.1) {
  // Send notification (email, Slack, etc.)
  await sendAlert({
    message: `High moderation rejection rate: ${rejectedCount}/${approvedCount + rejectedCount}`,
  });
}
```

## Manual Review Dashboard (Future Enhancement)

For edge cases, provide an admin dashboard to review flagged submissions:

```typescript
app.get('/admin/flagged-submissions', async (c) => {
  const db = c.env.DB;

  // Show submissions with moderate toxicity (0.5-0.7) for manual review
  const flagged = await db.prepare(`
    SELECT
      id, item_stable_id, star_rating,
      word1, word2, word3, word4, word5,
      toxicity_score, profanity_score,
      created_at
    FROM rating_submissions
    WHERE moderation_status = 'rejected'
      OR (toxicity_score >= 0.5 AND toxicity_score < 0.7)
    ORDER BY created_at DESC
    LIMIT 100
  `).all();

  // Render admin UI with approve/reject buttons
  return c.html(/* admin dashboard HTML */);
});
```

## Deployment Checklist

- [ ] Add `PERSPECTIVE_API_KEY` to Cloudflare Worker secrets
- [ ] Update D1 database schema (add moderation columns)
- [ ] Deploy updated Worker with batch moderation endpoint
- [ ] Configure Cloudflare Cron trigger (3am UTC daily)
- [ ] Update aggregation queries to filter by `moderation_status = 'approved'`
- [ ] Set up monitoring/alerting for high rejection rates
- [ ] Test with sample toxic submissions

## Testing Strategy

1. **Unit test ProfanityList**: Verify comprehensive word list catches obvious cases
2. **Integration test client-side**: Submit profane ratings, verify instant rejection
3. **Test batch moderation**: Submit edge case words, wait for cron, verify ML detection
4. **Test aggregation filtering**: Verify rejected submissions don't affect ratings
5. **Monitor production**: Track rejection rates, adjust thresholds as needed

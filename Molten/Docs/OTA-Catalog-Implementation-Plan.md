# OTA Catalog Implementation Plan

**Branch:** `ota-catalog`
**Target Version:** v1.5.0
**Status:** Planning
**Last Updated:** 2025-11-08

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Server-Side Specifications](#server-side-specifications)
4. [Client-Side Specifications](#client-side-specifications)
5. [Implementation Phases](#implementation-phases)
6. [Testing Strategy](#testing-strategy)
7. [Rollout Plan](#rollout-plan)
8. [Risks & Mitigation](#risks--mitigation)

---

## Overview

### Current State

**What's bundled now:**
- `glassitems.json`: 3,198 items, 3.1 MB, 81,085 lines
- Images: Already CDN-hosted (Shopify URLs in JSON)
- App bundle size: ~15 MB total
- Update frequency: Only with App Store releases

**Existing infrastructure we can leverage:**
- ✅ `InventorySharingAPIClient` - Network request patterns
- ✅ `AttestationManager` - App Attest implementation
- ✅ `URLSessionProtocol` - Testable networking
- ✅ `FirstRunDataLoadingView` - Loading UI patterns
- ✅ `GlassItemDataLoadingService` - Checksum & version tracking
- ✅ Server infrastructure already deployed

### Goals

**Primary:**
1. Enable catalog updates without App Store releases
2. Reduce initial app download size (future)
3. Keep catalog fresh (weekly vs quarterly updates)

**Secondary:**
1. Respect user data plans (WiFi-only option)
2. Protect catalog from scraping
3. Show users catalog version and update status

### Non-Goals (Scope Limits)

- ❌ Image hosting changes (images stay on Shopify CDN)
- ❌ Differential/incremental updates in v1.5 (add in v2.0)
- ❌ Removing bundled catalog in v1.5 (remove in v2.0)
- ❌ Per-manufacturer catalog segments
- ❌ A/B testing catalog layouts

---

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         iOS App                              │
│                                                               │
│  ┌──────────────────┐         ┌─────────────────────┐       │
│  │  SettingsView    │────────▶│ CatalogUpdateService│       │
│  │  - Show version  │         │ - Check updates      │       │
│  │  - Update button │         │ - Download catalog   │       │
│  │  - Preferences   │         │ - Apply updates      │       │
│  └──────────────────┘         └──────────┬──────────┘       │
│                                           │                   │
│  ┌──────────────────┐         ┌──────────▼──────────┐       │
│  │ NetworkMonitor   │────────▶│  CatalogAPIClient   │       │
│  │ - WiFi/cellular  │         │  - GET /version     │       │
│  └──────────────────┘         │  - GET /data        │       │
│                                │  - GET /delta       │       │
│                                └──────────┬──────────┘       │
│                                           │                   │
│                                ┌──────────▼──────────┐       │
│                                │ AttestationManager  │       │
│                                │ - App Attest        │       │
│                                └──────────┬──────────┘       │
│                                           │                   │
│  ┌──────────────────┐         ┌──────────▼──────────┐       │
│  │ CatalogStorage   │◀────────│ GlassItemDataLoading│       │
│  │ Service          │         │ Service              │       │
│  │ - Temp storage   │         │ - Parse JSON         │       │
│  │ - Atomic swap    │         │ - Update Core Data   │       │
│  └──────────────────┘         └─────────────────────┘       │
│                                                               │
└───────────────────────────────┬───────────────────────────────┘
                                │
                                │ HTTPS + Certificate Pinning
                                │ + App Attest
                                │
                    ┌───────────▼──────────────┐
                    │     Server API            │
                    │                           │
                    │  GET /catalog/version     │
                    │  GET /catalog/data        │
                    │  GET /catalog/delta       │
                    │                           │
                    └───────────┬───────────────┘
                                │
                    ┌───────────▼───────────────┐
                    │  Database                 │
                    │  - catalog_versions       │
                    │  - catalog_downloads      │
                    │  - app_attest_keys        │
                    └───────────────────────────┘
```

### Data Flow

**First Run (v1.5 with bundled fallback):**
```
1. App launches
2. Check if catalog exists in Core Data
3. If empty → Load bundled glassitems.json
4. Background: Check for updates from server
5. If update available → Show in Settings
6. User taps "Download" → Download + apply update
```

**Subsequent Launches:**
```
1. App launches
2. Load catalog from Core Data (instant)
3. Background: Check for updates (based on frequency setting)
4. If update available → Show notification/badge
5. User navigates to Settings → See "Update Available"
6. User taps "Download" → Download + apply update
```

**Update Application:**
```
1. Download catalog JSON to temp file
2. Verify checksum
3. Parse JSON
4. Begin Core Data transaction
5. Compare with existing items (by stable_id)
6. Create new items
7. Update changed items
8. Delete removed items (future)
9. Commit transaction
10. Update stored version number
11. Delete temp file
12. Notify UI to refresh
```

---

## Server-Side Specifications

### API Endpoints

#### Base Configuration

```
Production URL: https://api.yourdomain.com
Staging URL: https://staging-api.yourdomain.com

All endpoints:
- HTTPS required (reject HTTP)
- App Attest header: X-Apple-Assertion
- Content-Type: application/json
- Response compression: gzip (if Accept-Encoding: gzip)
```

---

#### 1. GET /catalog/version

**Purpose:** Check latest catalog version metadata

**Request:**
```http
GET /catalog/version HTTP/1.1
Host: api.yourdomain.com
X-Apple-Assertion: <base64-encoded-assertion>
Accept: application/json
```

**Response (200 OK):**
```json
{
  "version": 2,
  "item_count": 3198,
  "release_date": "2025-11-02T08:46:18Z",
  "file_size": 3145728,
  "checksum": "sha256:abc123def456...",
  "min_app_version": "1.5.0",
  "changelog": "Added 15 new AB Imagery colors, updated 7 discontinued Effetre items"
}
```

**Response Codes:**
- `200 OK` - Success
- `401 Unauthorized` - Invalid App Attest assertion
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

**Rate Limits:**
- Per IP: 100 requests/hour
- Per device: 50 requests/hour
- Global: 10,000 requests/hour

**Caching:**
- Cache-Control: public, max-age=3600 (1 hour)
- ETag: version number

---

#### 2. GET /catalog/data

**Purpose:** Download full catalog JSON

**Request:**
```http
GET /catalog/data?version=2 HTTP/1.1
Host: api.yourdomain.com
X-Apple-Assertion: <base64-encoded-assertion>
Accept: application/json
Accept-Encoding: gzip
If-None-Match: "v2-sha256:abc123..."
```

**Query Parameters:**
- `version` (optional): Specific version to download (defaults to latest)

**Response (200 OK):**
```json
{
  "version": "1.0",
  "catalog_data_version": 2,
  "generated": "2025-11-02T08:46:18.213637",
  "item_count": 3198,
  "glassitems": [
    {
      "status": "available",
      "manufacturer": "AB",
      "code": "AB-AR-AGATEGREEN",
      "name": "Agate Green",
      "coe": "33",
      "stable_id": "1ErCJw",
      ...
    },
    ...
  ]
}
```

**Response Headers:**
```http
Content-Type: application/json
Content-Encoding: gzip
Content-Length: 524288
ETag: "v2-sha256:abc123def456..."
Cache-Control: public, max-age=86400
X-Catalog-Version: 2
X-Checksum: sha256:abc123def456...
```

**Response Codes:**
- `200 OK` - Success
- `304 Not Modified` - If-None-Match matches current version
- `401 Unauthorized` - Invalid App Attest assertion
- `404 Not Found` - Requested version doesn't exist
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

**Rate Limits:**
- Per IP: 10 requests/hour
- Per device: 5 requests/hour
- Global: 1,000 requests/hour

**Caching:**
- Cache-Control: public, max-age=86400 (24 hours)
- ETag: "v{version}-{checksum}"

---

#### 3. GET /catalog/delta

**Purpose:** Download incremental changes between versions (v2.0 feature)

**Request:**
```http
GET /catalog/delta?from=1&to=2 HTTP/1.1
Host: api.yourdomain.com
X-Apple-Assertion: <base64-encoded-assertion>
Accept: application/json
```

**Query Parameters:**
- `from` (required): Source version
- `to` (required): Target version

**Response (200 OK):**
```json
{
  "from_version": 1,
  "to_version": 2,
  "generated": "2025-11-02T08:46:18Z",
  "added": [
    {
      "status": "available",
      "manufacturer": "AB",
      "code": "AB-NEW-COLOR",
      "name": "New Color",
      "stable_id": "xyz123",
      ...
    }
  ],
  "updated": [
    {
      "stable_id": "1ErCJw",
      "changes": {
        "name": "Agate Green (Updated)",
        "status": "discontinued"
      }
    }
  ],
  "removed": [
    "olditem1",
    "olditem2"
  ]
}
```

**Response Codes:**
- `200 OK` - Success
- `400 Bad Request` - Invalid version range
- `401 Unauthorized` - Invalid App Attest assertion
- `404 Not Found` - Delta not available for this version range
- `429 Too Many Requests` - Rate limit exceeded

**Rate Limits:**
- Per IP: 20 requests/hour
- Per device: 10 requests/hour

**Note:** Delta endpoint is NOT implemented in v1.5, only full catalog downloads.

---

### Database Schema

```sql
-- Catalog version metadata
CREATE TABLE catalog_versions (
    version INTEGER PRIMARY KEY,
    item_count INTEGER NOT NULL,
    file_size BIGINT NOT NULL,
    checksum VARCHAR(128) NOT NULL,
    release_date TIMESTAMP NOT NULL DEFAULT NOW(),
    min_app_version VARCHAR(20) NOT NULL DEFAULT '1.5.0',
    changelog TEXT,
    file_path VARCHAR(512) NOT NULL,  -- Path to JSON file in storage
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by VARCHAR(255),

    INDEX idx_release_date (release_date DESC),
    INDEX idx_checksum (checksum)
);

-- Download tracking (for analytics and abuse detection)
CREATE TABLE catalog_downloads (
    id SERIAL PRIMARY KEY,
    version INTEGER NOT NULL REFERENCES catalog_versions(version),
    device_fingerprint VARCHAR(255),  -- App Attest key ID
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    download_type VARCHAR(10) NOT NULL,  -- 'full' or 'delta'
    download_size BIGINT,
    success BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT,
    downloaded_at TIMESTAMP NOT NULL DEFAULT NOW(),

    INDEX idx_device (device_fingerprint),
    INDEX idx_ip (ip_address),
    INDEX idx_downloaded_at (downloaded_at DESC),
    INDEX idx_version (version)
);

-- App Attest key storage (reuse from InventorySharing)
CREATE TABLE app_attest_keys (
    key_id VARCHAR(255) PRIMARY KEY,
    public_key BYTEA NOT NULL,
    attestation_object BYTEA NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_used TIMESTAMP,
    assertion_count INTEGER DEFAULT 0,
    device_fingerprint VARCHAR(255),
    is_blocked BOOLEAN DEFAULT FALSE,
    blocked_reason TEXT,

    INDEX idx_last_used (last_used DESC),
    INDEX idx_device_fingerprint (device_fingerprint)
);

-- Rate limiting (per IP and per device)
CREATE TABLE rate_limits (
    id SERIAL PRIMARY KEY,
    identifier VARCHAR(255) NOT NULL,  -- IP or device fingerprint
    endpoint VARCHAR(100) NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 1,
    window_start TIMESTAMP NOT NULL,
    window_end TIMESTAMP NOT NULL,

    PRIMARY KEY (identifier, endpoint, window_start),
    INDEX idx_window_end (window_end)
);

-- Anomaly detection log
CREATE TABLE catalog_anomalies (
    id SERIAL PRIMARY KEY,
    anomaly_type VARCHAR(50) NOT NULL,  -- 'rate_limit', 'suspicious_pattern', etc.
    identifier VARCHAR(255) NOT NULL,  -- IP or device fingerprint
    details JSONB,
    severity VARCHAR(20) NOT NULL,  -- 'low', 'medium', 'high'
    detected_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved BOOLEAN DEFAULT FALSE,

    INDEX idx_detected_at (detected_at DESC),
    INDEX idx_identifier (identifier),
    INDEX idx_severity (severity)
);
```

**Initial Data:**
```sql
-- Insert current catalog as version 1
INSERT INTO catalog_versions (
    version,
    item_count,
    file_size,
    checksum,
    release_date,
    min_app_version,
    changelog,
    file_path,
    created_by
) VALUES (
    1,
    3198,
    3145728,
    'sha256:' || encode(sha256(pg_read_binary_file('/path/to/glassitems.json')::bytea), 'hex'),
    NOW(),
    '1.5.0',
    'Initial catalog version for OTA system',
    '/catalog_data/versions/v1.json.gz',
    'system'
);
```

---

### Server Implementation (Python/Flask)

**File Structure:**
```
server/
├── app.py                     # Main Flask application
├── config.py                  # Configuration
├── models/
│   ├── catalog.py             # Catalog models
│   └── app_attest.py          # App Attest models
├── routes/
│   ├── catalog.py             # Catalog endpoints
│   └── attest.py              # App Attest endpoints
├── services/
│   ├── catalog_service.py     # Catalog business logic
│   ├── app_attest_service.py  # App Attest verification
│   └── rate_limiter.py        # Rate limiting
├── storage/
│   └── catalog_data/          # Catalog JSON files
│       ├── versions/          # v1.json.gz, v2.json.gz
│       └── deltas/            # v1_to_v2.json.gz (future)
├── requirements.txt
└── tests/
    ├── test_catalog_api.py
    └── test_app_attest.py
```

**Key Dependencies:**
```python
# requirements.txt
Flask==3.0.0
Flask-CORS==4.0.0
Flask-Limiter==3.5.0
psycopg2-binary==2.9.9
cryptography==41.0.7
cbor2==5.5.1
gunicorn==21.2.0
redis==5.0.1  # For distributed rate limiting
```

**App Attest Verification (Reuse from InventorySharing):**
```python
# services/app_attest_service.py

import hashlib
import base64
import cbor2
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from models.app_attest import AppAttestKey

class AppAttestService:

    @staticmethod
    def verify_assertion(assertion_base64: str, request) -> bool:
        """
        Verify Apple App Attest assertion.

        Returns:
            True if valid, False otherwise
        """
        try:
            # 1. Decode assertion
            assertion = base64.b64decode(assertion_base64)

            # 2. Parse CBOR
            assertion_obj = cbor2.loads(assertion)
            signature = assertion_obj['signature']
            authenticator_data = assertion_obj['authenticatorData']

            # 3. Reconstruct client data
            method = request.method
            path = request.path
            body_hash = hashlib.sha256(request.get_data() or b'').hexdigest()
            client_data = f"{method}-{path}-{body_hash}".encode('utf-8')
            client_data_hash = hashlib.sha256(client_data).digest()

            # 4. Get stored public key for this key ID
            key_id = AppAttestService._extract_key_id(authenticator_data)
            attest_key = AppAttestKey.query.filter_by(key_id=key_id).first()

            if not attest_key or attest_key.is_blocked:
                return False

            # 5. Verify signature
            public_key = ec.EllipticCurvePublicKey.from_encoded_point(
                ec.SECP256R1(),
                attest_key.public_key
            )

            public_key.verify(
                signature,
                authenticator_data + client_data_hash,
                ec.ECDSA(hashes.SHA256())
            )

            # 6. Update usage stats
            attest_key.assertion_count += 1
            attest_key.last_used = datetime.utcnow()
            db.session.commit()

            return True

        except Exception as e:
            print(f"App Attest verification failed: {e}")
            return False
```

**Rate Limiting:**
```python
# services/rate_limiter.py

from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from redis import Redis

redis_client = Redis(host='localhost', port=6379, db=0)

limiter = Limiter(
    key_func=get_remote_address,
    storage_uri="redis://localhost:6379",
    default_limits=["1000 per hour"]
)

# Custom rate limit decorators
def catalog_version_limit():
    return "100 per hour"  # Per IP

def catalog_data_limit():
    return "10 per hour"  # Per IP

def device_rate_limit(key_id: str, endpoint: str, limit: int, window: int):
    """
    Check rate limit for specific device (App Attest key ID).

    Args:
        key_id: App Attest key ID
        endpoint: API endpoint
        limit: Max requests
        window: Time window in seconds

    Returns:
        True if under limit, False if exceeded
    """
    key = f"device_limit:{key_id}:{endpoint}"
    count = redis_client.get(key)

    if count is None:
        redis_client.setex(key, window, 1)
        return True

    count = int(count)
    if count >= limit:
        return False

    redis_client.incr(key)
    return True
```

**Catalog Endpoints:**
```python
# routes/catalog.py

from flask import Blueprint, request, jsonify, send_file
from services.catalog_service import CatalogService
from services.app_attest_service import AppAttestService
from services.rate_limiter import limiter, device_rate_limit

catalog_bp = Blueprint('catalog', __name__, url_prefix='/catalog')

@catalog_bp.route('/version', methods=['GET'])
@limiter.limit("100 per hour")
def get_version():
    """Get latest catalog version metadata."""

    # Optional: Verify App Attest
    assertion = request.headers.get('X-Apple-Assertion')
    if assertion:
        if not AppAttestService.verify_assertion(assertion, request):
            return jsonify({"error": "Invalid app attestation"}), 401

    # Get latest version
    version_metadata = CatalogService.get_latest_version()

    if not version_metadata:
        return jsonify({"error": "No catalog versions available"}), 404

    return jsonify(version_metadata.to_dict()), 200


@catalog_bp.route('/data', methods=['GET'])
@limiter.limit("10 per hour")
def get_data():
    """Download full catalog JSON."""

    # 1. Verify App Attest (REQUIRED for data downloads)
    assertion = request.headers.get('X-Apple-Assertion')
    if not assertion:
        return jsonify({"error": "App attestation required"}), 401

    if not AppAttestService.verify_assertion(assertion, request):
        return jsonify({"error": "Invalid app attestation"}), 401

    # 2. Extract device fingerprint for per-device rate limiting
    device_id = AppAttestService.extract_device_id(assertion)
    if not device_rate_limit(device_id, 'catalog_data', limit=5, window=3600):
        return jsonify({"error": "Device rate limit exceeded"}), 429

    # 3. Get requested version (or latest)
    requested_version = request.args.get('version', type=int)

    # 4. Check ETag for 304 Not Modified
    if_none_match = request.headers.get('If-None-Match')

    # 5. Load catalog
    catalog_file, metadata = CatalogService.get_catalog_file(requested_version)

    if not catalog_file:
        return jsonify({"error": "Catalog version not found"}), 404

    # 6. Check ETag
    etag = f'"v{metadata.version}-{metadata.checksum}"'
    if if_none_match == etag:
        return '', 304

    # 7. Log download
    CatalogService.log_download(
        version=metadata.version,
        device_fingerprint=device_id,
        ip_address=request.remote_addr,
        user_agent=request.headers.get('User-Agent'),
        download_type='full'
    )

    # 8. Return file with compression
    response = send_file(
        catalog_file,
        mimetype='application/json',
        as_attachment=False,
        download_name=f'catalog_v{metadata.version}.json'
    )

    response.headers['ETag'] = etag
    response.headers['Cache-Control'] = 'public, max-age=86400'
    response.headers['X-Catalog-Version'] = str(metadata.version)
    response.headers['X-Checksum'] = metadata.checksum

    # Compress if client accepts gzip
    if 'gzip' in request.headers.get('Accept-Encoding', ''):
        # Flask will handle gzip compression automatically
        pass

    return response


@catalog_bp.route('/delta', methods=['GET'])
def get_delta():
    """Download delta update (v2.0 feature - not implemented in v1.5)."""
    return jsonify({
        "error": "Delta updates not yet implemented",
        "message": "Please use /catalog/data for full catalog download"
    }), 501  # Not Implemented
```

**Catalog Service:**
```python
# services/catalog_service.py

import gzip
import json
import hashlib
from pathlib import Path
from datetime import datetime
from models.catalog import CatalogVersion, CatalogDownload
from database import db

class CatalogService:

    STORAGE_PATH = Path('/var/catalog_data/versions')

    @staticmethod
    def get_latest_version() -> CatalogVersion:
        """Get latest catalog version metadata."""
        return CatalogVersion.query.order_by(
            CatalogVersion.version.desc()
        ).first()

    @staticmethod
    def get_catalog_file(version: int = None):
        """
        Get catalog file path and metadata.

        Args:
            version: Specific version (or latest if None)

        Returns:
            (file_path, metadata) tuple
        """
        if version:
            metadata = CatalogVersion.query.filter_by(version=version).first()
        else:
            metadata = CatalogService.get_latest_version()

        if not metadata:
            return None, None

        file_path = Path(metadata.file_path)

        if not file_path.exists():
            print(f"ERROR: Catalog file not found: {file_path}")
            return None, None

        return file_path, metadata

    @staticmethod
    def compute_checksum(file_path: Path) -> str:
        """Compute SHA256 checksum of file."""
        sha256 = hashlib.sha256()

        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                sha256.update(chunk)

        return f"sha256:{sha256.hexdigest()}"

    @staticmethod
    def log_download(version: int, device_fingerprint: str, ip_address: str,
                     user_agent: str, download_type: str, success: bool = True,
                     error_message: str = None):
        """Log catalog download for analytics."""

        download = CatalogDownload(
            version=version,
            device_fingerprint=device_fingerprint,
            ip_address=ip_address,
            user_agent=user_agent,
            download_type=download_type,
            success=success,
            error_message=error_message
        )

        db.session.add(download)
        db.session.commit()

    @staticmethod
    def create_new_version(json_file_path: Path, changelog: str,
                          min_app_version: str = '1.5.0') -> CatalogVersion:
        """
        Create a new catalog version from JSON file.

        Args:
            json_file_path: Path to source JSON file
            changelog: Human-readable changelog
            min_app_version: Minimum app version required

        Returns:
            CatalogVersion object
        """
        # 1. Load and parse JSON
        with open(json_file_path, 'r') as f:
            catalog_data = json.load(f)

        item_count = len(catalog_data.get('glassitems', []))

        # 2. Get next version number
        latest = CatalogService.get_latest_version()
        next_version = (latest.version + 1) if latest else 1

        # 3. Compress and save
        output_path = CatalogService.STORAGE_PATH / f'v{next_version}.json.gz'
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with gzip.open(output_path, 'wt', encoding='utf-8') as f:
            json.dump(catalog_data, f)

        # 4. Compute checksum
        checksum = CatalogService.compute_checksum(output_path)
        file_size = output_path.stat().st_size

        # 5. Create database record
        version_record = CatalogVersion(
            version=next_version,
            item_count=item_count,
            file_size=file_size,
            checksum=checksum,
            release_date=datetime.utcnow(),
            min_app_version=min_app_version,
            changelog=changelog,
            file_path=str(output_path),
            created_by='admin'
        )

        db.session.add(version_record)
        db.session.commit()

        print(f"✅ Created catalog version {next_version}")
        print(f"   Items: {item_count}")
        print(f"   Size: {file_size:,} bytes")
        print(f"   Checksum: {checksum}")

        return version_record
```

---

## Client-Side Specifications

### File Structure

```
Molten/Sources/
├── Models/Domain/
│   ├── CatalogUpdateModels.swift         # NEW: Models for update system
│   └── CatalogUpdatePreferences.swift    # NEW: User preferences
├── Services/
│   ├── Network/
│   │   └── CatalogAPIClient.swift        # NEW: API client
│   ├── Core/
│   │   ├── CatalogUpdateService.swift    # NEW: Update orchestration
│   │   └── CatalogStorageService.swift   # NEW: Local storage
│   └── Coordination/
│       └── NetworkMonitor.swift          # NEW: Network state monitoring
├── Views/Settings/
│   ├── SettingsView.swift                # MODIFY: Add catalog update section
│   ├── ViewModels/
│   │   └── CatalogUpdateViewModel.swift  # NEW: Settings view model
│   └── Components/
│       ├── CatalogInfoView.swift         # NEW: Catalog version info
│       └── CatalogUpdateView.swift       # NEW: Update download UI
└── Utilities/
    └── Extensions/
        └── Data+Gzip.swift                # NEW: Gzip decompression
```

### Implementation Order

**Phase 1: Foundation (Day 1-2)**
1. ✅ Create branch `ota-catalog`
2. ✅ Write implementation plan (this document)
3. `CatalogUpdateModels.swift` - Data models
4. `NetworkMonitor.swift` - Network state monitoring
5. `Data+Gzip.swift` - Gzip decompression utility
6. Tests for above

**Phase 2: API Client (Day 2-3)**
1. `CatalogAPIClient.swift` - Network requests
2. `CatalogUpdatePreferences.swift` - User settings
3. Tests for API client (using mocks)

**Phase 3: Storage & Service (Day 3-4)**
1. `CatalogStorageService.swift` - Local file management
2. `CatalogUpdateService.swift` - Update orchestration
3. Modify `GlassItemDataLoadingService` to support OTA
4. Tests for storage and service layers

**Phase 4: UI (Day 4-5)**
1. `CatalogUpdateViewModel.swift` - View model
2. `CatalogInfoView.swift` - Info display
3. `CatalogUpdateView.swift` - Update UI
4. Modify `SettingsView.swift` - Add catalog section
5. UI tests

**Phase 5: Integration (Day 5-6)**
1. Wire up services in `RepositoryFactory`
2. Add background update check to `MoltenApp`
3. Integration tests
4. Manual testing

**Phase 6: Server Deployment (Day 6-7)**
1. Deploy server API
2. Load initial catalog version
3. Test end-to-end
4. Documentation

---

### Models

**File:** `Molten/Sources/Models/Domain/CatalogUpdateModels.swift`

```swift
import Foundation

// MARK: - Catalog Version Metadata

/// Metadata about a catalog version from server
struct CatalogVersionMetadata: Codable, Equatable {
    let version: Int
    let itemCount: Int
    let releaseDate: Date
    let fileSize: Int64
    let checksum: String
    let minAppVersion: String
    let changelog: String

    enum CodingKeys: String, CodingKey {
        case version
        case itemCount = "item_count"
        case releaseDate = "release_date"
        case fileSize = "file_size"
        case checksum
        case minAppVersion = "min_app_version"
        case changelog
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    /// Check if this version is compatible with current app
    func isCompatibleWithApp(version: String) -> Bool {
        // Simple semantic version comparison
        return minAppVersion.compare(version, options: .numeric) != .orderedDescending
    }
}

// MARK: - Update Info

/// Information about an available catalog update
struct CatalogUpdateInfo: Equatable, Identifiable {
    let id = UUID()
    let currentVersion: Int
    let availableVersion: Int
    let itemsAdded: Int
    let releaseDate: Date
    let changelog: String
    let fileSize: Int64
    let checksum: String

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var isNewVersion: Bool {
        availableVersion > currentVersion
    }
}

// MARK: - Update Result

/// Result of applying a catalog update
struct CatalogUpdateResult: Equatable {
    let version: Int
    let itemsCreated: Int
    let itemsUpdated: Int
    let itemsRemoved: Int
    let appliedAt: Date

    var totalChanges: Int {
        itemsCreated + itemsUpdated + itemsRemoved
    }
}

// MARK: - Download Strategy

/// Strategy for downloading catalog updates
enum CatalogDownloadStrategy {
    case full(version: Int)
    case delta(from: Int, to: Int)  // v2.0 feature

    var downloadType: String {
        switch self {
        case .full: return "full"
        case .delta: return "delta"
        }
    }
}

// MARK: - Delta Update (v2.0)

/// Incremental catalog update (not implemented in v1.5)
struct CatalogDelta: Codable {
    let fromVersion: Int
    let toVersion: Int
    let generated: Date
    let added: [CatalogItemData]
    let updated: [CatalogItemUpdate]
    let removed: [String]  // stable_ids

    enum CodingKeys: String, CodingKey {
        case fromVersion = "from_version"
        case toVersion = "to_version"
        case generated
        case added
        case updated
        case removed
    }
}

struct CatalogItemUpdate: Codable {
    let stableId: String
    let changes: [String: AnyCodable]  // Field name -> new value

    enum CodingKeys: String, CodingKey {
        case stableId = "stable_id"
        case changes
    }
}

// Helper for dynamic JSON decoding
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Errors

enum CatalogUpdateError: LocalizedError {
    case networkPolicyRestricted
    case updateNotAvailable
    case downloadFailed(underlying: Error)
    case checksumMismatch
    case incompatibleVersion(required: String, current: String)
    case storageError(underlying: Error)
    case parseError(underlying: Error)
    case serverError(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .networkPolicyRestricted:
            return "Download restricted by network policy. Enable cellular downloads or connect to WiFi."
        case .updateNotAvailable:
            return "No catalog update is available."
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .checksumMismatch:
            return "Downloaded catalog is corrupted. Please try again."
        case .incompatibleVersion(let required, let current):
            return "This catalog requires app version \(required) or later. Current: \(current)"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .parseError(let error):
            return "Failed to parse catalog: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .invalidResponse:
            return "Invalid response from server."
        }
    }
}
```

---

### Preferences

**File:** `Molten/Sources/Models/Domain/CatalogUpdatePreferences.swift`

```swift
import Foundation
import Combine

/// User preferences for catalog updates
@MainActor
class CatalogUpdatePreferences: ObservableObject {

    static let shared = CatalogUpdatePreferences()

    private let defaults = UserDefaults.standard
    private let notificationCenter = NotificationCenter.default

    // MARK: - Settings

    enum DownloadPolicy: String, Codable, CaseIterable {
        case wifiOnly = "WiFi Only"
        case wifiAndCellular = "WiFi & Cellular"
        case manual = "Manual Only"

        func allowsDownload(isOnWiFi: Bool) -> Bool {
            switch self {
            case .wifiOnly:
                return isOnWiFi
            case .wifiAndCellular:
                return true
            case .manual:
                return false
            }
        }

        var description: String {
            switch self {
            case .wifiOnly:
                return "Download updates only when connected to WiFi"
            case .wifiAndCellular:
                return "Download updates on WiFi or cellular"
            case .manual:
                return "Never download automatically"
            }
        }
    }

    enum UpdateFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var checkInterval: TimeInterval {
            switch self {
            case .daily:
                return 86400  // 24 hours
            case .weekly:
                return 604800  // 7 days
            case .monthly:
                return 2592000  // 30 days
            }
        }
    }

    // MARK: - Published Properties

    @Published var autoUpdateEnabled: Bool {
        didSet {
            defaults.set(autoUpdateEnabled, forKey: Keys.autoUpdate)
            notificationCenter.post(name: .catalogPreferencesChanged, object: nil)
        }
    }

    @Published var downloadPolicy: DownloadPolicy {
        didSet {
            defaults.set(downloadPolicy.rawValue, forKey: Keys.downloadPolicy)
            notificationCenter.post(name: .catalogPreferencesChanged, object: nil)
        }
    }

    @Published var updateFrequency: UpdateFrequency {
        didSet {
            defaults.set(updateFrequency.rawValue, forKey: Keys.updateFrequency)
            notificationCenter.post(name: .catalogPreferencesChanged, object: nil)
        }
    }

    // MARK: - Non-Published Properties

    var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Keys.lastUpdateCheck) as? Date }
        set {
            defaults.set(newValue, forKey: Keys.lastUpdateCheck)
            objectWillChange.send()
        }
    }

    var currentCatalogVersion: Int {
        get { defaults.integer(forKey: Keys.currentVersion) }
        set {
            defaults.set(newValue, forKey: Keys.currentVersion)
            objectWillChange.send()
        }
    }

    var lastSuccessfulUpdate: Date? {
        get { defaults.object(forKey: Keys.lastSuccessfulUpdate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastSuccessfulUpdate) }
    }

    var catalogSource: CatalogSource {
        get {
            guard let rawValue = defaults.string(forKey: Keys.catalogSource),
                  let source = CatalogSource(rawValue: rawValue) else {
                return .bundled
            }
            return source
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.catalogSource)
        }
    }

    enum CatalogSource: String {
        case bundled = "Bundled"
        case downloaded = "Downloaded"
        case unknown = "Unknown"
    }

    // MARK: - Keys

    private enum Keys {
        static let autoUpdate = "catalog.autoUpdate"
        static let downloadPolicy = "catalog.downloadPolicy"
        static let updateFrequency = "catalog.updateFrequency"
        static let lastUpdateCheck = "catalog.lastUpdateCheck"
        static let currentVersion = "catalog.currentVersion"
        static let lastSuccessfulUpdate = "catalog.lastSuccessfulUpdate"
        static let catalogSource = "catalog.source"
    }

    // MARK: - Initialization

    private init() {
        // Load settings with defaults
        self.autoUpdateEnabled = defaults.bool(forKey: Keys.autoUpdate)

        if let policyRaw = defaults.string(forKey: Keys.downloadPolicy),
           let policy = DownloadPolicy(rawValue: policyRaw) {
            self.downloadPolicy = policy
        } else {
            self.downloadPolicy = .wifiOnly  // Default
        }

        if let frequencyRaw = defaults.string(forKey: Keys.updateFrequency),
           let frequency = UpdateFrequency(rawValue: frequencyRaw) {
            self.updateFrequency = frequency
        } else {
            self.updateFrequency = .weekly  // Default
        }
    }

    // MARK: - Helpers

    /// Check if enough time has passed for next update check
    func shouldCheckForUpdates() -> Bool {
        guard let lastCheck = lastUpdateCheck else {
            return true  // Never checked
        }

        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck >= updateFrequency.checkInterval
    }

    /// Reset all preferences to defaults
    func resetToDefaults() {
        autoUpdateEnabled = false
        downloadPolicy = .wifiOnly
        updateFrequency = .weekly
        lastUpdateCheck = nil
        lastSuccessfulUpdate = nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let catalogPreferencesChanged = Notification.Name("catalogPreferencesChanged")
    static let catalogUpdateAvailable = Notification.Name("catalogUpdateAvailable")
    static let catalogUpdateCompleted = Notification.Name("catalogUpdateCompleted")
    static let catalogUpdateFailed = Notification.Name("catalogUpdateFailed")
}
```

---

### Network Monitor

**File:** `Molten/Sources/Services/Coordination/NetworkMonitor.swift`

```swift
import Foundation
import Network
import Combine

/// Monitors network connectivity and type
@MainActor
class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    // MARK: - Properties

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.molten.networkmonitor")

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isOnWiFi: Bool = false
    @Published private(set) var connectionType: NWInterface.InterfaceType?
    @Published private(set) var isExpensive: Bool = false
    @Published private(set) var isConstrained: Bool = false

    // MARK: - Initialization

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionState(path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Private Methods

    private func updateConnectionState(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isOnWiFi = path.usesInterfaceType(.wifi)
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = nil
        }
    }

    // MARK: - Public API

    /// Check if catalog download is allowed based on current network and user preferences
    func canDownloadCatalog() -> Bool {
        guard isConnected else {
            return false
        }

        let policy = CatalogUpdatePreferences.shared.downloadPolicy
        return policy.allowsDownload(isOnWiFi: isOnWiFi)
    }

    /// Get human-readable connection description
    var connectionDescription: String {
        guard isConnected else {
            return "No connection"
        }

        switch connectionType {
        case .wifi:
            return "WiFi"
        case .cellular:
            if isExpensive {
                return "Cellular (expensive)"
            }
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        default:
            return "Connected"
        }
    }
}
```

---

### Gzip Decompression

**File:** `Molten/Sources/Utilities/Extensions/Data+Gzip.swift`

```swift
import Foundation
import Compression

extension Data {

    /// Decompress gzipped data
    func gunzipped() throws -> Data {
        guard !self.isEmpty else {
            return self
        }

        var decompressed = Data()
        var index = 0

        let bufferSize = 512
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        try self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
            guard let inputBaseAddress = inputPointer.baseAddress else {
                throw CompressionError.invalidInput
            }

            let stream = compression_stream_init(
                COMPRESSION_STREAM_DECODE,
                COMPRESSION_ZLIB
            )

            guard let streamPointer = stream else {
                throw CompressionError.streamInitializationFailed
            }

            defer {
                compression_stream_destroy(streamPointer)
            }

            streamPointer.pointee.src_ptr = inputBaseAddress.assumingMemoryBound(to: UInt8.self)
            streamPointer.pointee.src_size = self.count
            streamPointer.pointee.dst_ptr = buffer
            streamPointer.pointee.dst_size = bufferSize

            while true {
                let status = compression_stream_process(streamPointer, 0)

                switch status {
                case COMPRESSION_STATUS_OK:
                    // More data to decompress
                    let count = bufferSize - streamPointer.pointee.dst_size
                    decompressed.append(buffer, count: count)

                    streamPointer.pointee.dst_ptr = buffer
                    streamPointer.pointee.dst_size = bufferSize

                case COMPRESSION_STATUS_END:
                    // Decompression complete
                    let count = bufferSize - streamPointer.pointee.dst_size
                    decompressed.append(buffer, count: count)
                    return

                case COMPRESSION_STATUS_ERROR:
                    throw CompressionError.decompressionFailed

                default:
                    throw CompressionError.unknownError
                }
            }
        }

        return decompressed
    }

    /// Check if data is gzipped (starts with gzip magic number)
    var isGzipped: Bool {
        self.count >= 2 && self[0] == 0x1f && self[1] == 0x8b
    }
}

enum CompressionError: LocalizedError {
    case invalidInput
    case streamInitializationFailed
    case decompressionFailed
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid input data for decompression"
        case .streamInitializationFailed:
            return "Failed to initialize compression stream"
        case .decompressionFailed:
            return "Decompression failed"
        case .unknownError:
            return "Unknown compression error"
        }
    }
}
```

---

### API Client

**File:** `Molten/Sources/Services/Network/CatalogAPIClient.swift`

```swift
import Foundation
import OSLog

/// API client for catalog update operations
@MainActor
class CatalogAPIClient {

    // MARK: - Properties

    private let session: URLSessionProtocol
    private let baseURL: URL
    private let attestationManager: AttestationManager
    private let pinnedCertificates: [Data]
    private let log = Logger(subsystem: "Molten", category: "CatalogAPI")

    // MARK: - Initialization

    init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = URL(string: "https://api.yourdomain.com")!,
        attestationManager: AttestationManager = AttestationManager(),
        pinnedCertificates: [Data] = []
    ) {
        self.session = session
        self.baseURL = baseURL
        self.attestationManager = attestationManager
        self.pinnedCertificates = pinnedCertificates
    }

    // MARK: - Version API

    /// Get latest catalog version metadata
    func getLatestVersion() async throws -> CatalogVersionMetadata {
        let url = baseURL.appendingPathComponent("catalog/version")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Optional: Add App Attest assertion
        // (server may not require it for version checks)
        do {
            try await addAttestation(to: &request)
        } catch {
            log.warning("Failed to add App Attest assertion: \(error.localizedDescription)")
            // Continue without attestation - server may allow it
        }

        let (data, response) = try await executeRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogUpdateError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CatalogVersionMetadata.self, from: data)

        case 401, 403:
            throw CatalogUpdateError.serverError(statusCode: httpResponse.statusCode)

        case 429:
            log.warning("Rate limit exceeded for version check")
            throw CatalogUpdateError.serverError(statusCode: 429)

        default:
            throw CatalogUpdateError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Data Download

    /// Download full catalog JSON
    /// - Parameters:
    ///   - version: Specific version to download (nil = latest)
    ///   - progressHandler: Optional closure for progress updates (0.0 to 1.0)
    /// - Returns: Decompressed catalog JSON data
    func downloadFullCatalog(
        version: Int? = nil,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Data {

        var urlComponents = URLComponents(
            url: baseURL.appendingPathComponent("catalog/data"),
            resolvingAgainstBaseURL: true
        )!

        if let version = version {
            urlComponents.queryItems = [
                URLQueryItem(name: "version", value: "\(version)")
            ]
        }

        guard let url = urlComponents.url else {
            throw CatalogUpdateError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        // REQUIRED: Add App Attest assertion for data downloads
        try await addAttestation(to: &request)

        log.info("Downloading catalog (version: \(version?.description ?? "latest"))")

        // Use download task for progress tracking and large files
        let delegate = DownloadProgressDelegate(progressHandler: progressHandler)
        let (localURL, response) = try await session.download(for: request, delegate: delegate)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogUpdateError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            // Read downloaded file
            var data = try Data(contentsOf: localURL)

            // Decompress if gzipped
            if let contentEncoding = httpResponse.value(forHTTPHeaderField: "Content-Encoding"),
               contentEncoding.lowercased() == "gzip" {
                log.debug("Decompressing gzipped catalog data")
                data = try data.gunzipped()
            } else if data.isGzipped {
                log.debug("Detected gzipped data, decompressing")
                data = try data.gunzipped()
            }

            log.info("Downloaded catalog: \(data.count) bytes (decompressed)")

            // Cleanup temp file
            try? FileManager.default.removeItem(at: localURL)

            return data

        case 304:
            log.info("Catalog not modified (304)")
            throw CatalogUpdateError.updateNotAvailable

        case 401, 403:
            log.error("Authentication failed (\(httpResponse.statusCode))")
            throw CatalogUpdateError.serverError(statusCode: httpResponse.statusCode)

        case 404:
            log.error("Catalog version not found")
            throw CatalogUpdateError.updateNotAvailable

        case 429:
            log.warning("Rate limit exceeded")
            throw CatalogUpdateError.serverError(statusCode: 429)

        default:
            log.error("Server error: \(httpResponse.statusCode)")
            throw CatalogUpdateError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    /// Download delta catalog update (v2.0 feature - not implemented in v1.5)
    func downloadDeltaCatalog(from: Int, to: Int) async throws -> CatalogDelta {
        throw CatalogUpdateError.updateNotAvailable  // Not implemented yet
    }

    // MARK: - Private Helpers

    /// Add App Attest assertion to request
    private func addAttestation(to request: inout URLRequest) async throws {
        // Generate assertion for this request
        let assertion = try await attestationManager.generateAssertion(for: request)

        // Add as header
        request.setValue(assertion, forHTTPHeaderField: "X-Apple-Assertion")
    }

    /// Execute request and validate response
    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            return (data, response)
        } catch {
            log.error("Network request failed: \(error.localizedDescription)")
            throw CatalogUpdateError.downloadFailed(underlying: error)
        }
    }
}

// MARK: - Download Progress Delegate

private class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {

    let progressHandler: ((Double) -> Void)?

    init(progressHandler: ((Double) -> Void)?) {
        self.progressHandler = progressHandler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task { @MainActor in
            progressHandler?(progress)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Download completed - handled by async/await return value
    }
}
```

---

### Storage Service

**File:** `Molten/Sources/Services/Core/CatalogStorageService.swift`

```swift
import Foundation
import OSLog

/// Manages local storage of catalog data
actor CatalogStorageService {

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let log = Logger(subsystem: "Molten", category: "CatalogStorage")

    // Storage paths
    private let storageDirectory: URL
    private let tempDirectory: URL
    private let currentCatalogFile: URL

    // MARK: - Initialization

    init() throws {
        // Get app support directory
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CatalogUpdateError.storageError(
                underlying: NSError(domain: "CatalogStorage", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Cannot access Application Support directory"])
            )
        }

        // Setup directories
        storageDirectory = appSupport.appendingPathComponent("CatalogData", isDirectory: true)
        tempDirectory = storageDirectory.appendingPathComponent("Temp", isDirectory: true)
        currentCatalogFile = storageDirectory.appendingPathComponent("current_catalog.json")

        // Create directories if needed
        try createDirectoriesIfNeeded()

        log.info("Catalog storage initialized at: \(self.storageDirectory.path)")
    }

    // MARK: - Public API

    /// Save catalog data to temporary storage
    /// - Parameters:
    ///   - data: Catalog JSON data
    ///   - version: Catalog version number
    /// - Returns: URL of saved temp file
    func saveTempCatalog(_ data: Data, version: Int) throws -> URL {
        let tempFile = tempDirectory.appendingPathComponent("catalog_v\(version)_temp.json")

        log.debug("Saving temp catalog to: \(tempFile.path)")

        do {
            try data.write(to: tempFile, options: .atomic)
            log.info("Saved temp catalog (\(data.count) bytes)")
            return tempFile
        } catch {
            log.error("Failed to save temp catalog: \(error.localizedDescription)")
            throw CatalogUpdateError.storageError(underlying: error)
        }
    }

    /// Promote temp catalog to current catalog (atomic swap)
    /// - Parameter tempFile: URL of temp catalog file
    func promoteTempToCurrent(tempFile: URL) throws {
        log.debug("Promoting temp catalog to current")

        do {
            // Remove old current catalog if exists
            if fileManager.fileExists(atPath: currentCatalogFile.path) {
                try fileManager.removeItem(at: currentCatalogFile)
            }

            // Move temp to current (atomic operation)
            try fileManager.moveItem(at: tempFile, to: currentCatalogFile)

            log.info("✅ Promoted temp catalog to current")
        } catch {
            log.error("Failed to promote temp catalog: \(error.localizedDescription)")
            throw CatalogUpdateError.storageError(underlying: error)
        }
    }

    /// Load current catalog from storage
    /// - Returns: Catalog JSON data, or nil if no catalog exists
    func loadCurrentCatalog() -> Data? {
        guard fileManager.fileExists(atPath: currentCatalogFile.path) else {
            log.debug("No current catalog file exists")
            return nil
        }

        do {
            let data = try Data(contentsOf: currentCatalogFile)
            log.debug("Loaded current catalog (\(data.count) bytes)")
            return data
        } catch {
            log.error("Failed to load current catalog: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clean up old temp files
    func cleanupTempFiles() {
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory,
                                                               includingPropertiesForKeys: [.creationDateKey],
                                                               options: .skipsHiddenFiles)

            // Delete temp files older than 24 hours
            let cutoffDate = Date().addingTimeInterval(-86400)

            for fileURL in tempFiles {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {

                    try? fileManager.removeItem(at: fileURL)
                    log.debug("Deleted old temp file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            log.warning("Failed to cleanup temp files: \(error.localizedDescription)")
        }
    }

    /// Get size of stored catalog data
    func getStorageSize() -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: storageDirectory,
                                                   includingPropertiesForKeys: [.fileSizeKey],
                                                   options: .skipsHiddenFiles) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
            }
        }

        return totalSize
    }

    // MARK: - Private Helpers

    private func createDirectoriesIfNeeded() throws {
        for directory in [storageDirectory, tempDirectory] {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory,
                                              withIntermediateDirectories: true,
                                              attributes: nil)
                log.debug("Created directory: \(directory.path)")
            }
        }
    }
}
```

---

### Update Service

**File:** `Molten/Sources/Services/Core/CatalogUpdateService.swift`

```swift
import Foundation
import OSLog

/// Service for managing catalog updates
@MainActor
class CatalogUpdateService: ObservableObject {

    // MARK: - Properties

    private let apiClient: CatalogAPIClient
    private let storageService: CatalogStorageService
    private let dataLoadingService: GlassItemDataLoadingService
    private let networkMonitor: NetworkMonitor
    private let log = Logger(subsystem: "Molten", category: "CatalogUpdate")

    @Published private(set) var isChecking: Bool = false
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var downloadProgress: Double = 0.0

    // MARK: - Initialization

    init(
        apiClient: CatalogAPIClient = CatalogAPIClient(),
        storageService: CatalogStorageService,
        dataLoadingService: GlassItemDataLoadingService,
        networkMonitor: NetworkMonitor = .shared
    ) {
        self.apiClient = apiClient
        self.storageService = storageService
        self.dataLoadingService = dataLoadingService
        self.networkMonitor = networkMonitor
    }

    // MARK: - Public API

    /// Check if catalog update is available
    /// - Returns: Update info if available, nil if current
    func checkForUpdates() async throws -> CatalogUpdateInfo? {
        guard !isChecking else {
            log.warning("Update check already in progress")
            return nil
        }

        isChecking = true
        defer { isChecking = false }

        log.info("Checking for catalog updates...")

        do {
            // Get latest version from server
            let latestMetadata = try await apiClient.getLatestVersion()

            // Update last check time
            CatalogUpdatePreferences.shared.lastUpdateCheck = Date()

            // Get current version
            let currentVersion = CatalogUpdatePreferences.shared.currentCatalogVersion

            log.info("Current: v\(currentVersion), Latest: v\(latestMetadata.version)")

            // Check if update available
            guard latestMetadata.version > currentVersion else {
                log.info("✅ Catalog is up to date")
                return nil
            }

            // Check app version compatibility
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            guard latestMetadata.isCompatibleWithApp(version: appVersion) else {
                log.warning("Catalog v\(latestMetadata.version) requires app version \(latestMetadata.minAppVersion)")
                throw CatalogUpdateError.incompatibleVersion(
                    required: latestMetadata.minAppVersion,
                    current: appVersion
                )
            }

            // Build update info
            let updateInfo = CatalogUpdateInfo(
                currentVersion: currentVersion,
                availableVersion: latestMetadata.version,
                itemsAdded: latestMetadata.itemCount - getCurrentItemCount(),
                releaseDate: latestMetadata.releaseDate,
                changelog: latestMetadata.changelog,
                fileSize: latestMetadata.fileSize,
                checksum: latestMetadata.checksum
            )

            log.info("📦 Update available: v\(currentVersion) → v\(updateInfo.availableVersion)")

            // Post notification
            NotificationCenter.default.post(
                name: .catalogUpdateAvailable,
                object: updateInfo
            )

            return updateInfo

        } catch {
            log.error("Failed to check for updates: \(error.localizedDescription)")
            throw error
        }
    }

    /// Download and install catalog update
    /// - Parameters:
    ///   - updateInfo: Update information
    ///   - force: Force download even if network policy restricts it
    /// - Returns: Update result
    func downloadAndInstallUpdate(
        updateInfo: CatalogUpdateInfo,
        force: Bool = false
    ) async throws -> CatalogUpdateResult {

        guard !isDownloading else {
            log.warning("Download already in progress")
            throw CatalogUpdateError.downloadFailed(
                underlying: NSError(domain: "CatalogUpdate", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Download already in progress"])
            )
        }

        isDownloading = true
        downloadProgress = 0.0

        defer {
            isDownloading = false
            downloadProgress = 0.0
        }

        do {
            // 1. Check network policy
            if !force {
                guard networkMonitor.canDownloadCatalog() else {
                    log.warning("Download blocked by network policy")
                    throw CatalogUpdateError.networkPolicyRestricted
                }
            }

            log.info("Starting catalog download: v\(updateInfo.availableVersion)")

            // 2. Download catalog
            let catalogData = try await apiClient.downloadFullCatalog(
                version: updateInfo.availableVersion
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress * 0.5  // First 50% is download
                }
            }

            downloadProgress = 0.5

            // 3. Verify checksum
            let actualChecksum = "sha256:" + catalogData.sha256Hash()
            guard actualChecksum == updateInfo.checksum else {
                log.error("Checksum mismatch: expected \(updateInfo.checksum), got \(actualChecksum)")
                throw CatalogUpdateError.checksumMismatch
            }

            log.info("✅ Checksum verified")
            downloadProgress = 0.6

            // 4. Save to temp storage
            let tempFile = try await storageService.saveTempCatalog(
                catalogData,
                version: updateInfo.availableVersion
            )

            downloadProgress = 0.7

            // 5. Parse and load into database
            log.info("Loading catalog into database...")

            let loadingResult = try await dataLoadingService.loadGlassItemsFromData(
                catalogData,
                options: .appUpdate
            )

            downloadProgress = 0.9

            // 6. Promote temp to current
            try await storageService.promoteTempToCurrent(tempFile: tempFile)

            // 7. Update version tracking
            CatalogUpdatePreferences.shared.currentCatalogVersion = updateInfo.availableVersion
            CatalogUpdatePreferences.shared.lastSuccessfulUpdate = Date()
            CatalogUpdatePreferences.shared.catalogSource = .downloaded

            downloadProgress = 1.0

            let result = CatalogUpdateResult(
                version: updateInfo.availableVersion,
                itemsCreated: loadingResult.itemsCreated,
                itemsUpdated: loadingResult.itemsUpdated,
                itemsRemoved: 0,  // Not tracking removals in v1.5
                appliedAt: Date()
            )

            log.info("✅ Catalog updated successfully to v\(updateInfo.availableVersion)")
            log.info("   Created: \(result.itemsCreated), Updated: \(result.itemsUpdated)")

            // Post notification
            NotificationCenter.default.post(
                name: .catalogUpdateCompleted,
                object: result
            )

            return result

        } catch {
            log.error("Failed to download/install update: \(error.localizedDescription)")

            // Post failure notification
            NotificationCenter.default.post(
                name: .catalogUpdateFailed,
                object: error
            )

            throw error
        }
    }

    /// Perform background update check (called by app lifecycle)
    func performBackgroundUpdateCheck() async {
        guard CatalogUpdatePreferences.shared.autoUpdateEnabled else {
            log.debug("Auto-update disabled, skipping background check")
            return
        }

        guard CatalogUpdatePreferences.shared.shouldCheckForUpdates() else {
            log.debug("Not yet time for background update check")
            return
        }

        do {
            if let updateInfo = try await checkForUpdates() {
                log.info("Background check found update: v\(updateInfo.availableVersion)")

                // If auto-update enabled and on WiFi, download automatically
                if CatalogUpdatePreferences.shared.downloadPolicy == .wifiAndCellular ||
                   (CatalogUpdatePreferences.shared.downloadPolicy == .wifiOnly && networkMonitor.isOnWiFi) {

                    log.info("Auto-downloading update in background")
                    _ = try await downloadAndInstallUpdate(updateInfo: updateInfo)
                }
            }
        } catch {
            // Silent failure for background checks
            log.debug("Background update check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func getCurrentItemCount() -> Int {
        // This would query the database for current item count
        // For now, return stored count or 0
        return 0  // TODO: Implement
    }
}

// MARK: - Data Extensions

extension Data {
    func sha256Hash() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// Import CommonCrypto
import CommonCrypto
```

**Note:** This file depends on modifications to `GlassItemDataLoadingService` to add a `loadGlassItemsFromData(_:options:)` method that accepts raw Data instead of loading from bundle.

---

## Implementation Phases

### Phase 1: Foundation ✅ (Day 1-2)

**Goals:**
- Set up project structure
- Implement basic models and utilities
- No server dependencies yet

**Tasks:**
1. ✅ Create `ota-catalog` branch
2. ✅ Write `OTA-Catalog-Implementation-Plan.md`
3. Create `CatalogUpdateModels.swift`
   - All model structs
   - Error types
   - Codable conformance
4. Create `CatalogUpdatePreferences.swift`
   - UserDefaults integration
   - Published properties
   - Notification posting
5. Create `NetworkMonitor.swift`
   - Network.framework integration
   - Connection type detection
   - Policy checking
6. Create `Data+Gzip.swift`
   - Gzip decompression
   - Error handling
7. Write tests:
   - `CatalogUpdateModelsTests.swift`
   - `CatalogUpdatePreferencesTests.swift`
   - `NetworkMonitorTests.swift`
   - `DataGzipTests.swift`

**Success Criteria:**
- All models compile
- Preferences persist correctly
- Network monitor detects WiFi/cellular
- Gzip decompression works

---

### Phase 2: API Client (Day 2-3)

**Goals:**
- Implement network layer
- Integrate with existing App Attest infrastructure
- Mock server responses for testing

**Tasks:**
1. Create `CatalogAPIClient.swift`
   - Version endpoint
   - Data endpoint
   - Progress tracking
   - App Attest integration
2. Create `MockCatalogAPIClient.swift` for testing
3. Write tests:
   - `CatalogAPIClientTests.swift`
   - Test version checking
   - Test data download
   - Test error handling
   - Test progress reporting
   - Test rate limiting responses

**Success Criteria:**
- Can fetch version metadata (mocked)
- Can download catalog data (mocked)
- Progress callbacks work
- Errors are properly typed

---

### Phase 3: Storage & Service (Day 3-4)

**Goals:**
- Implement local storage
- Orchestrate update flow
- Integrate with existing GlassItemDataLoadingService

**Tasks:**
1. Create `CatalogStorageService.swift`
   - Temp file management
   - Atomic swap
   - Cleanup
2. Create `CatalogUpdateService.swift`
   - Update checking
   - Download orchestration
   - Database integration
3. Modify `GlassItemDataLoadingService.swift`
   - Add `loadGlassItemsFromData(_:options:)` method
   - Support loading from Data (not just bundle)
4. Write tests:
   - `CatalogStorageServiceTests.swift`
   - `CatalogUpdateServiceTests.swift`
   - Test full update flow with mocks

**Success Criteria:**
- Can save/load catalog from temp storage
- Atomic swap works correctly
- Full update flow works end-to-end (with mocks)
- Database updates correctly

---

### Phase 4: UI (Day 4-5)

**Goals:**
- User-facing update controls
- Settings integration
- Visual feedback

**Tasks:**
1. Create `CatalogUpdateViewModel.swift`
   - Observable state
   - Action handlers
   - Error handling
2. Create `CatalogInfoView.swift`
   - Version display
   - Update status
   - Download button
3. Create `CatalogUpdateView.swift`
   - Progress indicator
   - Error messages
   - Network policy warnings
4. Modify `SettingsView.swift`
   - Add Catalog Updates section
   - Preference controls
   - Navigation to info view
5. Write tests:
   - `CatalogUpdateViewModelTests.swift`
   - UI tests for settings flow
   - UI tests for update flow

**Success Criteria:**
- User can see current version
- User can check for updates
- User can download updates
- Progress is shown
- Errors are displayed

---

### Phase 5: Integration (Day 5-6)

**Goals:**
- Wire everything together
- Background update checking
- App lifecycle integration

**Tasks:**
1. Update `RepositoryFactory.swift`
   - Create `CatalogUpdateService` instance
   - Inject dependencies
2. Update `MoltenApp.swift`
   - Background update checking
   - App lifecycle hooks
   - Initial catalog loading
3. Integration tests:
   - Full update flow with real Core Data
   - Background update checking
   - First-run experience
4. Manual testing:
   - Fresh install → load bundled catalog
   - Check for updates → see update available
   - Download update → catalog updates
   - Offline mode → use cached catalog
   - Cellular mode → respect WiFi-only setting

**Success Criteria:**
- App launches with bundled catalog
- Background checks work
- Updates apply correctly
- All user flows work

---

### Phase 6: Server Deployment (Day 6-7)

**Goals:**
- Deploy production server
- Load initial catalog data
- Verify end-to-end

**Tasks:**
1. Server setup:
   - Deploy Flask application
   - Configure PostgreSQL database
   - Set up Redis for rate limiting
   - Configure HTTPS + certificate pinning
2. Data migration:
   - Upload `glassitems.json` as version 1
   - Compute checksums
   - Create database records
3. Testing:
   - Test all API endpoints with curl
   - Verify rate limiting
   - Verify App Attest
   - Load test with 100 concurrent requests
4. Documentation:
   - Server deployment guide
   - Catalog release process
   - Monitoring setup

**Success Criteria:**
- All endpoints return correct data
- Rate limiting works
- App Attest verification works
- End-to-end update works
- Monitoring dashboards show metrics

---

## Testing Strategy

### Unit Tests (70% coverage target)

**Models & Preferences:**
- `CatalogUpdateModelsTests` - Model encoding/decoding
- `CatalogUpdatePreferencesTests` - Settings persistence
- `DataGzipTests` - Compression utilities

**Services:**
- `CatalogAPIClientTests` - API calls (mocked)
- `CatalogStorageServiceTests` - File operations
- `CatalogUpdateServiceTests` - Update orchestration
- `NetworkMonitorTests` - Network detection

**ViewModels:**
- `CatalogUpdateViewModelTests` - UI state management

### Integration Tests (20% coverage target)

**Repository Tests:**
- `CatalogUpdateIntegrationTests` - Full update flow with Core Data
- `CatalogStorageIntegrationTests` - Real file system operations

**Server Tests:**
- `CatalogAPIServerTests` - Test real server endpoints (staging)

### UI Tests (10% coverage target)

**Critical Flows:**
- `CatalogUpdateUITests` - Manual update flow
- `CatalogSettingsUITests` - Preference changes
- `CatalogInfoUITests` - Version display

### Manual Testing Checklist

**First Run:**
- [ ] Fresh install loads bundled catalog
- [ ] Background check finds update
- [ ] Update notification appears

**Update Flow:**
- [ ] Check for updates shows available update
- [ ] WiFi-only policy blocks cellular download
- [ ] Download shows progress
- [ ] Update applies successfully
- [ ] Catalog version increments

**Error Handling:**
- [ ] No network → graceful error
- [ ] Server down → retry option
- [ ] Checksum mismatch → error message
- [ ] Incompatible version → clear message

**Edge Cases:**
- [ ] App kill during download → resume works
- [ ] Multiple devices → all update correctly
- [ ] Old app version → compatibility check works

---

## Rollout Plan

### Beta Testing (Week 1-2)

**Target:** 10-20 beta testers

**Goals:**
- Verify update mechanism works
- Collect feedback on UI/UX
- Monitor server load
- Fix critical bugs

**Success Metrics:**
- 90%+ successful updates
- <5 second average download time
- No crashes related to updates
- Positive user feedback

### Staged Rollout (Week 3-4)

**Stage 1 (Week 3):** 25% of users
- Monitor error rates
- Check server capacity
- Gather analytics

**Stage 2 (Week 4):** 100% of users
- Full deployment
- Continued monitoring

### Post-Launch Monitoring

**Week 1-2:**
- Daily review of server logs
- Monitor error rates
- Track download success rate
- User support tickets

**Week 3-4:**
- Weekly monitoring
- Plan for v2.0 features (delta updates)

---

## Risks & Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| **Server downtime during first-run** | Users can't use app | Medium | Keep bundled fallback in v1.5 |
| **Catalog corruption during download** | App crashes/data loss | Low | Checksum verification + atomic swap |
| **User on cellular with large update** | Data charges | Medium | Default WiFi-only, warn before cellular |
| **Scrapers abuse API** | High bandwidth costs | Medium | App Attest + aggressive rate limiting |
| **Breaking schema change** | Old apps crash | Low | Version `min_app_version` check |
| **CloudKit conflicts during update** | Inventory data loss | Low | Updates only touch Local Store (GlassItem) |
| **App Store rejection** | Can't ship | Very Low | JSON data is not code, within guidelines |
| **High server costs** | Budget overrun | Low | Monitor usage, implement caching |

---

## Success Criteria

**Technical:**
- ✅ 95%+ update success rate
- ✅ <30 second average update time (WiFi)
- ✅ Zero data corruption incidents
- ✅ <$50/month server costs
- ✅ App bundle size <20 MB

**User Experience:**
- ✅ Users can see current catalog version
- ✅ Users can manually trigger updates
- ✅ Users receive update notifications
- ✅ Clear progress indication during downloads
- ✅ Graceful error messages

**Business:**
- ✅ Catalog updates ship weekly (not quarterly)
- ✅ No App Store review delays for catalog changes
- ✅ Reduced app bundle size (future v2.0)

---

## Next Steps After v1.5

**v2.0 Features:**
- Delta/incremental updates (smaller downloads)
- Remove bundled catalog (mandatory OTA)
- CDN for catalog delivery (faster, cheaper)
- Analytics dashboard for catalog usage

**v2.5 Features:**
- Per-manufacturer catalog segments
- A/B testing for catalog layouts
- Offline catalog caching improvements
- Background download during idle time

---

## Appendix

### API Endpoint Summary

```
GET  /catalog/version          - Get latest version metadata
GET  /catalog/data             - Download full catalog
GET  /catalog/delta            - Download incremental update (v2.0)
POST /attest/register          - Register App Attest key
```

### Database Tables Summary

```
catalog_versions       - Version metadata
catalog_downloads      - Download logs
app_attest_keys        - App Attest keys
rate_limits            - Rate limiting state
catalog_anomalies      - Abuse detection
```

### File Locations

**Client:**
```
~/Library/Application Support/CatalogData/
├── current_catalog.json       - Active catalog
└── Temp/                      - Download staging
    └── catalog_v2_temp.json
```

**Server:**
```
/var/catalog_data/
├── versions/
│   ├── v1.json.gz
│   └── v2.json.gz
└── deltas/
    └── v1_to_v2.json.gz
```

---

## Addendum: Image Download Strategy

### Revised Architecture (Based on User Requirements)

**What ships in the app bundle (v1.5):**
- ✅ Full catalog JSON metadata (~3.1 MB)
- ✅ App UI assets only
- ❌ Product images (CDN URLs only)

**What happens on app startup:**
```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions...) {
    // 1. Load bundled catalog into Core Data (if empty)
    await loadBundledCatalogIfNeeded()

    // 2. Background: Check for catalog updates
    Task.detached {
        await catalogUpdateService.performBackgroundUpdateCheck()
    }

    // 3. Background: Download missing images (based on user preferences)
    Task.detached {
        await imageDownloadService.downloadMissingImages()
    }
}
```

**Image Download Modes (User Preference):**

1. **On-Demand Only** (Default)
   - No pre-downloading
   - Fetch images as user scrolls/views
   - Cache after first load
   - Smallest storage footprint

2. **Thumbnails Only**
   - Pre-download small thumbnails (~50 KB each × 3,198 = ~160 MB)
   - Fast offline browsing
   - Full-res on-demand when viewing detail
   - Medium storage footprint

3. **All Images**
   - Pre-download thumbnails + full-res (~200 KB each × 3,198 = ~640 MB)
   - Full offline experience
   - Largest storage footprint

**User Preference Controls:**

```swift
// In SettingsView - new section
Section {
    Picker("Image Download Mode", selection: $imageDownloadMode) {
        Text("On-Demand Only").tag(ImageDownloadMode.onDemand)
        Text("Thumbnails Only").tag(ImageDownloadMode.thumbnails)
        Text("All Images").tag(ImageDownloadMode.allImages)
    }

    Toggle("Download Over Cellular", isOn: $allowCellularImageDownload)

    Picker("Download Timing", selection: $downloadTiming) {
        Text("Immediately").tag(DownloadTiming.immediate)
        Text("When Idle").tag(DownloadTiming.idle)
        Text("Manually").tag(DownloadTiming.manual)
    }

    // Storage info
    HStack {
        Text("Images Cached")
        Spacer()
        Text("\(cachedImageCount) / \(totalImageCount)")
            .foregroundColor(.secondary)
    }

    HStack {
        Text("Storage Used")
        Spacer()
        Text(storageUsedFormatted)
            .foregroundColor(.secondary)
    }

    Button("Clear Image Cache") {
        viewModel.clearImageCache()
    }
    .foregroundColor(.red)

} header: {
    Text("Product Images")
} footer: {
    Text(imageDownloadMode.footerText)
}
```

**Footer Text Examples:**
- On-Demand: "Images load as you browse. Requires internet connection."
- Thumbnails: "Small preview images for offline browsing. ~160 MB total."
- All Images: "Full-resolution images for offline use. ~640 MB total."

### New Service: ImageDownloadService

**File:** `Molten/Sources/Services/Core/ImageDownloadService.swift`

```swift
import Foundation
import UIKit
import OSLog

/// Service for downloading and caching product images
@MainActor
class ImageDownloadService: ObservableObject {

    // MARK: - Properties

    private let catalogService: CatalogService
    private let storageService: ImageStorageService
    private let networkMonitor: NetworkMonitor
    private let log = Logger(subsystem: "Molten", category: "ImageDownload")

    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var downloadProgress: Double = 0.0
    @Published private(set) var cachedImageCount: Int = 0

    // MARK: - User Preferences

    enum ImageDownloadMode: String, Codable, CaseIterable {
        case onDemand = "On-Demand Only"
        case thumbnails = "Thumbnails Only"
        case allImages = "All Images"

        var footerText: String {
            switch self {
            case .onDemand:
                return "Images load as you browse. Requires internet connection."
            case .thumbnails:
                return "Small preview images for offline browsing. Estimated ~160 MB total."
            case .allImages:
                return "Full-resolution images for offline use. Estimated ~640 MB total."
            }
        }
    }

    enum DownloadTiming: String, Codable {
        case immediate = "Immediately"
        case idle = "When Idle"
        case manual = "Manually"
    }

    // MARK: - Public API

    /// Download missing images based on user preferences
    func downloadMissingImages() async {
        let mode = ImageDownloadPreferences.shared.downloadMode
        let allowCellular = ImageDownloadPreferences.shared.allowCellular

        guard mode != .onDemand else {
            log.debug("Image download mode is on-demand, skipping pre-download")
            return
        }

        // Check network policy
        guard networkMonitor.isConnected else {
            log.warning("No network connection, skipping image download")
            return
        }

        if !allowCellular && !networkMonitor.isOnWiFi {
            log.info("Waiting for WiFi to download images")
            return
        }

        isDownloading = true
        downloadProgress = 0.0
        defer { isDownloading = false }

        do {
            // Get all catalog items
            let allItems = try await catalogService.getAllGlassItems()
            let totalItems = allItems.count

            log.info("Starting image download for \(totalItems) items (mode: \(mode.rawValue))")

            var downloadedCount = 0

            for (index, item) in allItems.enumerated() {
                // Download thumbnail
                if let thumbnailURL = item.glassItem.image_url,
                   !storageService.hasCachedImage(url: thumbnailURL, type: .thumbnail) {

                    do {
                        let imageData = try await downloadImage(url: thumbnailURL)
                        let thumbnail = generateThumbnail(from: imageData)
                        try storageService.cacheImage(thumbnail, url: thumbnailURL, type: .thumbnail)
                        downloadedCount += 1
                    } catch {
                        log.warning("Failed to download thumbnail for \(item.glassItem.stable_id): \(error)")
                    }
                }

                // Download full-res if mode is allImages
                if mode == .allImages,
                   let imageURL = item.glassItem.image_url,
                   !storageService.hasCachedImage(url: imageURL, type: .fullResolution) {

                    do {
                        let imageData = try await downloadImage(url: imageURL)
                        try storageService.cacheImage(imageData, url: imageURL, type: .fullResolution)
                    } catch {
                        log.warning("Failed to download full-res for \(item.glassItem.stable_id): \(error)")
                    }
                }

                // Update progress
                downloadProgress = Double(index + 1) / Double(totalItems)

                // Yield to allow UI updates
                if index % 10 == 0 {
                    await Task.yield()
                }
            }

            cachedImageCount = storageService.getCachedImageCount()

            log.info("✅ Downloaded \(downloadedCount) images")

        } catch {
            log.error("Image download failed: \(error.localizedDescription)")
        }
    }

    /// Download images for specific items (after catalog update)
    func downloadImagesForNewItems(_ items: [CompleteInventoryItemModel]) async {
        // Similar to downloadMissingImages but only for new items
    }

    /// Clear all cached images
    func clearImageCache() async {
        do {
            try await storageService.clearCache()
            cachedImageCount = 0
            log.info("Cleared image cache")
        } catch {
            log.error("Failed to clear image cache: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func downloadImage(url: String) async throws -> Data {
        guard let imageURL = URL(string: url) else {
            throw ImageDownloadError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: imageURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageDownloadError.downloadFailed
        }

        return data
    }

    private func generateThumbnail(from imageData: Data, maxSize: CGFloat = 200) -> Data {
        guard let image = UIImage(data: imageData) else {
            return imageData
        }

        let size = image.size
        let aspectRatio = size.width / size.height

        let thumbnailSize: CGSize
        if aspectRatio > 1 {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }

        UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail?.jpegData(compressionQuality: 0.8) ?? imageData
    }
}

enum ImageDownloadError: LocalizedError {
    case invalidURL
    case downloadFailed
    case storageFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .downloadFailed:
            return "Failed to download image"
        case .storageFailed:
            return "Failed to save image"
        }
    }
}
```

### Modified Startup Flow

**MoltenApp.swift changes:**

```swift
@main
struct MoltenApp: App {

    @StateObject private var catalogUpdateService = RepositoryFactory.createCatalogUpdateService()
    @StateObject private var imageDownloadService = RepositoryFactory.createImageDownloadService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Background tasks on app startup
                    await performStartupTasks()
                }
        }
    }

    private func performStartupTasks() async {
        // 1. Load bundled catalog if Core Data is empty
        await loadBundledCatalogIfNeeded()

        // 2. Check for catalog updates in background
        Task.detached(priority: .background) {
            await catalogUpdateService.performBackgroundUpdateCheck()
        }

        // 3. Download missing images in background
        Task.detached(priority: .background) {
            await imageDownloadService.downloadMissingImages()
        }
    }

    private func loadBundledCatalogIfNeeded() async {
        // Check if catalog is empty
        let catalogService = RepositoryFactory.createCatalogService()
        let existingItems = try? await catalogService.getAllGlassItems()

        if existingItems?.isEmpty ?? true {
            // Load bundled catalog
            let loadingService = RepositoryFactory.createGlassItemDataLoadingService()
            _ = try? await loadingService.loadGlassItemsFromJSON(options: .default)

            // Mark as bundled source
            CatalogUpdatePreferences.shared.catalogSource = .bundled
            CatalogUpdatePreferences.shared.currentCatalogVersion = 1
        }
    }
}
```

### Benefits of This Approach

**Immediate:**
- ✅ App works offline immediately (has catalog metadata)
- ✅ No "loading" screen on first launch
- ✅ User can browse catalog while images download in background
- ✅ Respects user data preferences

**Long-term:**
- ✅ Catalog updates propagate instantly (no App Store delay)
- ✅ Users control storage usage (on-demand vs full cache)
- ✅ Smaller initial download from App Store
- ✅ Fresh images always available

**User Experience Flow:**

```
App Launch
    ↓
Load bundled catalog → Show catalog immediately
    ↓                      ↓
Background:          User can browse
- Check updates      (sees placeholders for images)
- Download images         ↓
                    Images appear as they download
                          ↓
                    Catalog fully loaded + cached
```

### Storage Estimates

**Catalog JSON:** ~3.1 MB (bundled)

**Images:**
- On-Demand: 0 MB initial, grows with usage
- Thumbnails: ~160 MB (50 KB × 3,198 items)
- All Images: ~640 MB (200 KB × 3,198 items)

**Total App Bundle:**
- v1.5: ~15 MB (with bundled JSON, no images)
- v2.0: ~10 MB (OTA JSON, no images)

### Future Enhancements (v2.5+)

1. **Smart caching** - Download images for user's preferred manufacturers first
2. **Progressive loading** - Load visible images first, background load rest
3. **Image CDN** - Host images on our own CDN instead of Shopify
4. **WebP format** - Smaller file sizes (~30% reduction)
5. **Lazy image loading** - Only download when user scrolls to item

---

**End of Implementation Plan**

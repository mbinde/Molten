# Inventory Sharing Server Requirements

This document describes the server-side API requirements for the Molten inventory sharing feature. The server must implement three layers of security:

1. **App Attest** - Verify requests come from legitimate iOS app
2. **Certificate Pinning** - Enforce HTTPS with pinned certificates
3. **Ownership Verification** - Verify share modifications come from original owner

---

## API Endpoints

### Base URL
Production: `https://api.yourdomain.com`

All endpoints require HTTPS. HTTP requests should be rejected.

---

### 1. POST /share

**Description:** Create a new share

**Request Headers:**
```
Content-Type: application/json
X-Apple-Assertion: <base64-encoded assertion>  (iOS 14+ only)
```

**Request Body:**
```json
{
  "shareCode": "ABC123",
  "snapshotData": "<base64-encoded snapshot>",
  "publicKey": "<base64-encoded Ed25519 public key>"
}
```

**Response:**
- `201 Created` - Share created successfully
- `409 Conflict` - Share code already exists (client will retry with new code)
- `401 Unauthorized` - App Attest assertion invalid
- `400 Bad Request` - Invalid request body

**Server Implementation:**

```python
from flask import Flask, request, jsonify
from datetime import datetime, timedelta
import base64

app = Flask(__name__)

# Rate limiting decorator
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["100 per hour"]
)

@app.route('/share', methods=['POST'])
@limiter.limit("10 per hour")  # Max 10 share creations per hour per IP
def create_share():
    # 1. Verify App Attest assertion (iOS 14+)
    assertion = request.headers.get('X-Apple-Assertion')
    if assertion:
        if not verify_app_attest_assertion(assertion, request):
            return jsonify({"error": "Invalid app attestation"}), 401

    # 2. Parse request
    data = request.json
    share_code = data.get('shareCode')
    snapshot_data = data.get('snapshotData')
    public_key = data.get('publicKey')

    if not all([share_code, snapshot_data, public_key]):
        return jsonify({"error": "Missing required fields"}), 400

    # 3. Check if share code already exists
    if share_exists(share_code):
        return jsonify({"error": "Share code already exists"}), 409

    # 4. Store share in database
    store_share(
        share_code=share_code,
        snapshot_data=snapshot_data,
        public_key=public_key,
        created_at=datetime.utcnow()
    )

    return '', 201


def verify_app_attest_assertion(assertion_base64, request):
    """
    Verify Apple App Attest assertion.

    See: https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server
    """
    import hashlib
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography import x509

    # 1. Decode assertion
    assertion = base64.b64decode(assertion_base64)

    # 2. Parse assertion (CBOR format)
    import cbor2
    assertion_obj = cbor2.loads(assertion)

    # 3. Extract signature and authenticator data
    signature = assertion_obj['signature']
    authenticator_data = assertion_obj['authenticatorData']

    # 4. Reconstruct client data
    method = request.method
    path = request.path
    body_hash = hashlib.sha256(request.get_data()).hexdigest() if request.get_data() else ''
    client_data = f"{method}-{path}-{body_hash}".encode('utf-8')
    client_data_hash = hashlib.sha256(client_data).digest()

    # 5. Get public key for this key ID (from initial attestation)
    key_id = get_key_id_from_authenticator_data(authenticator_data)
    public_key = get_stored_public_key(key_id)

    if not public_key:
        return False

    # 6. Verify signature
    try:
        public_key.verify(
            signature,
            authenticator_data + client_data_hash,
            ec.ECDSA(hashes.SHA256())
        )
        return True
    except:
        return False
```

---

### 2. GET /share/:shareCode

**Description:** Download a friend's share

**Request Headers:**
```
X-Apple-Assertion: <base64-encoded assertion>  (iOS 14+ only)
```

**Response:**
- `200 OK` - Share found
  ```json
  {
    "snapshotData": "<base64-encoded snapshot>",
    "publicKey": "<base64-encoded public key>"
  }
  ```
- `404 Not Found` - Share code doesn't exist
- `401 Unauthorized` - App Attest assertion invalid

**Server Implementation:**

```python
@app.route('/share/<share_code>', methods=['GET'])
@limiter.limit("60 per hour")  # Max 60 downloads per hour per IP
def get_share(share_code):
    # 1. Verify App Attest assertion
    assertion = request.headers.get('X-Apple-Assertion')
    if assertion:
        if not verify_app_attest_assertion(assertion, request):
            return jsonify({"error": "Invalid app attestation"}), 401

    # 2. Fetch share from database
    share = get_share_from_db(share_code)

    if not share:
        return jsonify({"error": "Share not found"}), 404

    # 3. Return share data
    return jsonify({
        "snapshotData": share['snapshot_data'],
        "publicKey": share['public_key']
    }), 200
```

---

### 3. PUT /share/:shareCode

**Description:** Update existing share

**Request Headers:**
```
Content-Type: application/json
X-Apple-Assertion: <base64-encoded assertion>  (iOS 14+ only)
X-Ownership-Signature: <base64-encoded Ed25519 signature>
```

**Request Body:**
```json
{
  "snapshotData": "<base64-encoded snapshot>",
  "publicKey": "<base64-encoded public key>"
}
```

**Response:**
- `200 OK` - Share updated successfully
- `404 Not Found` - Share doesn't exist
- `401 Unauthorized` - App Attest assertion invalid
- `403 Forbidden` - Ownership signature invalid

**Ownership Verification:**
The `X-Ownership-Signature` header contains an Ed25519 signature of the share code, signed with the original private key. This proves the client owns the private key that created the share.

**Server Implementation:**

```python
@app.route('/share/<share_code>', methods=['PUT'])
@limiter.limit("30 per hour")  # Max 30 updates per hour per IP
def update_share(share_code):
    # 1. Verify App Attest assertion
    assertion = request.headers.get('X-Apple-Assertion')
    if assertion:
        if not verify_app_attest_assertion(assertion, request):
            return jsonify({"error": "Invalid app attestation"}), 401

    # 2. Fetch existing share
    share = get_share_from_db(share_code)

    if not share:
        return jsonify({"error": "Share not found"}), 404

    # 3. Verify ownership signature
    ownership_signature = request.headers.get('X-Ownership-Signature')
    if not ownership_signature:
        return jsonify({"error": "Missing ownership signature"}), 403

    if not verify_ownership_signature(
        signature_base64=ownership_signature,
        data=share_code.encode('utf-8'),
        public_key_base64=share['public_key']
    ):
        return jsonify({"error": "Invalid ownership signature"}), 403

    # 4. Update share
    data = request.json
    update_share_in_db(
        share_code=share_code,
        snapshot_data=data.get('snapshotData'),
        public_key=data.get('publicKey'),
        updated_at=datetime.utcnow()
    )

    return '', 200


def verify_ownership_signature(signature_base64, data, public_key_base64):
    """
    Verify Ed25519 signature proves ownership of private key.
    """
    from cryptography.hazmat.primitives.asymmetric import ed25519
    import base64

    try:
        # Decode signature and public key
        signature = base64.b64decode(signature_base64)
        public_key_bytes = base64.b64decode(public_key_base64)

        # Create public key object
        public_key = ed25519.Ed25519PublicKey.from_public_bytes(public_key_bytes)

        # Verify signature
        public_key.verify(signature, data)
        return True
    except Exception as e:
        print(f"Ownership verification failed: {e}")
        return False
```

---

### 4. DELETE /share/:shareCode

**Description:** Delete a share

**Request Headers:**
```
X-Apple-Assertion: <base64-encoded assertion>  (iOS 14+ only)
X-Ownership-Signature: <base64-encoded Ed25519 signature>
```

**Response:**
- `204 No Content` - Share deleted successfully
- `404 Not Found` - Share doesn't exist
- `401 Unauthorized` - App Attest assertion invalid
- `403 Forbidden` - Ownership signature invalid

**Server Implementation:**

```python
@app.route('/share/<share_code>', methods=['DELETE'])
@limiter.limit("30 per hour")  # Max 30 deletes per hour per IP
def delete_share(share_code):
    # 1. Verify App Attest assertion
    assertion = request.headers.get('X-Apple-Assertion')
    if assertion:
        if not verify_app_attest_assertion(assertion, request):
            return jsonify({"error": "Invalid app attestation"}), 401

    # 2. Fetch existing share
    share = get_share_from_db(share_code)

    if not share:
        return jsonify({"error": "Share not found"}), 404

    # 3. Verify ownership signature
    ownership_signature = request.headers.get('X-Ownership-Signature')
    if not ownership_signature:
        return jsonify({"error": "Missing ownership signature"}), 403

    if not verify_ownership_signature(
        signature_base64=ownership_signature,
        data=share_code.encode('utf-8'),
        public_key_base64=share['public_key']
    ):
        return jsonify({"error": "Invalid ownership signature"}), 403

    # 4. Delete share
    delete_share_from_db(share_code)

    return '', 204
```

---

## Database Schema

```sql
CREATE TABLE shares (
    share_code VARCHAR(6) PRIMARY KEY,
    snapshot_data TEXT NOT NULL,  -- Base64-encoded snapshot
    public_key VARCHAR(64) NOT NULL,  -- Base64-encoded Ed25519 public key
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP,
    last_accessed TIMESTAMP,
    access_count INTEGER DEFAULT 0,
    created_ip VARCHAR(45),  -- For abuse detection
    INDEX idx_created_at (created_at)
);

CREATE TABLE app_attest_keys (
    key_id VARCHAR(255) PRIMARY KEY,
    public_key BYTEA NOT NULL,  -- Apple attestation public key
    attestation_object BYTEA NOT NULL,  -- Full attestation from first registration
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_used TIMESTAMP,
    assertion_count INTEGER DEFAULT 0,
    device_fingerprint VARCHAR(255),  -- For anomaly detection
    INDEX idx_last_used (last_used)
);

CREATE TABLE rate_limit_log (
    ip_address VARCHAR(45) NOT NULL,
    endpoint VARCHAR(50) NOT NULL,
    request_count INTEGER DEFAULT 1,
    window_start TIMESTAMP NOT NULL,
    PRIMARY KEY (ip_address, endpoint, window_start)
);
```

---

## Security Best Practices

### 1. Rate Limiting (CRITICAL)

Implement aggressive rate limits to prevent abuse:

```python
# Per IP address limits
POST /share:     10 requests/hour
GET /share/:id:  60 requests/hour
PUT /share/:id:  30 requests/hour
DELETE /share/:id: 30 requests/hour

# Global limits
POST /share:     1000 requests/hour globally

# Per device (App Attest key ID) limits
POST /share:     5 requests/hour per device
PUT /share/:id:  10 requests/hour per device
```

### 2. Anomaly Detection

Monitor for suspicious patterns:
- Too many unique share codes from same IP
- Rapid creation/deletion cycles
- Downloads of many different shares from same IP
- Failed ownership verification attempts

### 3. Data Retention

Implement automatic cleanup:
```python
# Delete shares older than 90 days
DELETE FROM shares
WHERE created_at < NOW() - INTERVAL '90 days';

# Delete shares not accessed in 30 days
DELETE FROM shares
WHERE last_accessed < NOW() - INTERVAL '30 days'
   OR (last_accessed IS NULL AND created_at < NOW() - INTERVAL '30 days');
```

### 4. HTTPS Certificate Pinning

The iOS app pins your server's SSL certificate. When deploying:

1. **Extract your server's certificate:**
   ```bash
   openssl s_client -connect api.yourdomain.com:443 -showcerts < /dev/null \
     | openssl x509 -outform DER > cert.der
   ```

2. **Add to iOS app bundle:**
   - Add `cert.der` to Xcode project
   - Load certificate data at runtime:
     ```swift
     guard let certURL = Bundle.main.url(forResource: "cert", withExtension: "der"),
           let certData = try? Data(contentsOf: certURL) else {
         fatalError("Missing certificate")
     }

     let client = InventorySharingAPIClient(pinnedCertificates: [certData])
     ```

3. **Certificate rotation:**
   - When renewing certificates, deploy new cert to server first
   - Update iOS app with new pinned certificate
   - Only after app update is released, remove old certificate

### 5. App Attest Initial Registration

Before clients can make authenticated requests, they must register their attestation key:

```python
@app.route('/attest/register', methods=['POST'])
def register_attestation():
    """
    Register a new App Attest key.

    Request body:
    {
      "keyId": "<App Attest key ID>",
      "attestation": "<base64-encoded attestation object>",
      "challenge": "<base64-encoded server challenge>"
    }
    """
    data = request.json
    key_id = data.get('keyId')
    attestation_base64 = data.get('attestation')
    challenge_base64 = data.get('challenge')

    # 1. Verify attestation with Apple
    # See: https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server

    attestation = base64.b64decode(attestation_base64)
    challenge = base64.b64decode(challenge_base64)

    # 2. Validate attestation is for your app
    # Extract and verify app ID from attestation

    # 3. Store key ID and public key
    store_attest_key(
        key_id=key_id,
        attestation_object=attestation,
        public_key=extract_public_key_from_attestation(attestation)
    )

    return '', 201
```

---

## Deployment Checklist

- [ ] HTTPS enabled with valid certificate
- [ ] Certificate pinning configured in iOS app
- [ ] Rate limiting configured on all endpoints
- [ ] Database schema created
- [ ] App Attest validation implemented
- [ ] Ownership signature verification implemented
- [ ] Automated cleanup jobs scheduled
- [ ] Monitoring and alerting configured
- [ ] Backup strategy in place
- [ ] Disaster recovery plan documented

---

## Testing the Server

Use these curl commands to test your implementation:

### Create Share
```bash
curl -X POST https://api.yourdomain.com/share \
  -H "Content-Type: application/json" \
  -d '{
    "shareCode": "TEST01",
    "snapshotData": "'"$(echo -n '{"items":[],"timestamp":"2025-01-01T00:00:00Z","version":"1.0"}' | base64)"'",
    "publicKey": "'"$(openssl rand -base64 32)"'"
  }'
```

### Get Share
```bash
curl https://api.yourdomain.com/share/TEST01
```

### Update Share (with ownership signature)
```bash
# Note: Requires valid Ed25519 signature
curl -X PUT https://api.yourdomain.com/share/TEST01 \
  -H "Content-Type: application/json" \
  -H "X-Ownership-Signature: <base64-signature>" \
  -d '{
    "snapshotData": "'"$(echo -n '{"items":[...],"timestamp":"2025-01-02T00:00:00Z","version":"1.0"}' | base64)"'",
    "publicKey": "'"$(openssl rand -base64 32)"'"
  }'
```

### Delete Share
```bash
curl -X DELETE https://api.yourdomain.com/share/TEST01 \
  -H "X-Ownership-Signature: <base64-signature>"
```

---

## Monitoring

Key metrics to track:
- Requests per endpoint per hour
- Failed ownership verification rate
- Failed App Attest assertion rate
- Share creation rate
- Unique IPs per hour
- Database size growth
- Average response time per endpoint

Alert on:
- Failed ownership verification > 10/hour
- Failed App Attest > 20/hour
- Share creation > 1000/hour
- Database > 90% capacity
- Response time > 1 second

---

## Support

For questions about the Molten inventory sharing implementation:
- See `InventorySharingService.swift` for client-side crypto
- See `AttestationManager.swift` for App Attest implementation
- See `InventorySharingAPIClient.swift` for request format

For Apple App Attest documentation:
- https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server

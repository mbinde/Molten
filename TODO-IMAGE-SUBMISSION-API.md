# Image Submission API - TODO

## Overview
Users can now submit manufacturer images for consideration via the iOS app. We need to implement the backend API to receive and store these submissions.

## API Requirements

### Endpoint
`POST /api/v1/submit-image`

### Request Format
```json
{
  "glassItem": {
    "stable_id": "bullseye-0001-0",
    "name": "Bullseye Red Opal",
    "manufacturer": "be",
    "code": "0001"
  },
  "email": "user@example.com",
  "image": "base64-encoded-image-data",
  "hasPermission": true,
  "offersFreeOfCharge": true
}
```

### Response Format
**Success (200)**:
```json
{
  "success": true,
  "submissionId": "uuid-here"
}
```

**Error (400/500)**:
```json
{
  "success": false,
  "error": "Error message here"
}
```

## Implementation Tasks

- [ ] Create API endpoint in molten-website (Astro/Cloudflare)
- [ ] Set up image storage (Cloudflare R2 or similar)
- [ ] Create submission tracking database/table
- [ ] Add email notification system (notify admin of new submissions)
- [ ] Implement rate limiting (prevent abuse)
- [ ] Add submission review admin panel (optional, could be manual)

## iOS App Integration

Update `ImageSubmissionSheet.swift`:
1. Convert UIImage to base64
2. Make POST request to API
3. Handle success/error responses
4. Show appropriate user feedback

Example implementation:
```swift
private func submitImage() {
    isSubmitting = true
    errorMessage = nil

    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        errorMessage = "Failed to process image"
        isSubmitting = false
        return
    }

    let base64Image = imageData.base64EncodedString()

    let payload: [String: Any] = [
        "glassItem": [
            "stable_id": glassItem.stable_id,
            "name": glassItem.name,
            "manufacturer": glassItem.manufacturer,
            "code": glassItem.code
        ],
        "email": email,
        "image": base64Image,
        "hasPermission": hasPermission,
        "offersFreeOfCharge": offersFreeOfCharge
    ]

    // Make API request
    Task {
        do {
            // TODO: Implement API call
            try await submitToAPI(payload)
            await MainActor.run {
                isSubmitting = false
                showingConfirmation = true
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

## Security Considerations

1. **Rate Limiting**: Limit submissions per user/IP (e.g., 5 per day)
2. **Image Validation**:
   - Check file size (max 5MB)
   - Validate image format (JPEG/PNG only)
   - Scan for malicious content
3. **Email Validation**: Verify email format server-side
4. **Spam Protection**: Consider CAPTCHA or similar
5. **Terms Enforcement**: Store checkbox states with submission

## Storage Strategy

**Option A: Cloudflare R2**
- Pro: Cheap storage, integrated with Workers
- Con: Requires setup

**Option B: Direct to email**
- Pro: Simple, no storage needed
- Con: Manual processing

**Option C: GitHub Issues**
- Pro: Free, built-in tracking
- Con: Public, requires GitHub account

Recommend: **Option A** for production, **Option B** for MVP

## Email Template

Subject: New Image Submission for {glass_item_name}

Body:
```
New image submission received:

Glass Item: {stable_id} - {name}
Manufacturer: {manufacturer}
Code: {code}

Submitted by: {email}

Terms accepted:
- Has permission: Yes
- Free of charge: Yes

View image: {image_url}

Submission ID: {uuid}
Timestamp: {timestamp}
```

## Future Enhancements

- [ ] Add voting/rating system for submitted images
- [ ] Auto-approve images from trusted users
- [ ] Batch review interface
- [ ] Image quality analysis (blur detection, resolution check)
- [ ] Duplicate detection

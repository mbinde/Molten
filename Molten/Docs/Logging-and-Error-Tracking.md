# Logging and Error Tracking

Complete guide to the Molten logging system with Sentry integration.

---

## Overview

Molten uses a **unified logging system** that combines local logging (OSLog) with remote error tracking (Sentry). The system is designed to:

- ✅ Log everything locally for debugging (OSLog/Console.app)
- ✅ Send only errors/critical issues to Sentry for pattern detection
- ✅ Filter sensitive data automatically (anonymous tracking only)
- ✅ Capture breadcrumbs (user actions) leading up to errors
- ✅ Be configurable per environment (debug, testflight, production)
- ✅ Work seamlessly in tests (uses MockLogger automatically)

---

## Architecture

### LogLevel Enum

Defines log severity (debug < info < warning < error < critical):

```swift
public enum LogLevel: Int, Comparable {
    case debug = 0      // Detailed debugging info
    case info = 1       // General information
    case warning = 2    // Potential issues
    case error = 3      // Errors that need attention
    case critical = 4   // Critical failures
}
```

**Default Remote Logging**: Only `.error` and `.critical` are sent to Sentry by default.

### LoggerBackend Protocol

```swift
public protocol LoggerBackend: Sendable {
    func log(level: LogLevel, message: String, context: [String: Any]?, error: Error?, ...)
    func logError(_ error: Error, message: String?, context: [String: Any]?, ...)
}
```

**Implementations**:
- `MockLogger` - Captures logs for testing
- `SentryLogger` - Sends to Sentry for production error tracking

### LoggingService

Main service that coordinates all logging backends:

```swift
@MainActor
public final class LoggingService {
    // Configured in AppDependencies
    init(
        backends: [LoggerBackend],
        minimumLocalLevel: LogLevel = .debug,
        minimumRemoteLevel: LogLevel = .error
    )
}
```

---

## Setup

### 1. Install Sentry SDK

Add to your `Package.swift` or Xcode project:

```swift
dependencies: [
    .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0")
]
```

### 2. Get Sentry DSN

1. Create account at [sentry.io](https://sentry.io)
2. Create new project → Select "iOS / Swift"
3. Copy your DSN (looks like: `https://abc123@o123.ingest.sentry.io/456`)

### 3. Configure Environment Variable

**Option A: Xcode Scheme (Recommended)**

1. Edit Scheme → Run → Arguments → Environment Variables
2. Add: `SENTRY_DSN` = `your-dsn-here`

**Option B: Info.plist**

```xml
<key>SentryDSN</key>
<string>$(SENTRY_DSN)</string>
```

Then set in build settings: `SENTRY_DSN = your-dsn`

**Option C: Hardcode (NOT recommended for production)**

Edit `AppDependencies.swift:230`:

```swift
let sentryDSN = "https://your-dsn-here"
```

### 4. Initialize Sentry SDK (Required)

The current implementation is a **placeholder**. To actually send to Sentry, update `SentryLogger.swift:174`:

```swift
import Sentry  // Add this import at top

// Replace the placeholder sendToSentry implementation with:
private func sendToSentry(...) {
    // ... existing context enrichment code ...

    // Create Sentry event
    let event = Event(level: SentryLevel(level.sentryLevel))
    event.message = SentryMessage(formatted: message)
    event.extra = enrichedContext

    if let error = error {
        event.exceptions = [Exception(value: error)]
    }

    // Attach breadcrumbs
    event.breadcrumbs = breadcrumbs.map { breadcrumb in
        Breadcrumb(level: .info, category: breadcrumb.category).apply {
            $0.message = breadcrumb.message
            $0.timestamp = breadcrumb.timestamp
            $0.data = breadcrumb.data
        }
    }

    SentrySDK.capture(event: event)
}
```

Also add to `MoltenApp.swift` in `init()`:

```swift
import Sentry

init() {
    // Initialize Sentry
    if let dsn = ProcessInfo.processInfo.environment["SENTRY_DSN"], !dsn.isEmpty {
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = SentryEnvironment.current.rawValue
            options.tracesSampleRate = 1.0  // Adjust for production (0.1 = 10%)
            options.enableAutoSessionTracking = true
        }
    }

    // ... rest of init ...
}
```

---

## Usage

### Basic Logging

```swift
struct CatalogService {
    private let logger: LoggingService

    init(/* ... */, logger: LoggingService = AppDependencies.shared.loggingService) {
        self.logger = logger
    }

    func downloadCatalog() async throws {
        logger.info("Starting catalog download")

        do {
            let items = try await fetchItems()
            logger.info("Downloaded \(items.count) items", context: [
                "operation": "catalog-download",
                "itemCount": items.count
            ])
        } catch {
            logger.error("Catalog download failed", context: [
                "operation": "catalog-download",
                "error": error.localizedDescription
            ], error: error)
            throw error
        }
    }
}
```

### Logging Levels

```swift
// Debug - detailed information (local only)
logger.debug("Cache hit for item: \(itemId)")

// Info - general information (local only)
logger.info("User viewed catalog", context: ["section": "glass-rods"])

// Warning - potential issues (local only)
logger.warning("Low disk space", context: ["available_mb": 50])

// Error - needs attention (sent to Sentry)
logger.error("API request failed", context: [
    "operation": "fetch-ratings",
    "status_code": 500
])

// Critical - severe failures (sent to Sentry)
logger.critical("Database corruption detected", context: [
    "operation": "core-data-integrity-check"
])
```

### Logging Errors with AppError

The logger automatically extracts structured data from `AppError`:

```swift
let error = AppError(
    category: .network,
    severity: .error,
    userMessage: "Catalog download failed",
    technicalDetails: "HTTP 500 from api.molten.app",
    suggestions: ["Try again later", "Check your internet connection"]
)

logger.logError(error, message: "Catalog operation failed", context: [
    "operation": "catalog-download",
    "retry_count": 3
])
```

This automatically adds to Sentry:
- `error_category`: "Network"
- `error_severity`: "ERROR"
- `technical_details`: "HTTP 500 from api.molten.app"
- `suggestions`: "Try again later; Check your internet connection"

### Pattern Detection

Use consistent context keys to detect patterns in Sentry:

```swift
// Catalog downloads
logger.error("Catalog download failed", context: [
    "operation": "catalog-download",  // Tag for filtering
    "http_status": 500,
    "retry_count": 3
])

// Rating cache rebuilds
logger.error("Rating cache rebuild failed", context: [
    "operation": "rating-cache-rebuild",
    "items_processed": 150,
    "items_failed": 5
])

// Inventory sync issues
logger.error("CloudKit sync timeout", context: [
    "operation": "cloudkit-sync",
    "entity": "Inventory",
    "timeout_seconds": 30
])
```

**In Sentry Dashboard**:
- Filter by `operation:catalog-download` to see all catalog failures
- Set up alerts: "Notify if operation:catalog-download > 10 events/hour"

### Breadcrumbs (User Actions)

Track user actions leading up to errors:

```swift
// In your ViewModels or Services
logger.debug("User viewed catalog")  // Auto-captured as breadcrumb
logger.debug("User searched for 'Bullseye'")
logger.debug("User added item to cart")

// When error occurs, Sentry includes these breadcrumbs
logger.error("Checkout failed", error: checkoutError)
```

**Sentry will show**:
```
Timeline:
  12:00:00 - User viewed catalog
  12:00:15 - User searched for 'Bullseye'
  12:00:30 - User added item to cart
  12:00:45 - ❌ ERROR: Checkout failed
```

---

## Configuration

### Environment-Specific Settings

The logger automatically detects the environment:

```swift
public enum SentryEnvironment {
    case debug       // Local development
    case testFlight  // Beta testing
    case production  // App Store
    case test        // Unit tests (no Sentry)
}
```

**Automatic detection** in `SentryLogger.swift:30`:
- Debug builds → `.debug`
- TestFlight builds → `.testFlight` (checks for sandboxReceipt)
- Production builds → `.production`
- Tests → `.test` (no Sentry calls)

### Adjusting Log Levels

Edit `AppDependencies.swift:246`:

```swift
return LoggingService(
    backends: backends,
    minimumLocalLevel: .debug,     // Change to .warning to reduce local logs
    minimumRemoteLevel: .error     // Change to .critical to only send critical
)
```

**Common configurations**:

```swift
// Development: Log everything locally, send errors remotely
minimumLocalLevel: .debug
minimumRemoteLevel: .error

// Production: Reduce local logs, send errors remotely
minimumLocalLevel: .info
minimumRemoteLevel: .error

// TestFlight: Moderate local logs, send all warnings
minimumLocalLevel: .warning
minimumRemoteLevel: .warning

// Debug build with no remote logging
minimumLocalLevel: .debug
minimumRemoteLevel: .critical  // Nothing will be sent (no critical logs normally)
```

### Sensitive Data Filtering

The logger automatically filters sensitive keys (see `SentryLogger.swift:261`):

```swift
let sensitiveKeys = [
    "password", "token", "secret", "api_key",
    "apiKey", "creditCard", "ssn", "email"
]
```

**Always filtered** (anonymous mode):
- Email addresses
- Passwords, tokens, secrets
- Credit card numbers

**Always included** (safe for anonymous tracking):
- Device model, OS version
- App version, build number
- Operation names, error categories
- CloudKit user ID hash (anonymous identifier)

---

## Testing

### Unit Tests

Tests automatically use `MockLogger` via `AppDependencies.shared`:

```swift
@MainActor
final class MyServiceTests: XCTestCase {
    func testCatalogDownload() async throws {
        let deps = AppDependencies.shared  // Uses MockLogger automatically
        let service = CatalogService(/* inject deps */)

        // Service logs internally
        try await service.downloadCatalog()

        // Verify logs (if needed - usually not necessary)
        // MockLogger is internal to AppDependencies
    }
}
```

### Integration Tests

To verify logging behavior:

```swift
func testLoggingIntegration() {
    let mockLogger = MockLogger()
    let service = LoggingService(
        backends: [mockLogger],
        minimumLocalLevel: .debug,
        minimumRemoteLevel: .error
    )

    service.error("Test error", context: ["key": "value"])

    XCTAssertEqual(mockLogger.logs.count, 1)
    XCTAssertEqual(mockLogger.logs[0].level, .error)
    XCTAssertEqual(mockLogger.logs[0].context?["key"] as? String, "value")
}
```

---

## Sentry Dashboard

### Setting Up Alerts (Email Notifications)

1. Go to **Alerts** → **Create Alert**
2. Choose **Issues**
3. Set conditions:
   ```
   WHEN: new issue is created
   WHERE: environment = production
   AND tags contain: operation:catalog-download
   THEN: Send email to: you@example.com
   ```

4. For pattern detection:
   ```
   WHEN: event count > 10 in 1 hour
   WHERE: tags contain: operation:catalog-download
   THEN: Send email to: you@example.com
   ```

### Useful Filters

```
// All catalog download errors
operation:catalog-download

// All rating cache errors
operation:rating-cache-rebuild

// All CloudKit sync errors
operation:cloudkit-sync

// Critical errors only
level:fatal

// Errors in production only
environment:production
```

### Sample Dashboard Query

```
// Show catalog download failure rate over time
SELECT count() WHERE operation = 'catalog-download' AND level >= 'error'
GROUP BY time(1h)
```

---

## Migration from Old Error Handling

### Before (Old Pattern)

```swift
import OSLog

class MyService {
    private let log = Logger(subsystem: "...", category: "...")

    func doSomething() {
        do {
            try riskyOperation()
        } catch {
            log.error("Operation failed: \(error.localizedDescription)")
            // Error is lost - not tracked remotely
        }
    }
}
```

### After (New Pattern)

```swift
class MyService {
    private let logger: LoggingService

    init(logger: LoggingService = AppDependencies.shared.loggingService) {
        self.logger = logger
    }

    func doSomething() async throws {
        do {
            try await riskyOperation()
        } catch {
            logger.error("Operation failed", context: [
                "operation": "risky-operation"
            ], error: error)
            // ✅ Logged locally (OSLog)
            // ✅ Sent to Sentry with context
            // ✅ Pattern detection enabled
            throw error  // Still propagate for UI handling
        }
    }
}
```

---

## Best Practices

### ✅ DO

- Use consistent `operation` keys in context for pattern detection
- Log errors with context: `logger.error("...", context: ["operation": "..."])`
- Use `logger.logError(error, message: ...)` for caught exceptions
- Include relevant metadata: item counts, HTTP status, retry counts
- Let errors propagate up for UI error handling
- Use debug/info for breadcrumbs (user actions)

### ❌ DON'T

- Don't log sensitive data (passwords, emails, tokens)
- Don't swallow errors silently - always log them
- Don't use `print()` for error logging
- Don't create new loggers in `.task`/`.onAppear` (use init injection)
- Don't log PII (personally identifiable information)

### Example: Catalog Download with Pattern Detection

```swift
func downloadCatalog() async throws {
    logger.info("Starting catalog download", context: ["operation": "catalog-download"])

    do {
        let response = try await apiClient.fetchCatalog()

        logger.info("Catalog downloaded successfully", context: [
            "operation": "catalog-download",
            "itemCount": response.items.count,
            "duration_ms": response.duration
        ])

    } catch let error as URLError {
        logger.error("Catalog download failed - network error", context: [
            "operation": "catalog-download",
            "error_code": error.code.rawValue,
            "url": error.failingURL?.absoluteString ?? "unknown"
        ], error: error)
        throw error

    } catch {
        logger.error("Catalog download failed - unknown error", context: [
            "operation": "catalog-download"
        ], error: error)
        throw error
    }
}
```

**Benefits**:
- ✅ All catalog failures tagged with `operation:catalog-download`
- ✅ Easy to filter in Sentry: "Show me all catalog download failures this week"
- ✅ Set up alerts: "Email me if catalog downloads fail > 5 times/hour"
- ✅ Rich context for debugging (error codes, URLs, item counts)

---

## Troubleshooting

### Logs Not Appearing in Sentry

1. **Check DSN is configured**: `echo $SENTRY_DSN` in Xcode scheme
2. **Check environment**: Debug builds might have empty DSN
3. **Check log level**: Only `.error` and `.critical` send remotely by default
4. **Verify Sentry SDK**: Make sure you completed step 4 in Setup (initialize SDK)
5. **Check Sentry quota**: Free tier has limits (5k events/month)

### Too Many Logs in Sentry

Adjust `minimumRemoteLevel` in `AppDependencies.swift`:

```swift
minimumRemoteLevel: .critical  // Only send critical errors
```

Or filter specific operations:

```swift
// Add to LoggingService
func shouldSendRemotely(level: LogLevel, context: [String: Any]?) -> Bool {
    // Don't send certain operations remotely
    if let operation = context?["operation"] as? String {
        let ignoredOperations = ["debug-print", "cache-hit"]
        if ignoredOperations.contains(operation) {
            return false
        }
    }
    return level >= minimumRemoteLevel
}
```

### Testing Sentry Integration

```swift
// Add a test button in debug builds
#if DEBUG
Button("Test Sentry Error") {
    AppDependencies.shared.loggingService.error("Test error from debug build", context: [
        "operation": "sentry-test",
        "test": true
    ])
}
#endif
```

Check Sentry dashboard for the event.

---

## Files Reference

- `LoggingService.swift` - Main logging service and protocol
- `SentryLogger.swift` - Sentry backend implementation
- `AppDependencies.swift` - Dependency injection configuration
- `SimpleErrorHandling.swift` - Legacy error handling (still used for UI errors)

---

## Future Enhancements

- [ ] Add automatic crash reporting (Sentry SDK handles this)
- [ ] Add performance monitoring (track slow operations)
- [ ] Add session replay (Sentry feature for reproducing UI bugs)
- [ ] Add custom user properties (when user opts into non-anonymous tracking)
- [ ] Add integration with App Store Connect for crash reports

# NeuralCanvas Sandbox Security Audit

## Audit Date
January 2026

## Summary
NeuralCanvas has been audited for App Store sandbox compliance. The application is designed as a privacy-first, local-only tool with minimal entitlements.

---

## Entitlements Review

### Current Entitlements (`NeuralCanvas.entitlements`)

| Entitlement | Status | Justification |
|-------------|--------|---------------|
| `com.apple.security.app-sandbox` | ✅ Enabled | Required for Mac App Store |
| `com.apple.security.files.user-selected.read-write` | ✅ Enabled | Required for importing screenshots and exporting wireframes |

### Entitlements NOT Used

The following entitlements are explicitly **not** requested:

- ❌ `com.apple.security.network.client` - No network access needed
- ❌ `com.apple.security.network.server` - No server functionality
- ❌ `com.apple.security.files.downloads.read-write` - Not accessing Downloads
- ❌ `com.apple.security.files.user-selected.executable` - No executable files
- ❌ `com.apple.security.temporary-exception.*` - No exceptions needed
- ❌ `com.apple.security.device.*` - No device access (camera, microphone, etc.)

---

## Network Usage Audit

### URLSession/URLRequest Usage
**Result: NONE FOUND** ✅

```bash
grep -r "URLSession\|URLRequest\|NSURLSession" NeuralCanvas/
# No matches
```

### Network Frameworks
**Result: NOT IMPORTED** ✅

The app does not import:
- Network.framework
- CFNetwork.framework
- WebKit (for network purposes)

---

## File System Access Audit

### File Operations
All file operations go through:
1. **SwiftData/ModelContainer** - Uses app's sandbox container
2. **User-selected files** - Via NSOpenPanel/NSSavePanel (sandbox-allowed)
3. **Temporary files** - Uses system temp directory within sandbox

### Verified Safe Usage
- `FileManager.default.ubiquityIdentityToken` - Only for CloudKit availability check
- SwiftData storage in `~/Library/Application Support/`

### No Direct File Access
- ❌ No hardcoded file paths
- ❌ No access to `/`, `/Users`, `/Applications`
- ❌ No access to other apps' containers

---

## Data Privacy Audit

### Data Storage
| Data Type | Storage Location | Encryption |
|-----------|-----------------|------------|
| Projects | SwiftData (local) | System-level |
| Sketches | SwiftData (local) | System-level |
| Style Presets | SwiftData (local) | System-level |
| Preferences | UserDefaults | System-level |

### Data Not Collected
- ❌ No analytics
- ❌ No crash reporting to external services
- ❌ No user tracking
- ❌ No telemetry

### Data Not Transmitted
- ❌ No data sent to servers
- ❌ No data shared with third parties
- ❌ No cloud sync (CloudKit is optional and user-initiated)

---

## Third-Party Dependencies

**Result: NONE** ✅

NeuralCanvas uses only Apple frameworks:
- SwiftUI
- SwiftData
- CoreML
- Metal
- MetalKit
- AppKit (macOS)
- OSLog

No third-party libraries, SDKs, or dependencies.

---

## CoreML Model Security

### Model Source
- Models are bundled with the app
- No runtime model downloads
- No model updates from network

### Model Data
- Models process images locally
- Input/output stays in memory
- No persistent storage of processed data beyond user saves

---

## Hardened Runtime

The app is configured for hardened runtime:
- Code signing required
- Library validation enabled
- No JIT compilation
- No unsigned executable memory

---

## Recommendations

### Implemented ✅
1. Minimal entitlements
2. No network access
3. No third-party dependencies
4. SwiftData for secure local storage
5. User-selected file access only

### Future Considerations
1. Consider implementing certificate pinning if CloudKit sync is enabled
2. Add runtime integrity checks for ML models
3. Implement secure enclave for any future sensitive data

---

## Compliance Checklist

- [x] App Sandbox enabled
- [x] No unauthorized network access
- [x] No unauthorized file system access
- [x] User data stored securely
- [x] No third-party analytics
- [x] No tracking or telemetry
- [x] Hardened runtime configured
- [x] Entitlements are minimal
- [x] No temporary exceptions

---

## Audit Result

**PASS** ✅

NeuralCanvas meets all requirements for Mac App Store sandbox compliance and privacy best practices.

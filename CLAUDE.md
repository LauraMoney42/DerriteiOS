# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Alerta is a highly secure, privacy-focused anonymous safety reporting iOS app built with SwiftUI. The app allows users to create location-based safety reports/pins that expire after 8 hours, with maximum anonymity and security.

## Build and Run Commands
```bash
# Open project in Xcode
open Derrite.xcodeproj

# Build from command line
xcodebuild -project Derrite.xcodeproj -scheme Derrite -sdk iphonesimulator -configuration Debug build

# Clean build
xcodebuild -project Derrite.xcodeproj -scheme Derrite clean

# Run tests (if available)
xcodebuild -project Derrite.xcodeproj -scheme Derrite -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test
```

## Architecture
- **Language**: Swift with SwiftUI framework
- **Minimum iOS Version**: iOS 15.0+
- **Main Entry Point**: `DerriteApp.swift` - SwiftUI App protocol implementation
- **Dependencies**: Firebase Messaging only (v12.0.0), MapKit, CryptoKit
- **Backend**: https://backend-production-cfbe.up.railway.app
- **Security Framework**: Custom SecurityManager with AES-GCM encryption

## Project Structure
```
Derrite/
├── DerriteApp.swift          # App entry point
├── ContentView.swift         # Main map interface
├── Core/
│   └── BackendClient.swift   # Secure API client with rate limiting
├── Models/
│   ├── Report.swift          # Report data model with auto-sanitization
│   └── Favorite.swift        # Favorite places model
├── Views/
│   ├── MapView.swift         # MapKit integration
│   └── ReportInputView.swift # Report creation with PII filtering
├── Managers/
│   ├── LocationManager.swift # Location services with privacy
│   ├── ReportManager.swift   # Report lifecycle management
│   ├── AlertManager.swift    # Proximity alert system
│   ├── FavoriteManager.swift # Favorite location monitoring
│   └── PreferencesManager.swift # App settings
├── Utils/
│   ├── SecurityManager.swift # Core security utilities
│   └── SecureStorage.swift   # Keychain-based encrypted storage
└── Assets.xcassets/          # App resources
```

## Security Features (CRITICAL)
**This app is designed for maximum anonymity and security:**

1. **Anonymous ID Generation**: All reports use cryptographically random UUIDs with no device correlation
2. **Location Privacy**: Coordinates are automatically fuzzed within ~100m radius
3. **Data Sanitization**: All text input is automatically scanned and sanitized to remove:
   - Phone numbers (all formats)
   - Email addresses
   - Social Security Numbers
   - Credit card numbers
   - Other PII patterns
4. **Image Security**: Photos are stripped of ALL EXIF metadata and GPS data
5. **Network Security**: 
   - Ephemeral URLSession with no caching
   - No cookies or tracking headers
   - Rate limiting with queue management
   - Secure request headers
6. **Local Storage**: All data encrypted with AES-GCM before keychain storage
7. **Anti-Tampering**: Jailbreak detection with app lockdown
8. **No Telemetry**: Zero analytics, tracking, or usage data collection

## Core Features
1. **Anonymous Safety Reporting**: Create location-based safety pins with optional photos
2. **Real-time Alerts**: Get notified of safety reports within 1-mile radius
3. **Favorite Monitoring**: Set favorite locations and receive alerts for activity nearby  
4. **Bilingual Support**: English/Spanish with dynamic language switching
5. **Map Integration**: MapKit with satellite view and report visualization
6. **Auto-Expiration**: All reports expire after 8 hours automatically

## Development Rules
1. **NO TRACKING**: Never add analytics, crash reporting, or telemetry
2. **NO PII**: All user input must be sanitized through SecurityManager
3. **ENCRYPTION FIRST**: All persistent data must use SecureStorage
4. **SECURE BY DEFAULT**: All network requests use SecurityManager.createSecureRequest()
5. **MINIMIZE DATA**: Store only essential data, delete everything else immediately
6. **AUDIT TRAILS**: No logs should contain sensitive information

## Testing Security
Before any deployment, verify:
- [ ] No PII in any stored data
- [ ] No metadata in photos  
- [ ] Location fuzzing is working
- [ ] Encrypted storage is functioning
- [ ] Jailbreak detection is active
- [ ] Network requests have no tracking headers

## Key Dependencies
- Firebase iOS SDK 12.0.0 (Messaging only - Analytics removed for privacy)
- MapKit (Apple's mapping framework)
- CryptoKit (for AES-GCM encryption)
- Security framework (for keychain storage)

## Backend Integration
- **Server**: Railway-hosted Node.js backend
- **Database**: Anonymous report storage with automatic expiration
- **Rate Limiting**: 10 requests per minute per IP
- **Geographic Zones**: Reports organized by lat/lng zones for efficiency
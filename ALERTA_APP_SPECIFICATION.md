# Alerta - Complete App Specification for Android Development

## Table of Contents
1. [App Overview](#app-overview)
2. [Core Security Architecture](#core-security-architecture)
3. [User Interface & Experience](#user-interface--experience)
4. [Feature Implementation Order](#feature-implementation-order)
5. [Data Models](#data-models)
6. [API Integration](#api-integration)
7. [Settings & Preferences](#settings--preferences)
8. [Localization](#localization)
9. [Testing Requirements](#testing-requirements)
10. [App Store Requirements](#app-store-requirements)

---

## App Overview

**App Name**: Alerta  
**Purpose**: Anonymous safety reporting with maximum privacy and security  
**Platform**: iOS (existing), Android (target)  
**Backend**: https://backend-production-cfbe.up.railway.app  
**Languages**: English/Spanish bilingual support  

### Core Concept
Users can anonymously report safety issues by long-pressing on a map. Reports expire after 8 hours. Users receive real-time notifications for nearby safety reports within their configured distance.

---

## Core Security Architecture

### 1. Anonymity & Privacy (CRITICAL - Implement First)

#### Anonymous ID System
- Generate cryptographically random UUIDs for each report
- No correlation between reports and users/devices
- No device fingerprinting or tracking

#### Location Privacy
```
User Location: Automatically fuzzed within ~100m radius for distance calculations
Report Location: Stored exactly as placed for accuracy
Favorite Locations: Stored locally only, never transmitted
```

#### PII Sanitization (Required for all text input)
Automatically detect and remove:
- Phone numbers (all international formats)
- Email addresses
- Social Security Numbers
- Credit card numbers
- Personal names (basic detection)
- Addresses with specific details

#### Photo Security
- Strip ALL EXIF metadata
- Remove GPS coordinates
- Remove camera model/settings
- Remove timestamps
- Fix image orientation before processing

#### Data Encryption
- All local storage must use AES-GCM encryption
- Keychain/Keystore integration for key management
- No plaintext storage of any user data

### 2. Network Security

#### Secure Requests
- Ephemeral sessions (no caching)
- No cookies or tracking headers
- Rate limiting: 10 requests per minute
- Request queue management
- Timeout handling

#### Anti-Tampering
- Root/jailbreak detection
- App integrity verification
- Secure storage validation

---

## User Interface & Experience

### 1. Main Interface Components

#### Map View (Primary Screen)
- MapKit (iOS) / Google Maps (Android)
- Satellite view default
- Location marker for user (fuzzed)
- Safety report pins (color-coded)
- Long-press gesture detection

#### Navigation Structure
```
Bottom Tab Bar:
├── Map (Home) - MapKit/Google Maps with safety pins
├── Alerts - List of nearby safety reports
├── Favorites - User's saved locations
└── Settings - App configuration
```

#### Color Scheme
- Primary: System blue (#007AFF)
- Safety pins: Red/orange for active reports
- Background: System background (supports dark mode)
- Text: System text colors

### 2. Core User Flows

#### Creating a Report
1. Long press on map → Context menu appears
2. Select "Report Safety Issue"
3. Add description (with PII filtering)
4. Optionally add photo (with EXIF stripping)
5. Submit → Success notification

#### Receiving Alerts
1. Background location monitoring
2. Check for reports within configured distance
3. Local notification with sound/vibration
4. Tap notification → View report details

#### Managing Favorites
1. Long press on map → "Add to Favorites"
2. Enter generic name (e.g., "Place A")
3. Stored locally with encryption
4. Monitor for nearby reports

---

## Feature Implementation Order

### Phase 1: Core Security Foundation
1. **Security Manager** - PII detection, encryption, photo sanitization
2. **Secure Storage** - AES-GCM encrypted local storage
3. **Anonymous ID Generation** - Cryptographic UUID system
4. **Root/Jailbreak Detection** - Device integrity checks

### Phase 2: Basic Functionality
1. **Location Services** - Permission handling, fuzzing
2. **Map Integration** - Basic map with user location
3. **Backend Client** - Secure API communication
4. **Report Model** - Data structure with auto-sanitization

### Phase 3: Core Features
1. **Report Creation** - Long press gesture, input forms
2. **Report Display** - Pin visualization on map
3. **Basic Notifications** - Local alert system
4. **Report Expiration** - 8-hour auto-cleanup

### Phase 4: Advanced Features
1. **Favorites System** - Location bookmarking
2. **Alert Filtering** - Distance-based notifications
3. **Real-time Updates** - Background sync
4. **Translation** - Basic Google Translate integration

### Phase 5: User Experience
1. **Settings Interface** - Complete preferences
2. **Onboarding** - First-run tutorial
3. **Accessibility** - VoiceOver/TalkBack support
4. **Dark Mode** - Theme switching

### Phase 6: Localization & Polish
1. **Spanish Translation** - Complete bilingual support
2. **App Lock** - PIN/Biometric security
3. **Sound/Vibration** - Notification customization
4. **Performance Optimization** - Memory, battery

---

## Data Models

### Report Model
```json
{
  "id": "uuid-v4-random",
  "latitude": "number (exact as placed)",
  "longitude": "number (exact as placed)", 
  "description": "string (PII sanitized)",
  "photoUrl": "string (optional, EXIF stripped)",
  "timestamp": "ISO 8601 date",
  "expiresAt": "ISO 8601 date (timestamp + 8 hours)",
  "isActive": "boolean"
}
```

### Favorite Model (Local Storage Only)
```json
{
  "id": "uuid-v4",
  "name": "string (user provided)",
  "latitude": "number",
  "longitude": "number",
  "createdAt": "ISO 8601 date"
}
```

### User Preferences Model
```json
{
  "language": "en|es",
  "enableSoundAlerts": "boolean",
  "enableVibration": "boolean", 
  "alertDistanceMiles": "number (default: 1.0)",
  "isDarkMode": "boolean",
  "appLockType": "none|biometric|pin",
  "appLockTimeout": "number (minutes)"
}
```

---

## API Integration

### Backend Endpoints

#### Get Reports (GET /reports)
```
Query Parameters:
- lat: number (user latitude, fuzzed)
- lng: number (user longitude, fuzzed)
- radius: number (miles, default 1.0)

Response: Array of Report objects
Rate Limit: 10 requests/minute
```

#### Create Report (POST /reports)
```
Body: Report object (without id, timestamps)
Headers: No tracking headers
Response: Created report with server-generated fields
Rate Limit: 10 requests/minute
```

#### Upload Photo (POST /photos)
```
Body: FormData with sanitized image
Headers: Content-Type multipart/form-data
Response: { photoUrl: string }
Rate Limit: 5 uploads/minute
```

### Request Security Requirements
- Use ephemeral sessions
- No persistent cookies
- No user-agent tracking
- Implement request queuing
- Handle network failures gracefully

---

## Settings & Preferences

### Alert Settings
- **Sound Alerts**: Enable/disable notification sounds
- **Vibration**: Enable/disable haptic feedback
- **Notification Distance**: 0.25 to 5.0 miles
- **Emergency Mode**: Bypass silent mode (with warning)

### Privacy & Security
- **App Lock**: None/Biometric/PIN options
- **Auto-Lock Timeout**: Immediate to 15 minutes
- **Privacy Info**: Educational screen about protections
- **Clear All Data**: Emergency wipe function

### Appearance
- **Language**: English/Spanish toggle
- **Dark Mode**: System/Light/Dark options
- **Map Type**: Standard/Satellite toggle

### About Section
- **App Version**: Display current version
- **How to Use**: Tutorial/help screens
- **Privacy Policy**: Built-in privacy explanation
- **Support Contact**: Help email

---

## Localization

### Required Language Support
- **English** (primary)
- **Spanish** (secondary)

### Key Translation Categories

#### Core Actions
```
"create_report" → "Report Safety Issue" / "Reportar problema de seguridad"
"add_to_favorites" → "Add to Favorites" / "Agregar a Favoritos"
"cancel" → "Cancel" / "Cancelar"
"submit" → "Submit" / "Enviar"
```

#### Navigation
```
"safety" → "Safety" / "Seguridad"
"alerts" → "Alerts" / "Alertas"
"favorites" → "Favorites" / "Favoritos"
"settings" → "Settings" / "Configuración"
```

#### Notifications
```
"safety_issue_in_area" → "Safety issue in your area" / "Problema de seguridad en tu área"
"safety_issue_near_favorite" → "Safety issue near favorite location" / "Problema de seguridad cerca de ubicación favorita"
```

#### Privacy/Security
```
"coordinates_automatically_fuzzed" → "User location is automatically fuzzed" / "La ubicación del usuario se difumina automáticamente"
"exif_data_automatically_removed" → "EXIF data automatically removed" / "Los datos EXIF se eliminan automáticamente"
```

### Implementation Notes
- Use platform-standard localization (NSLocalizedString / Android strings.xml)
- Support dynamic language switching without app restart
- Test all UI layouts in both languages
- Ensure date/time formatting follows locale conventions

---

## Testing Requirements

### Security Testing (Critical)
- [ ] Verify no PII in stored data
- [ ] Confirm EXIF metadata removal from photos
- [ ] Test location fuzzing accuracy
- [ ] Validate encryption/decryption cycles
- [ ] Verify jailbreak/root detection
- [ ] Test network request headers (no tracking)

### Functionality Testing
- [ ] Report creation and submission
- [ ] Real-time alert notifications
- [ ] Favorite location monitoring
- [ ] Map interaction (long press, pin display)
- [ ] Language switching
- [ ] Dark mode support
- [ ] App lock functionality

### Performance Testing
- [ ] Battery usage during background monitoring
- [ ] Memory usage with large number of reports
- [ ] Network efficiency and rate limiting
- [ ] App startup time
- [ ] Map rendering performance

---

## App Store Requirements

### iOS App Store (Current)
- **App Name**: Alerta
- **Subtitle**: Anonymous Safety Reporting
- **Bundle ID**: com.derrite.Alerta
- **Version**: 1.1 (Build 2)
- **Minimum iOS**: 15.0
- **Encryption**: ITSAppUsesNonExemptEncryption = false

### Google Play Store (Target)
- **Package Name**: com.alerta.safety (suggested)
- **Target SDK**: Android 14 (API 34)
- **Minimum SDK**: Android 7.0 (API 24)
- **Permissions**: Location, Camera, Storage, Notifications

### Required Permissions Justification

#### iOS (NSUsageDescription)
- **Location**: "Show nearby safety reports and alerts"
- **Camera**: "Take photos for safety reports"  
- **Photo Library**: "Attach photos to safety reports"
- **Face ID**: "Securely protect your safety reports"

#### Android (Manifest Permissions)
- **ACCESS_FINE_LOCATION**: Proximity alert calculations
- **ACCESS_COARSE_LOCATION**: General area monitoring
- **CAMERA**: Safety report photo capture
- **READ_EXTERNAL_STORAGE**: Photo attachment selection
- **VIBRATE**: Alert notifications
- **USE_BIOMETRIC**: App lock security

### Privacy Policy Requirements
Both stores require privacy policy covering:
- Anonymous data collection
- Location data handling
- Photo processing and storage
- No third-party tracking
- Local data encryption
- User rights and data deletion

### Screenshots Requirements
- **iPhone**: 6.7" (1290×2796), 6.5" (1242×2688)
- **iPad**: 12.9" (2064×2752), Pro 12.9" (2048×2732)
- **Android**: Phone (1080×1920), Tablet (1600×2560)

---

## Implementation Priority Summary

1. **Start Here**: Security framework (PII filtering, encryption, anonymity)
2. **Core Foundation**: Location services, map integration, basic reporting
3. **Essential Features**: Notifications, favorites, real-time updates
4. **User Experience**: Settings, onboarding, accessibility
5. **Localization**: Spanish translation, cultural considerations
6. **Polish**: App lock, sound/vibration, performance optimization

This specification provides everything needed to recreate Alerta on Android while maintaining the same security standards and user experience as the iOS version.
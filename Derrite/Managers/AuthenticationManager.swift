//  AuthenticationManager.swift
//  Derrite

import Foundation
import LocalAuthentication
import CryptoKit

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    @Published var isAppLocked = false
    @Published var authenticationRequired = false
    
    private var justUnlocked = false
    private var unlockTime: Date?
    private var isUsingCamera = false

    private let userDefaults = UserDefaults.standard
    private let secureStorage = SecureStorage.shared

    // Keys for UserDefaults
    private let authMethodKey = "app_authentication_method"
    private let lastUnlockTimeKey = "last_unlock_time"
    private let autoLockIntervalKey = "auto_lock_interval"

    // Keys for SecureStorage (Keychain)
    private let pinHashKey = "app_pin_hash"
    private let pinSaltKey = "app_pin_salt"

    // Authentication methods
    enum AuthenticationMethod: Int, CaseIterable {
        case none = 0
        case biometric = 1
        case pin = 2

        var displayName: String {
            switch self {
            case .none: return "None"
            case .biometric: return "Biometric"
            case .pin: return "PIN"
            }
        }

        func localizedDisplayName(using preferencesManager: PreferencesManager) -> String {
            let isSpanish = preferencesManager.currentLanguage == "es"

            switch self {
            case .none:
                return isSpanish ? "Ninguna" : "None"
            case .biometric:
                return isSpanish ? "Biométrico" : "Biometric"
            case .pin:
                return isSpanish ? "PIN" : "PIN"
            }
        }
    }

    // Auto-lock intervals (in seconds)
    enum AutoLockInterval: Int, CaseIterable {
        case immediate = 0
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case never = -1

        var displayName: String {
            switch self {
            case .immediate: return "Immediately"
            case .thirtySeconds: return "30 seconds"
            case .oneMinute: return "1 minute"
            case .fiveMinutes: return "5 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .never: return "Never"
            }
        }

        func localizedDisplayName(using preferencesManager: PreferencesManager) -> String {
            let isSpanish = preferencesManager.currentLanguage == "es"

            switch self {
            case .immediate:
                return isSpanish ? "Inmediatamente" : "Immediately"
            case .thirtySeconds:
                return isSpanish ? "30 segundos" : "30 seconds"
            case .oneMinute:
                return isSpanish ? "1 minuto" : "1 minute"
            case .fiveMinutes:
                return isSpanish ? "5 minutos" : "5 minutes"
            case .fifteenMinutes:
                return isSpanish ? "15 minutos" : "15 minutes"
            case .never:
                return isSpanish ? "Nunca" : "Never"
            }
        }
    }

    private init() {
        checkAuthenticationStatus()
    }

    // MARK: - Public Properties

    var authenticationMethod: AuthenticationMethod {
        get {
            AuthenticationMethod(rawValue: userDefaults.integer(forKey: authMethodKey)) ?? .none
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: authMethodKey)
        }
    }

    var isAuthenticationEnabled: Bool {
        return authenticationMethod != .none
    }

    var isBiometricsEnabled: Bool {
        return authenticationMethod == .biometric
    }

    var isPinEnabled: Bool {
        return authenticationMethod == .pin
    }
    
    var hasPinAvailable: Bool {
        return secureStorage.keyExists(for: pinHashKey) && secureStorage.keyExists(for: pinSaltKey)
    }

    var autoLockInterval: AutoLockInterval {
        get {
            AutoLockInterval(rawValue: userDefaults.integer(forKey: autoLockIntervalKey)) ?? .fiveMinutes
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: autoLockIntervalKey)
        }
    }

    // MARK: - Biometric Support

    func biometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometricTypeDisplayName: String {
        switch biometricType() {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometric"
        }
    }

    // MARK: - Authentication Setup

    func setAuthenticationMethod(_ method: AuthenticationMethod, completion: @escaping (Result<Void, AuthenticationError>) -> Void) {
        // Clear any existing authentication data completely - this is OK here since we're changing methods
        clearPINDataOnly()
        authenticationMethod = .none  // Explicitly clear the method when changing

        switch method {
        case .none:
            authenticationMethod = .none
            isAppLocked = false
            authenticationRequired = false
            completion(.success(()))

        case .biometric:
            if !isBiometricAuthenticationAvailable() {
                completion(.failure(.biometricsUnavailable))
                return
            }
            // Don't set the authentication method yet - wait for PIN setup
            // This will be handled in the settings view
            completion(.success(()))

        case .pin:
            // PIN will be set separately via setPIN()
            // Don't set authenticationMethod yet - wait until PIN is actually set
            // Don't call checkAuthenticationStatus() until PIN is configured
            completion(.success(()))
        }
    }
    
    private func clearAllPINData() {
        // Delete PIN data
        _ = secureStorage.delete(for: pinHashKey)
        _ = secureStorage.delete(for: pinSaltKey)
        
        // NOTE: Don't clear authMethodKey here - only clear it when completely disabling auth
        // This prevents race conditions during PIN updates
    }
    
    private func clearPINDataOnly() {
        // Only delete PIN data, keep authentication method intact during updates
        _ = secureStorage.delete(for: pinHashKey)
        _ = secureStorage.delete(for: pinSaltKey)
    }

    func disableAuthentication() {
        // Only when completely disabling auth, clear the authentication method
        clearPINDataOnly()
        authenticationMethod = .none
        isAppLocked = false
        authenticationRequired = false
    }
    
    

    // MARK: - Combined Authentication Setup
    
    func enableBiometricWithPinFallback(completion: @escaping (Result<Void, AuthenticationError>) -> Void) {
        guard isBiometricAuthenticationAvailable() else {
            completion(.failure(.biometricsUnavailable))
            return
        }
        
        guard hasPinAvailable else {
            completion(.failure(.noPinFallback))
            return
        }
        
        // Both biometric and PIN are available, enable biometric as primary
        authenticationMethod = .biometric
        checkAuthenticationStatus()
        completion(.success(()))
    }

    // MARK: - PIN Management

    func setPIN(_ pin: String, completion: @escaping (Result<Void, AuthenticationError>) -> Void) {
        
        // First, clear any existing PIN data but preserve authentication method
        clearPINDataOnly()
        
        guard pin.count >= 4 && pin.count <= 8 else {
            completion(.failure(.invalidPIN))
            return
        }

        // Generate random salt
        var saltBytes = [UInt8](repeating: 0, count: 32)
        let saltStatus = SecRandomCopyBytes(kSecRandomDefault, saltBytes.count, &saltBytes)
        guard saltStatus == errSecSuccess else {
            completion(.failure(.cryptographicFailure))
            return
        }

        let salt = Data(saltBytes)

        // Hash PIN with salt using PBKDF2
        guard let pinData = pin.data(using: .utf8) else {
            completion(.failure(.invalidPIN))
            return
        }

        let iterations = 100_000 // PBKDF2 iterations
        let keyLength = 32 // 256 bits

        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        let status = pinData.withUnsafeBytes { pinBytes in
            salt.withUnsafeBytes { saltBytes in
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pinBytes.bindMemory(to: Int8.self).baseAddress,
                    pinData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPBKDFAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derivedKey,
                    keyLength
                )
            }
        }

        guard status == kCCSuccess else {
            completion(.failure(.cryptographicFailure))
            return
        }

        let pinHash = Data(derivedKey)

        // Store in Keychain
        let hashSaved = secureStorage.save(pinHash, for: pinHashKey)
        let saltSaved = secureStorage.save(salt, for: pinSaltKey)
        
        if hashSaved && saltSaved {
            // Now that PIN is successfully stored, set the authentication method
            authenticationMethod = .pin
            checkAuthenticationStatus()
            completion(.success(()))
        } else {
            completion(.failure(.storageFailure))
        }
    }

    func verifyPIN(_ pin: String) -> Bool {
        // Validate PIN length
        guard pin.count >= 4 && pin.count <= 8 else { 
            return false 
        }
        
        guard let storedHash = secureStorage.load(for: pinHashKey),
              let salt = secureStorage.load(for: pinSaltKey),
              let pinData = pin.data(using: .utf8),
              !storedHash.isEmpty,
              !salt.isEmpty else {
            return false
        }
        
        let iterations = 100_000
        let keyLength = 32

        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        
        let status = pinData.withUnsafeBytes { pinBytes in
            salt.withUnsafeBytes { saltBytes in
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pinBytes.bindMemory(to: Int8.self).baseAddress,
                    pinData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPBKDFAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derivedKey,
                    keyLength
                )
            }
        }

        guard status == kCCSuccess else { 
            return false 
        }

        let computedHash = Data(derivedKey)
        
        // Use constant-time comparison to prevent timing attacks
        guard computedHash.count == storedHash.count else { 
            return false 
        }
        
        var result = 0
        for (byte1, byte2) in zip(computedHash, storedHash) {
            result |= Int(byte1 ^ byte2)
        }
        
        return result == 0
    }

    // MARK: - Authentication Flow

    func authenticateWithBiometrics(completion: @escaping (Result<Void, AuthenticationError>) -> Void) {
        guard isBiometricAuthenticationAvailable() else {
            completion(.failure(.biometricsUnavailable))
            return
        }


        let context = LAContext()
        let reason = PreferencesManager.shared.currentLanguage == "es" ?
            "Accede a tus reportes de seguridad" :
            "Access your safety reports"

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                              localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.unlockApp()
                    completion(.success(()))
                } else {
                    if let laError = error as? LAError {
                        completion(.failure(.biometricAuthenticationFailed(laError.localizedDescription)))
                    } else {
                        completion(.failure(.biometricAuthenticationFailed("Unknown error")))
                    }
                }
            }
        }
    }

    func authenticateWithPIN(_ pin: String, completion: @escaping (Result<Void, AuthenticationError>) -> Void) {
        // First check if PIN is actually set up
        guard hasPinAvailable else {
            completion(.failure(.noPinFallback))
            return
        }
        
        // Verify the PIN
        if verifyPIN(pin) {
            unlockApp()
            completion(.success(()))
        } else {
            completion(.failure(.incorrectPIN))
        }
    }

    func unlockApp() {
        DispatchQueue.main.async {
            self.isAppLocked = false
            self.authenticationRequired = false
            let now = Date()
            self.userDefaults.set(now.timeIntervalSince1970, forKey: self.lastUnlockTimeKey)
            
            // Set grace period to prevent immediate re-locking
            self.justUnlocked = true
            self.unlockTime = now
            
            // Clear the grace period after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.justUnlocked = false
            }
        }
    }

    func lockApp() {
        DispatchQueue.main.async {
            if self.isAuthenticationEnabled {
                self.isAppLocked = true
                self.authenticationRequired = true
            }
        }
    }

    // MARK: - Auto-lock Management

    func checkAuthenticationStatus() {
        guard isAuthenticationEnabled else {
            DispatchQueue.main.async {
                self.isAppLocked = false
                self.authenticationRequired = false
            }
            return
        }
        
        // Don't lock while camera is being used
        if isUsingCamera {
            return
        }

        let interval = autoLockInterval
        guard interval != .never else {
            // Never auto-lock, but app might still be locked manually
            return
        }

        // For immediate locking, always lock when checking status
        // (this gets called when app returns from background)
        // BUT: Don't lock immediately if we just unlocked within the grace period
        if interval == .immediate {
            if justUnlocked {
                return
            }
            lockApp()
            return
        }

        // For timed intervals, check elapsed time
        let lastUnlockTime = userDefaults.double(forKey: lastUnlockTimeKey)
        let currentTime = Date().timeIntervalSince1970
        let timeSinceUnlock = currentTime - lastUnlockTime

        if timeSinceUnlock > Double(interval.rawValue) {
            lockApp()
        }
    }

    func startAutoLockTimer() {
        // This should be called when app becomes active
        checkAuthenticationStatus()
    }

    func resetAutoLockTimer() {
        // This should be called on user interaction
        if !isAppLocked {
            userDefaults.set(Date().timeIntervalSince1970, forKey: lastUnlockTimeKey)
        }
    }
    
    // MARK: - Camera Usage Tracking
    
    func setCameraInUse(_ inUse: Bool) {
        isUsingCamera = inUse
    }
}

// MARK: - Error Types

enum AuthenticationError: LocalizedError {
    case biometricsUnavailable
    case biometricAuthenticationFailed(String)
    case invalidPIN
    case incorrectPIN
    case cryptographicFailure
    case storageFailure
    case noPinFallback

    var errorDescription: String? {
        switch self {
        case .biometricsUnavailable:
            return "Biometric authentication is not available on this device"
        case .biometricAuthenticationFailed(let message):
            return "Biometric authentication failed: \(message)"
        case .invalidPIN:
            return "PIN must be 4-8 digits"
        case .incorrectPIN:
            return "Incorrect PIN"
        case .cryptographicFailure:
            return "Failed to generate secure PIN hash"
        case .storageFailure:
            return "Failed to store authentication data"
        case .noPinFallback:
            return "PIN fallback is required for Face ID authentication"
        }
    }
}

// MARK: - CommonCrypto Import
import CommonCrypto
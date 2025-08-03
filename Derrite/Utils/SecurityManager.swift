//  SecurityManager.swift
//  Derrite

import Foundation
import UIKit
import CryptoKit
import LocalAuthentication
import CoreLocation

class SecurityManager {
    static let shared = SecurityManager()

    private init() {
        // Private initializer to ensure singleton
    }

    // MARK: - Anonymous ID Generation
    func generateAnonymousReportId() -> String {
        // Generate a truly random UUID with no device correlation
        return UUID().uuidString
    }

    // MARK: - Data Sanitization
    func sanitizeTextInput(_ text: String) -> String {
        // Remove any potential PII patterns
        var sanitized = text

        // Remove phone numbers (various formats)
        let phonePatterns = [
            #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#,
            #"\b\d{10}\b"#,
            #"\+\d{1,3}\s?\d{1,14}"#
        ]

        for pattern in phonePatterns {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "[REDACTED]",
                options: .regularExpression
            )
        }

        // Remove email addresses
        let emailPattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
        sanitized = sanitized.replacingOccurrences(
            of: emailPattern,
            with: "[REDACTED]",
            options: .regularExpression
        )

        // Remove SSN patterns
        let ssnPattern = #"\b\d{3}-\d{2}-\d{4}\b"#
        sanitized = sanitized.replacingOccurrences(
            of: ssnPattern,
            with: "[REDACTED]",
            options: .regularExpression
        )

        // Remove credit card patterns
        let ccPattern = #"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"#
        sanitized = sanitized.replacingOccurrences(
            of: ccPattern,
            with: "[REDACTED]",
            options: .regularExpression
        )

        return sanitized
    }

    // MARK: - Image Processing
    func sanitizeImage(_ image: UIImage) -> UIImage? {
        // Fix orientation first by drawing the image in the correct orientation
        let orientationFixedImage = fixImageOrientation(image)
        
        // Remove EXIF data and metadata by creating a new image
        guard let imageData = orientationFixedImage.jpegData(compressionQuality: 0.8) else { return nil }
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        
        // Create new image without metadata, keeping orientation as 1 since we already fixed it
        let options: [String: Any] = [
            kCGImageSourceShouldCache as String: false,
            kCGImagePropertyOrientation as String: 1
        ]
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else { return nil }
        
        // Create clean image with no metadata
        let cleanImage = UIImage(cgImage: cgImage)
        
        // Further compress to remove any hidden data
        guard let finalData = cleanImage.jpegData(compressionQuality: 0.7) else { return nil }
        return UIImage(data: finalData)
    }
    
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        // If the image is already in the correct orientation, return it as-is
        if image.imageOrientation == .up {
            return image
        }
        
        // Create a graphics context and draw the image with correct orientation
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        guard let orientationFixedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image // Return original if fixing fails
        }
        
        return orientationFixedImage
    }

    // MARK: - Location Privacy
    func fuzzyLocation(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // Add random noise to location (within ~100 meters)
        let latOffset = Double.random(in: -0.001...0.001)
        let lonOffset = Double.random(in: -0.001...0.001)

        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + latOffset,
            longitude: coordinate.longitude + lonOffset
        )
    }

    // MARK: - Network Security
    func createSecureRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)

        // Add security headers
        request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("0", forHTTPHeaderField: "Expires")

        // Prevent tracking
        request.setValue("1", forHTTPHeaderField: "DNT") // Do Not Track
        request.setValue("?1", forHTTPHeaderField: "Sec-GPC") // Global Privacy Control

        // Remove identifying headers
        request.setValue(nil, forHTTPHeaderField: "User-Agent")
        request.setValue(nil, forHTTPHeaderField: "Accept-Language")

        return request
    }

    // MARK: - Data Encryption (for local storage)
    func encryptData(_ data: Data, key: String) -> Data? {
        guard let keyData = key.data(using: .utf8) else { return nil }
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: keyData))

        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return sealedBox.combined
        } catch {
            return nil
        }
    }

    func decryptData(_ encryptedData: Data, key: String) -> Data? {
        guard let keyData = key.data(using: .utf8) else { return nil }
        let symmetricKey = SymmetricKey(data: SHA256.hash(data: keyData))

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            return nil
        }
    }

    // MARK: - App Security
    func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for jailbreak indicators
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/usr/bin/ssh"
        ]

        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if we can write to system directories
        let testString = "test"
        do {
            try testString.write(toFile: "/private/test.txt", atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: "/private/test.txt")
            return true
        } catch {
            // Expected behavior on non-jailbroken devices
        }

        return false
        #endif
    }

    // MARK: - Clear Sensitive Data
    func clearAllSensitiveData() {
        // Clear keychain
        let secItemClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]

        for itemClass in secItemClasses {
            let spec: NSDictionary = [kSecClass: itemClass]
            SecItemDelete(spec)
        }

        // Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }

        // Clear caches
        URLCache.shared.removeAllCachedResponses()

        // Clear cookies
        HTTPCookieStorage.shared.cookies?.forEach { cookie in
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    // MARK: - Prevent Screenshots
    func preventScreenshots(in window: UIWindow?) {
        #if !DEBUG
        // Add a secure text field to prevent screenshots
        let secureField = UITextField()
        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false
        window?.addSubview(secureField)
        window?.layer.superlayer?.addSublayer(secureField.layer)
        secureField.layer.sublayers?.first?.addSublayer(window?.layer ?? CALayer())
        #endif
    }
}
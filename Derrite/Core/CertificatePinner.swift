//  CertificatePinner.swift
//  Derrite

import Foundation
import Security
import CryptoKit

class CertificatePinner: NSObject {
    static let shared = CertificatePinner()

    // MARK: - Configuration
    private var pinnedPublicKeyHashes: [String: Set<String>] = [
        // Railway.app backend - these hashes need to be updated with actual values
        "backend-production-cfbe.up.railway.app": [
            "sha256/hRXsZfq1XKirdAifqUuVeb9MX3GJ4wxgu0R2scDbXB0=", // Certificate hash 1
            "sha256/xc9GpOr0w8B6bJXELbBeki8m47kJwYOItxBghukBkLM=", // Certificate hash 2
            "sha256/9Fk6HgfMnM7/vtnBHcUhg1b3gU2bIpSd50XmKZkMbGA="  // Certificate hash 3 - add the third hash from your extraction
        ]
    ]

    // Feature flag to enable/disable pinning (can be controlled remotely)
    private var isPinningEnabled = true

    // Monitoring and fallback settings
    private let enableFallbackMode = true // Allow fallback to normal SSL validation
    private let maxPinningFailures = 3    // Max failures before temporary disable
    private var pinningFailureCount = 0

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Validates if certificate pinning should be enforced for the given host
    func shouldEnforcePinning(for host: String) -> Bool {
        guard isPinningEnabled else { return false }
        guard pinningFailureCount < maxPinningFailures else { return false }
        return pinnedPublicKeyHashes.keys.contains(host)
    }

    /// Main certificate validation method
    func validateCertificate(challenge: URLAuthenticationChallenge) -> URLSession.AuthChallengeDisposition {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logSecurityEvent("No server trust available", level: .error)
            return .cancelAuthenticationChallenge
        }

        let host = challenge.protectionSpace.host

        // Check if we should enforce pinning for this host
        guard shouldEnforcePinning(for: host) else {
            // Fallback to default SSL validation
            logSecurityEvent("Certificate pinning disabled - using default validation for \(host)", level: .info)
            return .performDefaultHandling
        }

        // Get pinned hashes for this host
        guard let pinnedHashes = pinnedPublicKeyHashes[host] else {
            logSecurityEvent("No pinned certificates found for \(host)", level: .warning)
            return enableFallbackMode ? .performDefaultHandling : .cancelAuthenticationChallenge
        }

        // Extract public key hashes from server certificate chain
        let serverHashes = extractPublicKeyHashes(from: serverTrust)

        // Check if any server hash matches our pinned hashes
        let hasValidPin = !serverHashes.intersection(pinnedHashes).isEmpty

        if hasValidPin {
            logSecurityEvent("Certificate pinning validation successful for \(host)", level: .info)
            pinningFailureCount = 0 // Reset failure count on success
            return .useCredential
        } else {
            pinningFailureCount += 1
            logSecurityEvent("Certificate pinning validation failed for \(host). Failure count: \(pinningFailureCount)", level: .error)

            // In fallback mode, allow connection but log the security issue
            if enableFallbackMode {
                logSecurityEvent("Using fallback mode - allowing connection despite pinning failure", level: .warning)
                return .performDefaultHandling
            } else {
                return .cancelAuthenticationChallenge
            }
        }
    }

    // MARK: - Certificate Processing

    private func extractPublicKeyHashes(from serverTrust: SecTrust) -> Set<String> {
        var hashes = Set<String>()

        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else { continue }

            if let hash = extractPublicKeyHash(from: certificate) {
                hashes.insert(hash)
            }
        }

        return hashes
    }

    private func extractPublicKeyHash(from certificate: SecCertificate) -> String? {
        // Get public key from certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else { return nil }

        // Get public key data
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            if let error = error?.takeRetainedValue() {
                logSecurityEvent("Failed to extract public key: \(error)", level: .error)
            }
            return nil
        }

        // Calculate SHA256 hash of public key
        let data = Data(publicKeyData as NSData)
        let hash = SHA256.hash(data: data)

        // Convert to base64 string with proper formatting
        let hashData = Data(hash)
        return "sha256/" + hashData.base64EncodedString()
    }

    // MARK: - Monitoring and Logging

    private enum LogLevel {
        case info, warning, error
    }

    private func logSecurityEvent(_ message: String, level: LogLevel) {
        // In production, this would send to analytics/monitoring service
        // Analytics disabled for privacy - no logging in production
        // Temporarily disabled to test for duplicate key issue
        // sendSecurityAnalytics(event: "certificate_pinning", data: [
        //     "level": "\(level)",
        //     "host_hash": message.contains("backend-production") ? "railway_backend" : "unknown",
        //     "timestamp": Date().timeIntervalSince1970
        // ])
    }

    private func sendSecurityAnalytics(event: String, data: [String: Any]) {
        // This would integrate with your analytics service
        // For privacy, we only send non-identifying data
        // Implementation would depend on your analytics setup
    }

    // MARK: - Configuration Updates

    /// Update pinning configuration (for remote configuration)
    func updatePinningConfiguration(enabled: Bool, maxFailures: Int? = nil) {
        isPinningEnabled = enabled
        if let maxFailures = maxFailures {
            // Update max failures if provided
        }

        logSecurityEvent("Certificate pinning configuration updated: enabled=\(enabled)", level: .info)
    }

    /// Update pinned hashes for a host (for certificate rotation)
    func updatePinnedHashes(for host: String, hashes: [String]) {
        pinnedPublicKeyHashes[host] = Set(hashes)
        logSecurityEvent("Updated pinned hashes for \(host): \(hashes.count) hashes", level: .info)
    }

    /// Reset failure count (for recovery scenarios)
    func resetFailureCount() {
        pinningFailureCount = 0
        logSecurityEvent("Certificate pinning failure count reset", level: .info)
    }

    // MARK: - Certificate Hash Validation (for setup/testing)

    /// Validate that certificate hashes are properly formatted
    func validatePinnedHashes() -> Bool {
        for (host, hashes) in pinnedPublicKeyHashes {
            for hash in hashes {
                if !isValidCertificateHash(hash) {
                    logSecurityEvent("Invalid certificate hash format for \(host): \(hash)", level: .error)
                    return false
                }
            }
        }
        return true
    }

    private func isValidCertificateHash(_ hash: String) -> Bool {
        // Check format: sha256/[base64-encoded-hash]
        guard hash.hasPrefix("sha256/") else { return false }
        let base64Part = String(hash.dropFirst(7))
        guard base64Part.count == 44 else { return false } // SHA256 base64 is 44 chars
        guard Data(base64Encoded: base64Part) != nil else { return false }
        return true
    }
}

// MARK: - URLSessionDelegate Extension

extension CertificatePinner: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {

        let disposition = validateCertificate(challenge: challenge)

        switch disposition {
        case .useCredential:
            // Create credential from server trust
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)

        case .performDefaultHandling:
            completionHandler(.performDefaultHandling, nil)

        case .cancelAuthenticationChallenge:
            completionHandler(.cancelAuthenticationChallenge, nil)

        default:
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

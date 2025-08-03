//  CertificateHashExtractor.swift
//  Derrite

import Foundation
import Security
import CryptoKit

/// Utility class to extract certificate hashes for pinning setup
/// This is primarily used during development to get the correct hashes
class CertificateHashExtractor {

    /// Extract certificate hashes from a live connection
    /// This method should be called during development to get the correct hashes
    static func extractHashesFromURL(_ urlString: String, completion: @escaping ([String]) -> Void) {
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }

        // Create a temporary session without pinning to get the certificate
        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration, delegate: HashExtractionDelegate { hashes in
            completion(hashes)
        }, delegateQueue: nil)

        let task = session.dataTask(with: url) { _, _, _ in
            // We don't care about the response, only the certificate
        }

        task.resume()
    }

    /// Extract hash from certificate data (for manual certificate inspection)
    static func extractHashFromCertificateData(_ data: Data) -> String? {
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            return nil
        }

        return extractPublicKeyHash(from: certificate)
    }

    /// Extract public key hash from certificate
    static func extractPublicKeyHash(from certificate: SecCertificate) -> String? {
        // Get public key from certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else { return nil }

        // Get public key data
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            return nil
        }

        // Calculate SHA256 hash of public key
        let data = Data(publicKeyData as NSData)
        let hash = SHA256.hash(data: data)

        // Convert to base64 string with proper formatting
        let hashData = Data(hash)
        return "sha256/" + hashData.base64EncodedString()
    }

    /// Get certificate information for debugging
    static func getCertificateInfo(from certificate: SecCertificate) -> [String: Any] {
        var info: [String: Any] = [:]

        // Get certificate data
        let data = SecCertificateCopyData(certificate)
        info["data_length"] = CFDataGetLength(data)

        // Try to get subject summary
        if let subjectSummary = SecCertificateCopySubjectSummary(certificate) {
            info["subject"] = subjectSummary as String
        }

        // Get public key hash
        if let hash = extractPublicKeyHash(from: certificate) {
            info["public_key_hash"] = hash
        }

        return info
    }
}

// MARK: - Hash Extraction Delegate

private class HashExtractionDelegate: NSObject, URLSessionDelegate {
    private let completion: ([String]) -> Void

    init(completion: @escaping ([String]) -> Void) {
        self.completion = completion
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completion([])
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var hashes: [String] = []
        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else { continue }

            if let hash = CertificateHashExtractor.extractPublicKeyHash(from: certificate) {
                hashes.append(hash)
            }
        }

        completion(hashes)

        // Allow the connection to proceed for hash extraction
        completionHandler(.performDefaultHandling, nil)
    }
}


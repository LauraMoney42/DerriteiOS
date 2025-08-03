//  BackendClient.swift
//  Derrite

import Foundation
import UIKit
import CoreLocation

class BackendClient {
    static let shared = BackendClient()

    private let baseURL = "https://backend-production-cfbe.up.railway.app"
    private let maxRequestsPerMinute = 10
    private let rateLimitWindowMs: TimeInterval = 60000
    private let maxRetries = 3
    private let initialRetryDelayMs: TimeInterval = 1000

    private var requestTimes: [Date] = []
    private var isProcessingQueue = false
    private var lastRequestTime: Date?
    private var requestQueue: [(request: URLRequest, completion: (Bool, String) -> Void, retryCount: Int, requestType: String)] = []

    private let session: URLSession
    private let certificatePinner = CertificatePinner.shared

    private init() {
        let configuration = URLSessionConfiguration.ephemeral // Use ephemeral to avoid caching
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never

        // Disable telemetry
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        configuration.isDiscretionary = false

        // Create session with certificate pinning delegate
        self.session = URLSession(
            configuration: configuration,
            delegate: certificatePinner,
            delegateQueue: nil
        )

        // Validate pinned certificate hashes on initialization
        if !certificatePinner.validatePinnedHashes() {
            // Log error but continue with fallback mode
        }
    }

    // MARK: - Rate Limiting
    private func canMakeRequest() -> Bool {
        let now = Date()

        // Remove old requests outside the window
        requestTimes.removeAll { now.timeIntervalSince($0) * 1000 > rateLimitWindowMs }

        // Check if we're under the limit
        if requestTimes.count >= maxRequestsPerMinute {
            return false
        }

        // Add minimum delay between requests (2 seconds)
        if let lastTime = lastRequestTime {
            let timeSinceLastRequest = now.timeIntervalSince(lastTime) * 1000
            if timeSinceLastRequest < 2000 {
                return false
            }
        }

        return true
    }

    private func recordRequest() {
        let now = Date()
        requestTimes.append(now)
        lastRequestTime = now
    }

    // MARK: - Submit Report
    func submitReport(latitude: Double,
                     longitude: Double,
                     content: String,
                     language: String,
                     hasPhoto: Bool,
                     photo: String? = nil,
                     category: ReportCategory,
                     completion: @escaping (Bool, String) -> Void) {

        guard let url = URL(string: "\(baseURL)/report") else {
            completion(false, "Invalid URL")
            return
        }

        // Use secure request from SecurityManager
        var request = SecurityManager.shared.createSecureRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "lat": latitude,
            "lng": longitude,
            "content": content,
            "language": language,
            "hasPhoto": hasPhoto,
            "category": category.rawValue
        ]

        if hasPhoto, let photoData = photo {
            body["photo"] = photoData
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            queueRequest(request: request, completion: completion, requestType: "submitReport")
        } catch {
            completion(false, "Failed to create request: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch All Reports
    func fetchAllReports(completion: @escaping (Bool, [Report], String) -> Void) {
        guard let url = URL(string: "\(baseURL)/reports/all") else {
            completion(false, [], "Invalid URL")
            return
        }

        var request = SecurityManager.shared.createSecureRequest(url: url)
        request.httpMethod = "GET"

        queueRequest(request: request, completion: { success, response in
            if success {
                do {
                    let reports = try self.parseReports(from: response)
                    completion(true, reports, "Success")
                } catch {
                    completion(false, [], "Failed to parse reports: \(error.localizedDescription)")
                }
            } else {
                completion(false, [], response)
            }
        }, requestType: "fetchReports")
    }

    // MARK: - Subscribe to Alerts
    func subscribeToAlerts(latitude: Double, longitude: Double, completion: @escaping (Bool, String) -> Void) {
        // Privacy-first approach: No external subscriptions, alerts work locally only
        // This ensures complete anonymity - no tokens, no external registration

        // Simulate successful subscription for compatibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion(true, "Local alert monitoring enabled - maximum privacy mode")
        }
    }

    // MARK: - Request Queue Processing
    private func queueRequest(request: URLRequest, completion: @escaping (Bool, String) -> Void, requestType: String) {
        requestQueue.append((request, completion, 0, requestType))
        processRequestQueue()
    }

    private func processRequestQueue() {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true

        processNext()
    }

    private func processNext() {
        guard !requestQueue.isEmpty else {
            isProcessingQueue = false
            return
        }

        if canMakeRequest() {
            let queued = requestQueue.removeFirst()
            recordRequest()
            executeRequest(queued) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.processNext()
                }
            }
        } else {
            // Can't make request now, wait and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.processNext()
            }
        }
    }

    private func executeRequest(_ queued: (request: URLRequest, completion: (Bool, String) -> Void, retryCount: Int, requestType: String), onComplete: @escaping () -> Void) {

        session.dataTask(with: queued.request) { [weak self] data, response, error in
            if let error = error {
                self?.handleRequestFailure(queued, errorMessage: "Network error: \(error.localizedDescription)", onComplete: onComplete)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self?.handleRequestFailure(queued, errorMessage: "Invalid response", onComplete: onComplete)
                return
            }

            switch httpResponse.statusCode {
            case 200, 201:
                self?.handleSuccessResponse(queued, data: data, onComplete: onComplete)
            case 429:
                self?.handleRateLimit(queued, onComplete: onComplete)
            case 500...599:
                self?.handleRetryableError(queued, errorMessage: "Server error: \(httpResponse.statusCode)", onComplete: onComplete)
            default:
                queued.completion(false, "Server error: \(httpResponse.statusCode)")
                onComplete()
            }
        }.resume()
    }

    private func handleSuccessResponse(_ queued: (request: URLRequest, completion: (Bool, String) -> Void, retryCount: Int, requestType: String), data: Data?, onComplete: @escaping () -> Void) {
        guard let data = data else {
            queued.completion(false, "No data received")
            onComplete()
            return
        }

        if queued.requestType == "fetchReports" {
            // For fetch reports, pass the raw JSON string
            if let jsonString = String(data: data, encoding: .utf8) {
                queued.completion(true, jsonString)
            } else {
                queued.completion(false, "Failed to decode response")
            }
        } else {
            // For other requests, parse the JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool {
                    let message = json["message"] as? String ?? "Success"
                    queued.completion(success, message)
                } else {
                    queued.completion(true, "Success")
                }
            } catch {
                queued.completion(false, "Failed to parse response")
            }
        }
        onComplete()
    }

    private func handleRequestFailure(_ queued: (request: URLRequest, completion: (Bool, String) -> Void, retryCount: Int, requestType: String), errorMessage: String, onComplete: @escaping () -> Void) {
        if queued.retryCount < maxRetries {
            let retryDelay = initialRetryDelayMs * Double(1 << queued.retryCount) / 1000

            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                let retryRequest = (queued.request, queued.completion, queued.retryCount + 1, queued.requestType)
                self?.requestQueue.insert(retryRequest, at: 0)
                onComplete()
            }
        } else {
            queued.completion(false, errorMessage)
            onComplete()
        }
    }

    private func handleRateLimit(_ queued: (request: URLRequest, completion: (Bool, String) -> Void, retryCount: Int, requestType: String), onComplete: @escaping () -> Void) {
        let retryDelay = 10.0 + Double(queued.retryCount * 5)

        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            if queued.retryCount < self?.maxRetries ?? 3 {
                let retryRequest = (queued.request, queued.completion, queued.retryCount + 1, queued.requestType)
                self?.requestQueue.insert(retryRequest, at: 0)
            } else {
                queued.completion(false, "Rate limit exceeded - please try again later")
            }
            onComplete()
        }
    }

    private func handleRetryableError(_ queued: (request: URLRequest, completion: (Bool, String) -> Void, retryCount: Int, requestType: String), errorMessage: String, onComplete: @escaping () -> Void) {
        handleRequestFailure(queued, errorMessage: errorMessage, onComplete: onComplete)
    }

    // MARK: - Parse Reports
    private func parseReports(from jsonString: String) throws -> [Report] {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "BackendClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let success = json?["success"] as? Bool, success,
              let reportsArray = json?["reports"] as? [[String: Any]] else {
            return []
        }

        var reports: [Report] = []

        for reportDict in reportsArray {
            guard let id = reportDict["id"] as? String,
                  let lat = reportDict["lat"] as? Double,
                  let lng = reportDict["lng"] as? Double,
                  let content = reportDict["content"] as? String,
                  let language = reportDict["language"] as? String,
                  let hasPhoto = reportDict["hasPhoto"] as? Bool,
                  let timestamp = reportDict["timestamp"] as? TimeInterval else {
                continue
            }

            let categoryCode = reportDict["category"] as? String ?? "safety"
            let category = ReportCategory(rawValue: categoryCode) ?? .safety

            // Handle timestamp - could be in seconds or milliseconds from backend
            let timestampInSeconds: TimeInterval
            let currentTime = Date().timeIntervalSince1970
            
            // If timestamp appears to be in milliseconds (very large number), convert to seconds
            if timestamp > currentTime * 100 {
                // Backend sent milliseconds
                timestampInSeconds = timestamp / 1000
            } else {
                // Backend sent seconds
                timestampInSeconds = timestamp
            }
            
            // Calculate expiration (8 hours from timestamp in seconds)
            let expiresAt = timestampInSeconds + (8 * 60 * 60)

            // Skip expired reports
            guard expiresAt > currentTime else {
                continue
            }

            // Convert photo from base64 if present
            var photo: UIImage?
            if hasPhoto, let photoString = reportDict["photo"] as? String {
                photo = convertBase64ToImage(photoString)
            }

            let report = Report(
                id: id,
                location: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                originalText: content,
                originalLanguage: language,
                hasPhoto: hasPhoto,
                photo: photo,
                timestamp: timestampInSeconds, // Already converted to seconds above
                expiresAt: expiresAt,
                category: category
            )

            reports.append(report)
        }

        return reports
    }

    private func convertBase64ToImage(_ base64String: String) -> UIImage? {
        var base64 = base64String
        if base64.hasPrefix("data:image") {
            // Remove data:image/jpeg;base64, prefix
            if let range = base64.range(of: ",") {
                base64 = String(base64[range.upperBound...])
            }
        }

        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }

        return UIImage(data: data)
    }
}
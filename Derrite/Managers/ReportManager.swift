//  ReportManager.swift
//  Derrite

import Foundation
import CoreLocation
import UIKit

class ReportManager: ObservableObject {
    static let shared = ReportManager()

    @Published var activeReports: [Report] = []
    @Published var isLoading = false

    private let userDefaults = UserDefaults.standard
    private let reportsKey = "saved_reports"
    private let lastReportTimestampKey = "last_report_timestamp"
    private let userCreatedReportsKey = "user_created_reports"
    private let userCreatedSignaturesKey = "user_created_signatures"

    private var userCreatedReportIds: Set<String> = []
    private var userCreatedReportSignatures: Set<String> = []

    private init() {
        loadSavedReports()
        loadUserCreatedReports()
    }

    // MARK: - Public Methods
    func createReport(location: CLLocationCoordinate2D,
                     text: String,
                     detectedLanguage: String,
                     photo: UIImage?,
                     category: ReportCategory) -> Report {

        let timestamp = Date().timeIntervalSince1970
        let expiresAt = timestamp + (8 * 60 * 60) // 8 hours

        let report = Report(
            location: location,
            originalText: text,
            originalLanguage: detectedLanguage,
            hasPhoto: photo != nil,
            photo: photo,
            timestamp: timestamp,
            expiresAt: expiresAt,
            category: category
        )

        // Save last report timestamp for cooldown
        userDefaults.set(timestamp, forKey: lastReportTimestampKey)

        // Track that this user created this report (for preventing self-alerts)
        userCreatedReportIds.insert(report.id)

        // Also track by signature (content + timestamp + location) to handle backend ID changes
        let signature = createReportSignature(report)
        userCreatedReportSignatures.insert(signature)

        // Store the timestamp of when this user created a report for time-based filtering
        userDefaults.set(timestamp, forKey: "last_user_report_time")

        saveUserCreatedReports()

        // Add to active reports
        activeReports.append(report)
        saveReports()

        return report
    }

    func addReport(_ report: Report) {
        // Check if report already exists by ID
        if activeReports.contains(where: { $0.id == report.id }) {
            return
        }

        // Also check for near-duplicate reports (same content, similar time, similar location)
        let isDuplicate = activeReports.contains { existingReport in
            let timeDiff = abs(existingReport.timestamp - report.timestamp)
            let locationDiff = existingReport.location.distance(from: report.location)
            let sameContent = existingReport.originalText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == 
                             report.originalText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // More aggressive deduplication: same content within 10 minutes and 500 meters
            return sameContent && timeDiff < 600 && locationDiff < 500
        }

        if isDuplicate {
            return
        }

        activeReports.append(report)
        saveReports()
    }

    func getActiveReports() -> [Report] {
        return activeReports.filter { !$0.isExpired }
    }

    func cleanupExpiredReports() -> [Report] {
        let expiredReports = activeReports.filter { $0.isExpired }
        activeReports.removeAll { $0.isExpired }

        // Also clean up expired user-created report IDs and signatures
        let expiredIds = Set(expiredReports.map { $0.id })
        let expiredSignatures = Set(expiredReports.map { createReportSignature($0) })
        userCreatedReportIds = userCreatedReportIds.subtracting(expiredIds)
        userCreatedReportSignatures = userCreatedReportSignatures.subtracting(expiredSignatures)

        if !expiredReports.isEmpty {
            saveReports()
            saveUserCreatedReports()
        }

        return expiredReports
    }

    func loadLastReportTimestamp() -> TimeInterval? {
        return userDefaults.object(forKey: lastReportTimestampKey) as? TimeInterval
    }

    func isUserCreatedReport(_ reportId: String) -> Bool {
        return userCreatedReportIds.contains(reportId)
    }

    func isUserCreatedReport(_ report: Report) -> Bool {
        // Check by ID first
        if userCreatedReportIds.contains(report.id) {
            return true
        }

        // Check by signature to handle backend ID changes
        let signature = createReportSignature(report)
        if userCreatedReportSignatures.contains(signature) {
            return true
        }

        // Enhanced detection: Check if any user-created report signature has similar content and location
        // This handles cases where backend slightly modifies timestamps or text
        for userSignature in userCreatedReportSignatures {
            let userParts = userSignature.components(separatedBy: "|")
            let reportParts = signature.components(separatedBy: "|")

            if userParts.count >= 4 && reportParts.count >= 4 {
                let userText = userParts[0]
                let userLat = Double(userParts[2]) ?? 0
                let userLng = Double(userParts[3]) ?? 0
                let reportText = reportParts[0]
                let reportLat = Double(reportParts[2]) ?? 0
                let reportLng = Double(reportParts[3]) ?? 0

                // Check if text is similar (allowing for minor backend modifications)
                let textSimilar = userText == reportText ||
                                 userText.contains(reportText) ||
                                 reportText.contains(userText)

                // Check if location is very close (within ~100 meters accounting for fuzzing)
                let latDiff = abs(userLat - reportLat)
                let lngDiff = abs(userLng - reportLng)
                let locationClose = latDiff < 0.01 && lngDiff < 0.01 // ~100 meters to account for backend fuzzing
                
                if textSimilar && locationClose {
                    return true
                }
            }
        }

        // Time-based check: if this report was created recently after user created a report,
        // it's likely the user's own report coming back from the backend
        if let lastUserReportTime = userDefaults.object(forKey: "last_user_report_time") as? TimeInterval {
            let timeDiff = abs(report.timestamp - lastUserReportTime)
            if timeDiff < 60 { // Within 60 seconds (1 minute)
                return true
            }
        }
        
        return false
    }

    private func createReportSignature(_ report: Report) -> String {
        // Create a signature based on content, timestamp (rounded to nearest minute), and location (rounded)
        let roundedTimestamp = Int(report.timestamp / 60) * 60 // Round to nearest minute
        let roundedLat = round(report.location.latitude * 1000) / 1000 // Round to 3 decimal places
        let roundedLng = round(report.location.longitude * 1000) / 1000
        return "\(report.originalText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))|\(roundedTimestamp)|\(roundedLat)|\(roundedLng)"
    }

    // MARK: - Persistence
    func saveReports() {
        // Use secure storage instead of UserDefaults
        _ = SecureStorage.shared.saveSecureObject(activeReports, for: reportsKey)
    }

    func loadSavedReports() {
        // Load from secure storage
        if let savedReports = SecureStorage.shared.loadSecureObject([Report].self, for: reportsKey) {
            activeReports = savedReports

            // Clean up expired reports on load
            _ = cleanupExpiredReports()
        }
    }

    private func saveUserCreatedReports() {
        userDefaults.set(Array(userCreatedReportIds), forKey: userCreatedReportsKey)
        userDefaults.set(Array(userCreatedReportSignatures), forKey: userCreatedSignaturesKey)
    }

    private func loadUserCreatedReports() {
        if let reportIds = userDefaults.array(forKey: userCreatedReportsKey) as? [String] {
            userCreatedReportIds = Set(reportIds)
        }

        if let signatures = userDefaults.array(forKey: userCreatedSignaturesKey) as? [String] {
            userCreatedReportSignatures = Set(signatures)
        }
    }

    // MARK: - Network Operations
    func fetchAllReports(completion: @escaping (Bool, String) -> Void) {
        isLoading = true

        BackendClient.shared.fetchAllReports { [weak self] success, reports, message in
            DispatchQueue.main.async {
                self?.isLoading = false

                if success {
                    // Clear existing reports and replace with fresh data to prevent accumulation
                    self?.activeReports.removeAll()
                    
                    // Add new reports
                    for report in reports {
                        self?.addReport(report)
                    }
                    completion(true, "Loaded \(reports.count) reports")
                } else {
                    completion(false, message)
                }
            }
        }
    }

    func submitReport(_ report: Report, completion: @escaping (Bool, String) -> Void) {
        // Convert photo to base64 if present
        var photoBase64: String?
        if let photo = report.photo,
           let imageData = photo.jpegData(compressionQuality: 0.85) {
            photoBase64 = "data:image/jpeg;base64," + imageData.base64EncodedString()
        }

        BackendClient.shared.submitReport(
            latitude: report.location.latitude,
            longitude: report.location.longitude,
            content: report.originalText,
            language: report.originalLanguage,
            hasPhoto: report.hasPhoto,
            photo: photoBase64,
            category: report.category,
            completion: completion
        )
    }
}
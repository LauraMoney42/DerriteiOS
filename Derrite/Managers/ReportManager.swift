//
//  ReportManager.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

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
    
    private init() {
        loadSavedReports()
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
        
        // Add to active reports
        activeReports.append(report)
        saveReports()
        
        return report
    }
    
    func addReport(_ report: Report) {
        // Check if report already exists
        if !activeReports.contains(where: { $0.id == report.id }) {
            activeReports.append(report)
            saveReports()
        }
    }
    
    func getActiveReports() -> [Report] {
        return activeReports.filter { !$0.isExpired }
    }
    
    func cleanupExpiredReports() -> [Report] {
        let expiredReports = activeReports.filter { $0.isExpired }
        activeReports.removeAll { $0.isExpired }
        
        if !expiredReports.isEmpty {
            saveReports()
        }
        
        return expiredReports
    }
    
    func loadLastReportTimestamp() -> TimeInterval? {
        return userDefaults.object(forKey: lastReportTimestampKey) as? TimeInterval
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
    
    // MARK: - Network Operations
    func fetchAllReports(completion: @escaping (Bool, String) -> Void) {
        isLoading = true
        
        BackendClient.shared.fetchAllReports { [weak self] success, reports, message in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if success {
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
//  Report.swift
//  Derrite

import Foundation
import CoreLocation
import UIKit

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D {
    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let location2 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - Report Category
enum ReportCategory: String, CaseIterable, Codable {
    case safety = "safety"

    var displayName: String {
        return "Safety"
    }

    func getDisplayName(isSpanish: Bool) -> String {
        return isSpanish ? "Seguridad" : "Safety"
    }

    var icon: String {
        return "⚠️"
    }

    var colorName: String {
        return "categorySafety"
    }

    var fillColorName: String {
        return "categorySafetyFill"
    }

    var strokeColorName: String {
        return "categorySafetyStroke"
    }
}

// MARK: - Report Model
struct Report: Identifiable, Codable {
    let id: String
    let location: CLLocationCoordinate2D
    let originalText: String
    let originalLanguage: String
    let hasPhoto: Bool
    var photo: UIImage?
    let timestamp: TimeInterval
    let expiresAt: TimeInterval
    let category: ReportCategory

    // Custom coding to handle UIImage
    enum CodingKeys: String, CodingKey {
        case id, location, originalText, originalLanguage, hasPhoto, timestamp, expiresAt, category
        case photoData
    }

    init(id: String? = nil,
         location: CLLocationCoordinate2D,
         originalText: String,
         originalLanguage: String,
         hasPhoto: Bool,
         photo: UIImage? = nil,
         timestamp: TimeInterval = Date().timeIntervalSince1970,
         expiresAt: TimeInterval,
         category: ReportCategory = .safety) {
        // Use deterministic ID to prevent duplicates when syncing with backend
        if let providedId = id {
            self.id = providedId
        } else {
            // Create deterministic ID based on content hash to prevent duplicates
            let contentHash = "\(originalText)\(timestamp)\(location.latitude)\(location.longitude)".hash
            self.id = "report_\(abs(contentHash))"
        }

        // Use exact location for accurate safety reporting
        self.location = location

        // Sanitize text to remove any PII
        self.originalText = SecurityManager.shared.sanitizeTextInput(originalText)

        self.originalLanguage = originalLanguage
        self.hasPhoto = hasPhoto

        // Sanitize photo to remove EXIF data
        self.photo = photo != nil ? SecurityManager.shared.sanitizeImage(photo!) : nil

        self.timestamp = timestamp
        self.expiresAt = expiresAt
        self.category = category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        location = try container.decode(CLLocationCoordinate2D.self, forKey: .location)
        originalText = try container.decode(String.self, forKey: .originalText)
        originalLanguage = try container.decode(String.self, forKey: .originalLanguage)
        hasPhoto = try container.decode(Bool.self, forKey: .hasPhoto)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        expiresAt = try container.decode(TimeInterval.self, forKey: .expiresAt)
        category = try container.decode(ReportCategory.self, forKey: .category)

        if let photoData = try container.decodeIfPresent(Data.self, forKey: .photoData) {
            photo = UIImage(data: photoData)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(location, forKey: .location)
        try container.encode(originalText, forKey: .originalText)
        try container.encode(originalLanguage, forKey: .originalLanguage)
        try container.encode(hasPhoto, forKey: .hasPhoto)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(category, forKey: .category)

        if let photo = photo {
            try container.encode(photo.jpegData(compressionQuality: 0.8), forKey: .photoData)
        }
    }

    var isExpired: Bool {
        return Date().timeIntervalSince1970 > expiresAt
    }

    func timeAgo(preferencesManager: PreferencesManager = PreferencesManager.shared) -> String {
        let now = Date()
        let reportDate = Date(timeIntervalSince1970: timestamp)
        let interval = now.timeIntervalSince(reportDate)

        if interval < 60 {
            return preferencesManager.localizedString("just_now")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) " + preferencesManager.localizedString("min_ago")
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) " + preferencesManager.localizedString("hr_ago")
        } else {
            let days = Int(interval / 86400)
            return "\(days) " + preferencesManager.localizedString("day_ago")
        }
    }
}

// MARK: - Alert Model
struct Alert: Identifiable, Codable {
    let id: String
    let report: Report
    var distanceFromUser: Double
    var isViewed: Bool
    let timestamp: TimeInterval

    init(id: String = UUID().uuidString,
         report: Report,
         distanceFromUser: Double,
         isViewed: Bool = false,
         timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.report = report
        self.distanceFromUser = distanceFromUser
        self.isViewed = isViewed
        self.timestamp = timestamp
    }
}

// MARK: - CLLocationCoordinate2D Extension for Codable
extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}
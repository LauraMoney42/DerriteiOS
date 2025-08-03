//  InputValidator.swift
//  Derrite

import Foundation
import UIKit
import CoreLocation

enum ValidationError: Error, LocalizedError {
    case empty
    case tooShort(minimum: Int)
    case tooLong(maximum: Int)
    case invalidCharacters
    case containsPII
    case invalidImageSize
    case invalidImageFormat
    case invalidCoordinate
    case invalidDistance

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Input cannot be empty"
        case .tooShort(let minimum):
            return "Input must be at least \(minimum) characters"
        case .tooLong(let maximum):
            return "Input must not exceed \(maximum) characters"
        case .invalidCharacters:
            return "Input contains invalid characters"
        case .containsPII:
            return "Input contains potentially sensitive information"
        case .invalidImageSize:
            return "Image size exceeds maximum allowed"
        case .invalidImageFormat:
            return "Image format not supported"
        case .invalidCoordinate:
            return "Invalid location coordinates"
        case .invalidDistance:
            return "Invalid distance value"
        }
    }
}

class InputValidator {
    static let shared = InputValidator()

    // MARK: - Constants
    private let maxReportTextLength = 1000
    private let minReportTextLength = 3
    private let maxFavoriteNameLength = 50
    private let minFavoriteNameLength = 1
    private let maxFavoriteDescriptionLength = 200
    private let maxImageSizeBytes = 5 * 1024 * 1024 // 5MB
    private let allowedCharacterSet = CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces).union(.newlines)

    // Additional character sets for specific languages
    private let spanishCharacterSet = CharacterSet(charactersIn: "áéíóúüñÁÉÍÓÚÜÑ¿¡")
    private let commonSpecialCharacters = CharacterSet(charactersIn: ".,!?;:()\"-'")

    private init() {}

    // MARK: - Text Validation
    func validateReportText(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if empty
        guard !trimmed.isEmpty else {
            throw ValidationError.empty
        }

        // Check length limits
        guard trimmed.count >= minReportTextLength else {
            throw ValidationError.tooShort(minimum: minReportTextLength)
        }

        guard trimmed.count <= maxReportTextLength else {
            throw ValidationError.tooLong(maximum: maxReportTextLength)
        }

        // Check for valid characters
        try validateCharacterSet(trimmed)

        // Check for PII (this will sanitize rather than reject)
        let sanitized = SecurityManager.shared.sanitizeTextInput(trimmed)

        // If sanitization changed the text significantly, warn about PII
        if sanitized != trimmed && sanitized.contains("[REDACTED]") {
            throw ValidationError.containsPII
        }

        return sanitized
    }

    func validateFavoriteName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.empty
        }

        guard trimmed.count >= minFavoriteNameLength else {
            throw ValidationError.tooShort(minimum: minFavoriteNameLength)
        }

        guard trimmed.count <= maxFavoriteNameLength else {
            throw ValidationError.tooLong(maximum: maxFavoriteNameLength)
        }

        try validateCharacterSet(trimmed)

        return trimmed
    }

    func validateFavoriteDescription(_ description: String) throws -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Description can be empty
        if trimmed.isEmpty {
            return trimmed
        }

        guard trimmed.count <= maxFavoriteDescriptionLength else {
            throw ValidationError.tooLong(maximum: maxFavoriteDescriptionLength)
        }

        try validateCharacterSet(trimmed)

        return trimmed
    }

    // MARK: - Character Set Validation
    private func validateCharacterSet(_ text: String) throws {
        let combinedAllowedSet = allowedCharacterSet
            .union(spanishCharacterSet)
            .union(commonSpecialCharacters)

        let textCharacterSet = CharacterSet(charactersIn: text)

        guard combinedAllowedSet.isSuperset(of: textCharacterSet) else {
            throw ValidationError.invalidCharacters
        }
    }

    // MARK: - Image Validation
    func validateImage(_ image: UIImage) throws -> UIImage {
        // Check image format by trying to convert to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ValidationError.invalidImageFormat
        }

        // Check file size
        guard imageData.count <= maxImageSizeBytes else {
            throw ValidationError.invalidImageSize
        }

        // Sanitize image (remove EXIF data) - this is done in SecurityManager
        guard let sanitizedImage = SecurityManager.shared.sanitizeImage(image) else {
            throw ValidationError.invalidImageFormat
        }

        return sanitizedImage
    }

    // MARK: - Location Validation
    func validateCoordinate(_ coordinate: CLLocationCoordinate2D) throws -> CLLocationCoordinate2D {
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw ValidationError.invalidCoordinate
        }

        // Check for reasonable bounds (not exactly 0,0 which might be default)
        guard abs(coordinate.latitude) > 0.0001 || abs(coordinate.longitude) > 0.0001 else {
            throw ValidationError.invalidCoordinate
        }

        return coordinate
    }

    // MARK: - Distance Validation
    func validateDistance(_ distance: Double, minimum: Double = 0.1, maximum: Double = 50.0) throws -> Double {
        guard distance >= minimum && distance <= maximum else {
            throw ValidationError.invalidDistance
        }

        return distance
    }

    // MARK: - Search Query Validation
    func validateSearchQuery(_ query: String) throws -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.empty
        }

        guard trimmed.count <= 200 else {
            throw ValidationError.tooLong(maximum: 200)
        }

        try validateCharacterSet(trimmed)

        return trimmed
    }

    // MARK: - Safe Validation Methods (non-throwing)
    func safeValidateReportText(_ text: String) -> (isValid: Bool, sanitizedText: String?, error: String?) {
        do {
            let validated = try validateReportText(text)
            return (true, validated, nil)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    func safeValidateFavoriteName(_ name: String) -> (isValid: Bool, sanitizedName: String?, error: String?) {
        do {
            let validated = try validateFavoriteName(name)
            return (true, validated, nil)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    func safeValidateFavoriteDescription(_ description: String) -> (isValid: Bool, sanitizedDescription: String?, error: String?) {
        do {
            let validated = try validateFavoriteDescription(description)
            return (true, validated, nil)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    func safeValidateSearchQuery(_ query: String) -> (isValid: Bool, sanitizedText: String?, error: String?) {
        do {
            let validated = try validateSearchQuery(query)
            return (true, validated, nil)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    func safeValidateImage(_ image: UIImage) -> (isValid: Bool, sanitizedImage: UIImage?, error: String?) {
        do {
            let validated = try validateImage(image)
            return (true, validated, nil)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    // MARK: - Content Safety Checks
    func containsSuspiciousContent(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Check for potential spam patterns
        let spamPatterns = [
            "buy now", "click here", "free money", "get rich", "make money fast",
            "urgent", "act now", "limited time", "call now", "www.", "http"
        ]

        for pattern in spamPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }

        // Check for excessive repetition
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let uniqueWords = Set(words)

        // If less than 30% unique words, might be spam
        if words.count > 10 && Double(uniqueWords.count) / Double(words.count) < 0.3 {
            return true
        }

        return false
    }

    // MARK: - Validation Constants Access
    var maxReportLength: Int { maxReportTextLength }
    var maxFavoriteNameLen: Int { maxFavoriteNameLength }
    var maxFavoriteDescLen: Int { maxFavoriteDescriptionLength }
    var maxImageSize: Int { maxImageSizeBytes }
}
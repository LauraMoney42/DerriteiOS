//
//  Favorite.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import Foundation
import CoreLocation

// MARK: - Favorite Place Model
struct FavoritePlace: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let location: CLLocationCoordinate2D
    let alertDistance: Double // in meters
    let enableSafetyAlerts: Bool
    let createdAt: TimeInterval
    
    init(id: String = UUID().uuidString,
         name: String,
         description: String = "",
         location: CLLocationCoordinate2D,
         alertDistance: Double = 1609.0, // 1 mile default
         enableSafetyAlerts: Bool = true,
         createdAt: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.name = name
        self.description = description
        self.location = location
        self.alertDistance = alertDistance
        self.enableSafetyAlerts = enableSafetyAlerts
        self.createdAt = createdAt
    }
    
    func getAlertDistanceText(isSpanish: Bool) -> String {
        switch alertDistance {
        case 1609.0:
            return isSpanish ? "1 milla" : "1 mile"
        case 3218.0:
            return isSpanish ? "2 millas" : "2 miles"
        case 4827.0:
            return isSpanish ? "3 millas" : "3 miles"
        case 8047.0:
            return isSpanish ? "5 millas" : "5 miles"
        case 32187.0:
            return isSpanish ? "20 millas" : "20 miles"
        case 160934.0:
            return isSpanish ? "todo el estado" : "state-wide"
        default:
            return isSpanish ? "distancia personalizada" : "custom distance"
        }
    }
    
    func getEnabledAlertsText(isSpanish: Bool) -> String {
        return isSpanish ? "Seguridad" : "Safety"
    }
    
    func shouldReceiveAlert(category: ReportCategory) -> Bool {
        return category == .safety && enableSafetyAlerts
    }
}

// MARK: - Favorite Alert Model
struct FavoriteAlert: Identifiable, Codable {
    let id: String
    let favoritePlace: FavoritePlace
    let report: Report
    let distanceFromFavorite: Double
    let timestamp: TimeInterval
    var isViewed: Bool
    
    init(id: String = UUID().uuidString,
         favoritePlace: FavoritePlace,
         report: Report,
         distanceFromFavorite: Double,
         timestamp: TimeInterval = Date().timeIntervalSince1970,
         isViewed: Bool = false) {
        self.id = id
        self.favoritePlace = favoritePlace
        self.report = report
        self.distanceFromFavorite = distanceFromFavorite
        self.timestamp = timestamp
        self.isViewed = isViewed
    }
    
    func getAlertMessage(isSpanish: Bool) -> String {
        let distance = String(format: "%.1f", distanceFromFavorite / 1609.0)
        if isSpanish {
            return "Nueva alerta de seguridad en \(favoritePlace.name) (\(distance) millas)"
        } else {
            return "New safety alert at \(favoritePlace.name) (\(distance) miles)"
        }
    }
    
    var category: ReportCategory {
        return report.category
    }
    
    var content: String {
        return report.originalText
    }
}
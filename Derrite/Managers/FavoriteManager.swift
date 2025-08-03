//  FavoriteManager.swift
//  Derrite

import Foundation
import CoreLocation
import UserNotifications

protocol FavoriteManagerDelegate {
    func onFavoritesUpdated(_ favorites: [FavoritePlace])
    func onNewFavoriteAlerts(_ alerts: [FavoriteAlert])
    func onFavoriteAlertsUpdated(_ alerts: [FavoriteAlert], hasUnviewed: Bool)
}

class FavoriteManager: ObservableObject {
    static let shared = FavoriteManager()

    @Published var favorites: [FavoritePlace] = []
    @Published var favoriteAlerts: [FavoriteAlert] = []
    @Published var hasUnviewedFavoriteAlerts = false

    var onFavoritesUpdated: (([FavoritePlace]) -> Void)?
    var onNewFavoriteAlerts: (([FavoriteAlert]) -> Void)?
    var onFavoriteAlertsUpdated: (([FavoriteAlert], Bool) -> Void)?

    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "saved_favorites"
    private let favoriteAlertsKey = "favorite_alerts"
    private let viewedFavoriteAlertsKey = "viewed_favorite_alerts"

    private var viewedFavoriteAlertIds: Set<String> = []
    private var locationManager: LocationManager
    private var reportManager: ReportManager
    private var preferencesManager: PreferencesManager

    private init() {
        self.locationManager = LocationManager.shared
        self.reportManager = ReportManager.shared
        self.preferencesManager = PreferencesManager.shared
        loadSavedData()
    }

    // MARK: - Favorite Management
    func addFavorite(_ favorite: FavoritePlace) {
        favorites.append(favorite)
        saveFavorites()
        onFavoritesUpdated?(favorites)

        // Subscribe to alerts for this location
        subscribeToFavoriteAlerts(favorite)
    }

    func updateFavorite(_ favorite: FavoritePlace) {
        if let index = favorites.firstIndex(where: { $0.id == favorite.id }) {
            favorites[index] = favorite
            saveFavorites()
            onFavoritesUpdated?(favorites)
        }
    }

    func deleteFavorite(_ favoriteId: String) {
        favorites.removeAll { $0.id == favoriteId }
        favoriteAlerts.removeAll { $0.favoritePlace.id == favoriteId }
        saveFavorites()
        saveFavoriteAlerts()
        onFavoritesUpdated?(favorites)
    }

    func getFavorites() -> [FavoritePlace] {
        return favorites
    }

    // MARK: - Alert Checking
    func checkForFavoriteAlerts() {
        var newAlerts: [FavoriteAlert] = []

        for favorite in favorites {
            let reports = reportManager.getActiveReports()

            for report in reports {
                // Skip alerts for reports created by this user
                if reportManager.isUserCreatedReport(report) {
                    continue
                }

                // Skip if we've already alerted for this report/favorite combo
                let alertExists = favoriteAlerts.contains {
                    $0.report.id == report.id && $0.favoritePlace.id == favorite.id
                }

                if !alertExists {
                    let favoriteLocation = CLLocation(latitude: favorite.location.latitude,
                                                    longitude: favorite.location.longitude)
                    let reportLocation = CLLocation(latitude: report.location.latitude,
                                                  longitude: report.location.longitude)
                    let distance = favoriteLocation.distance(from: reportLocation)

                    let alertDistanceMeters = preferencesManager.alertDistanceMiles * 1609.34 // Convert miles to meters
                    if distance <= alertDistanceMeters && favorite.shouldReceiveAlert(category: report.category) {
                        let alert = FavoriteAlert(
                            favoritePlace: favorite,
                            report: report,
                            distanceFromFavorite: distance,
                            isViewed: viewedFavoriteAlertIds.contains(report.id)
                        )
                        newAlerts.append(alert)
                        favoriteAlerts.append(alert)
                    }
                }
            }
        }

        if !newAlerts.isEmpty {
            hasUnviewedFavoriteAlerts = favoriteAlerts.contains { !$0.isViewed }
            saveFavoriteAlerts()
            
            // Send custom notifications
            sendCustomNotifications(for: newAlerts)
            
            onNewFavoriteAlerts?(newAlerts)
            onFavoriteAlertsUpdated?(favoriteAlerts, hasUnviewedFavoriteAlerts)
        }
    }

    func markFavoriteAlertAsViewed(_ alertId: String) {
        if let index = favoriteAlerts.firstIndex(where: { $0.id == alertId }) {
            favoriteAlerts[index].isViewed = true
            viewedFavoriteAlertIds.insert(favoriteAlerts[index].report.id)
        }

        hasUnviewedFavoriteAlerts = favoriteAlerts.contains { !$0.isViewed }
        saveFavoriteAlerts()
        saveViewedAlerts()
        onFavoriteAlertsUpdated?(favoriteAlerts, hasUnviewedFavoriteAlerts)
    }

    func removeAlertsForExpiredReports(_ expiredReports: [Report]) {
        let expiredIds = Set(expiredReports.map { $0.id })
        favoriteAlerts.removeAll { expiredIds.contains($0.report.id) }
        viewedFavoriteAlertIds = viewedFavoriteAlertIds.subtracting(expiredIds)
        saveFavoriteAlerts()
        saveViewedAlerts()
    }

    func getFavoriteAlertSummaryMessage(_ alerts: [FavoriteAlert], isSpanish: Bool) -> String {
        if alerts.count == 1 {
            let alert = alerts[0]
            return alert.getAlertMessage(isSpanish: isSpanish)
        } else {
            let places = Set(alerts.map { $0.favoritePlace.name }).joined(separator: ", ")
            return isSpanish ?
                "\(alerts.count) alertas en: \(places)" :
                "\(alerts.count) alerts at: \(places)"
        }
    }

    // MARK: - Subscriptions
    func subscribeToAllFavorites() {
        for favorite in favorites {
            subscribeToFavoriteAlerts(favorite)
        }
    }

    private func subscribeToFavoriteAlerts(_ favorite: FavoritePlace) {
        BackendClient.shared.subscribeToAlerts(
            latitude: favorite.location.latitude,
            longitude: favorite.location.longitude
        ) { success, message in
            // Alert subscription handled locally for privacy
        }
    }

    // MARK: - Persistence
    func loadSavedData() {
        loadFavorites()
        loadFavoriteAlerts()
        loadViewedAlerts()
    }

    private func loadFavorites() {
        guard let data = userDefaults.data(forKey: favoritesKey) else { return }

        do {
            let decoder = JSONDecoder()
            favorites = try decoder.decode([FavoritePlace].self, from: data)
        } catch {
            // Failed to load favorites - using empty array
        }
    }

    private func saveFavorites() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(favorites)
            userDefaults.set(data, forKey: favoritesKey)
        } catch {
            // Failed to save favorites
        }
    }

    private func loadFavoriteAlerts() {
        guard let data = userDefaults.data(forKey: favoriteAlertsKey) else { return }

        do {
            let decoder = JSONDecoder()
            favoriteAlerts = try decoder.decode([FavoriteAlert].self, from: data)
            hasUnviewedFavoriteAlerts = favoriteAlerts.contains { !$0.isViewed }
        } catch {
            // Failed to load favorite alerts
        }
    }

    private func saveFavoriteAlerts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(favoriteAlerts)
            userDefaults.set(data, forKey: favoriteAlertsKey)
        } catch {
            // Failed to save favorite alerts
        }
    }

    private func loadViewedAlerts() {
        if let viewedIds = userDefaults.array(forKey: viewedFavoriteAlertsKey) as? [String] {
            viewedFavoriteAlertIds = Set(viewedIds)
        }
    }

    private func saveViewedAlerts() {
        userDefaults.set(Array(viewedFavoriteAlertIds), forKey: viewedFavoriteAlertsKey)
    }
    
    // MARK: - Custom Notifications
    private func sendCustomNotifications(for alerts: [FavoriteAlert]) {
        let center = UNUserNotificationCenter.current()
        let preferencesManager = PreferencesManager.shared
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            
            for alert in alerts {
                let content = UNMutableNotificationContent()
                content.title = preferencesManager.currentLanguage == "es" ? "Alerta de Seguridad" : "Safety Alert"
                content.body = alert.getAlertMessage(isSpanish: preferencesManager.currentLanguage == "es")
                content.sound = .default
                
                let request = UNNotificationRequest(
                    identifier: "favorite_alert_\(alert.id)",
                    content: content,
                    trigger: nil
                )
                
                center.add(request)
            }
        }
    }
}
//  AlertManager.swift
//  Derrite

import Foundation
import CoreLocation
import UserNotifications
import MapKit

protocol AlertManagerDelegate {
    func onNewAlerts(_ alerts: [Alert])
    func onAlertsUpdated(hasUnviewed: Bool)
}

class AlertManager: ObservableObject {
    static let shared = AlertManager()

    @Published var activeAlerts: [Alert] = []
    @Published var hasUnviewedAlerts = false

    var onNewAlerts: (([Alert]) -> Void)?
    var onAlertsUpdated: ((Bool) -> Void)?

    private let userDefaults = UserDefaults.standard
    private let viewedAlertsKey = "viewed_alerts"
    private let lastAlertCheckKey = "last_alert_check"
    private let alertCooldownSeconds: TimeInterval = 60

    private var viewedAlertIds: Set<String> = []
    private var locationManager: LocationManager
    private var reportManager: ReportManager
    private var preferencesManager: PreferencesManager

    private init() {
        self.locationManager = LocationManager.shared
        self.reportManager = ReportManager.shared
        self.preferencesManager = PreferencesManager.shared
        loadViewedAlerts()
    }

    // MARK: - Alert Checking
    func checkForNewAlerts(_ location: CLLocation) {
        let reports = reportManager.getActiveReports()

        var newAlerts: [Alert] = []
        var allCurrentAlerts: [Alert] = []

        for report in reports {
            let reportLocation = CLLocation(latitude: report.location.latitude, longitude: report.location.longitude)
            let distance = location.distance(from: reportLocation)
            let _ = distance / 1609.34 // Distance in miles (unused but calculated for potential future use)

            let alertRadiusMeters = preferencesManager.alertDistanceMiles * 1609.34 // Convert miles to meters

            if distance <= alertRadiusMeters {
                let isViewed = viewedAlertIds.contains(report.id)
                let isUserCreated = reportManager.isUserCreatedReport(report)

                let alert = Alert(
                    id: report.id, // Use report ID as alert ID to prevent duplicates
                    report: report,
                    distanceFromUser: distance,
                    isViewed: isViewed,
                    timestamp: report.timestamp
                )
                allCurrentAlerts.append(alert)

                // Only consider it "new" for notifications if not user-created, not viewed, and not already in activeAlerts
                if !isUserCreated && !isViewed && !activeAlerts.contains(where: { $0.report.id == report.id }) {
                    newAlerts.append(alert)} else if isUserCreated {}
            }
        }

        // Update the full list of current alerts, merging with existing alerts to preserve viewed status
        var updatedAlerts: [Alert] = []
        var seenReportIds: Set<String> = []
        
        for newAlert in allCurrentAlerts {
            // Skip if we've already seen this report ID (additional duplicate prevention)
            if seenReportIds.contains(newAlert.report.id) {
                continue
            }
            seenReportIds.insert(newAlert.report.id)
            
            // Check if we already have an alert for this report
            if let existingAlert = activeAlerts.first(where: { $0.id == newAlert.id }) {
                // Keep the existing alert but update the distance
                var updatedAlert = existingAlert
                updatedAlert.distanceFromUser = newAlert.distanceFromUser
                updatedAlerts.append(updatedAlert)
            } else {
                // New alert
                updatedAlerts.append(newAlert)
            }
        }
        activeAlerts = updatedAlerts
        hasUnviewedAlerts = activeAlerts.contains { !$0.isViewed }// Only trigger notifications for truly new alerts
        if !newAlerts.isEmpty {
            onNewAlerts?(newAlerts)
            sendAlertNotification(for: newAlerts)
        }

        onAlertsUpdated?(hasUnviewedAlerts)

        // Save last check time
        userDefaults.set(Date().timeIntervalSince1970, forKey: lastAlertCheckKey)
    }

    func checkForNewAlertsInRegion(_ region: MKCoordinateRegion) {
        let reports = reportManager.getActiveReports()
        var newAlerts: [Alert] = []
        var allCurrentAlerts: [Alert] = []

        // Calculate region bounds
        let northLatitude = region.center.latitude + (region.span.latitudeDelta / 2.0)
        let southLatitude = region.center.latitude - (region.span.latitudeDelta / 2.0)
        let eastLongitude = region.center.longitude + (region.span.longitudeDelta / 2.0)
        let westLongitude = region.center.longitude - (region.span.longitudeDelta / 2.0)

        for report in reports {
            // Check if report is within the visible map region
            let reportLat = report.location.latitude
            let reportLon = report.location.longitude

            let isInRegion = reportLat >= southLatitude &&
                           reportLat <= northLatitude &&
                           reportLon >= westLongitude &&
                           reportLon <= eastLongitude
            if isInRegion {
                let isViewed = viewedAlertIds.contains(report.id)
                let isUserCreated = reportManager.isUserCreatedReport(report)

                // For distance, we'll use distance from region center since we don't have user location
                let reportLocation = CLLocation(latitude: report.location.latitude, longitude: report.location.longitude)
                let regionCenter = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
                let distance = regionCenter.distance(from: reportLocation)

                let alert = Alert(
                    id: report.id, // Use report ID as alert ID to prevent duplicates
                    report: report,
                    distanceFromUser: distance,
                    isViewed: isViewed,
                    timestamp: report.timestamp
                )
                allCurrentAlerts.append(alert)

                // Only consider it "new" for notifications if not user-created, not viewed, and not already in activeAlerts
                if !isUserCreated && !isViewed && !activeAlerts.contains(where: { $0.report.id == report.id }) {
                    newAlerts.append(alert)} else if isUserCreated {}
            }
        }

        // Update the full list of current alerts, merging with existing alerts to preserve viewed status
        var updatedAlerts: [Alert] = []
        var seenReportIds: Set<String> = []
        
        for newAlert in allCurrentAlerts {
            // Skip if we've already seen this report ID (additional duplicate prevention)
            if seenReportIds.contains(newAlert.report.id) {
                continue
            }
            seenReportIds.insert(newAlert.report.id)
            
            // Check if we already have an alert for this report
            if let existingAlert = activeAlerts.first(where: { $0.id == newAlert.id }) {
                // Keep the existing alert but update the distance
                var updatedAlert = existingAlert
                updatedAlert.distanceFromUser = newAlert.distanceFromUser
                updatedAlerts.append(updatedAlert)
            } else {
                // New alert
                updatedAlerts.append(newAlert)
            }
        }
        activeAlerts = updatedAlerts
        hasUnviewedAlerts = activeAlerts.contains { !$0.isViewed }// Only trigger notifications for truly new alerts
        if !newAlerts.isEmpty {
            onNewAlerts?(newAlerts)
            sendAlertNotification(for: newAlerts)
        }

        onAlertsUpdated?(hasUnviewedAlerts)

        // Save last check time
        userDefaults.set(Date().timeIntervalSince1970, forKey: lastAlertCheckKey)
    }

    func markAlertAsViewed(_ reportId: String) {
        viewedAlertIds.insert(reportId)

        // Update alert status
        if let index = activeAlerts.firstIndex(where: { $0.report.id == reportId }) {
            activeAlerts[index].isViewed = true
        }

        // Check if any unviewed alerts remain
        hasUnviewedAlerts = activeAlerts.contains { !$0.isViewed }
        onAlertsUpdated?(hasUnviewedAlerts)

        saveViewedAlerts()
    }

    func removeAlertsForExpiredReports(_ expiredReports: [Report]) {
        let expiredIds = Set(expiredReports.map { $0.id })
        activeAlerts.removeAll { expiredIds.contains($0.report.id) }
        viewedAlertIds = viewedAlertIds.subtracting(expiredIds)
        saveViewedAlerts()
    }

    func getAlertSummaryMessage(_ alerts: [Alert], isSpanish: Bool) -> String {
        if alerts.count == 1 {
            let alert = alerts[0]
            let distanceText = formatDistance(alert.distanceFromUser, isSpanish: isSpanish)
            return isSpanish ? "Nueva alerta a \(distanceText)" : "New alert \(distanceText) away"
        } else {
            return isSpanish ? "\(alerts.count) nuevas alertas en tu área" : "\(alerts.count) new alerts in your area"
        }
    }

    // MARK: - Persistence
    func loadViewedAlerts() {
        if let viewedIds = userDefaults.array(forKey: viewedAlertsKey) as? [String] {
            viewedAlertIds = Set(viewedIds)
        }
    }

    private func saveViewedAlerts() {
        userDefaults.set(Array(viewedAlertIds), forKey: viewedAlertsKey)
    }

    // MARK: - Notifications
    private func sendAlertNotification(for alerts: [Alert]) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            let preferencesManager = PreferencesManager.shared
            let isSpanish = preferencesManager.currentLanguage == "es"
            
            if alerts.count == 1 {
                let alert = alerts[0]
                let distance = self.formatDistance(alert.distanceFromUser, isSpanish: isSpanish)
                content.title = isSpanish ? "Alerta de Seguridad" : "Safety Alert"
                content.body = isSpanish ? 
                    "Reporte de seguridad \(distance) de tu ubicación" :
                    "Safety report \(distance) from your location"
            } else {
                content.title = isSpanish ? "Múltiples Alertas" : "Multiple Alerts"
                content.body = self.getAlertSummaryMessage(alerts, isSpanish: isSpanish)
            }
            
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            center.add(request)
        }
    }

    // MARK: - Helpers
    private func formatDistance(_ meters: Double, isSpanish: Bool) -> String {
        if meters < 1609 {
            let feet = Int(meters * 3.28084)
            return isSpanish ? "\(feet) pies" : "\(feet) ft"
        } else {
            let miles = String(format: "%.1f", meters / 1609.0)
            return isSpanish ? "\(miles) millas" : "\(miles) mi"
        }
    }
}
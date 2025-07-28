//
//  AlertManager.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import Foundation
import CoreLocation
import UserNotifications

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
        print("🚨 AlertManager: Checking \(reports.count) reports for user at \(location.coordinate)")
        print("🚨 Alert distance: \(preferencesManager.alertDistanceMiles) miles")
        
        var newAlerts: [Alert] = []
        var allCurrentAlerts: [Alert] = []
        
        for report in reports {
            let reportLocation = CLLocation(latitude: report.location.latitude, longitude: report.location.longitude)
            let distance = location.distance(from: reportLocation)
            let distanceMiles = distance / 1609.34
            
            let alertRadiusMeters = preferencesManager.alertDistanceMiles * 1609.34 // Convert miles to meters
            print("🚨 Report \(report.id): \(String(format: "%.2f", distanceMiles)) miles away (limit: \(preferencesManager.alertDistanceMiles) miles)")
            
            if distance <= alertRadiusMeters {
                let isViewed = viewedAlertIds.contains(report.id)
                let alert = Alert(
                    report: report,
                    distanceFromUser: distance,
                    isViewed: isViewed
                )
                allCurrentAlerts.append(alert)
                
                // Only consider it "new" if not viewed and not already in activeAlerts
                if !isViewed && !activeAlerts.contains(where: { $0.report.id == report.id }) {
                    newAlerts.append(alert)
                }
            }
        }
        
        // Update the full list of current alerts
        activeAlerts = allCurrentAlerts
        hasUnviewedAlerts = activeAlerts.contains { !$0.isViewed }
        
        print("🚨 AlertManager: Found \(allCurrentAlerts.count) alerts total, \(newAlerts.count) new alerts")
        print("🚨 ActiveAlerts count: \(activeAlerts.count)")
        
        // Only trigger notifications for truly new alerts
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
            content.title = "New Alert"
            content.body = self.getAlertSummaryMessage(alerts, isSpanish: false)
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
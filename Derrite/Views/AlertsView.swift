//
//  AlertsView.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import SwiftUI
import CoreLocation

enum AlertSortOption: String, CaseIterable {
    case nearest = "Nearest"
    case farthest = "Farthest" 
    case newest = "Most Recent"
    case oldest = "Oldest"
    
    var displayName: String {
        return self.rawValue
    }
}

enum AlertFilterOption: String, CaseIterable {
    case all = "All Alerts"
    case unviewed = "Unviewed Only"
    
    var displayName: String {
        return self.rawValue
    }
}

struct AlertsView: View {
    @StateObject private var alertManager = AlertManager.shared
    @StateObject private var favoriteManager = FavoriteManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedSortOption: AlertSortOption = .newest
    @State private var selectedFilterOption: AlertFilterOption = .all
    @State private var showingSortOptions = false
    @State private var showingFilterOptions = false
    @State private var selectedAlert: Alert?
    @State private var showingAlertDetails = false
    @State private var userLocation: CLLocation?
    
    private var filteredAndSortedAlerts: [Alert] {
        var alerts = alertManager.activeAlerts
        
        // Apply filter
        switch selectedFilterOption {
        case .all:
            break // Show all
        case .unviewed:
            alerts = alerts.filter { !$0.isViewed }
        }
        
        // Apply sort
        switch selectedSortOption {
        case .nearest:
            alerts.sort { $0.distanceFromUser < $1.distanceFromUser }
        case .farthest:
            alerts.sort { $0.distanceFromUser > $1.distanceFromUser }
        case .newest:
            alerts.sort { $0.report.timestamp > $1.report.timestamp }
        case .oldest:
            alerts.sort { $0.report.timestamp < $1.report.timestamp }
        }
        
        return alerts
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter and Sort Controls
                HStack {
                    // Filter Button
                    Button(action: { showingFilterOptions = true }) {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(selectedFilterOption.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(15)
                    }
                    
                    Spacer()
                    
                    // Sort Button
                    Button(action: { showingSortOptions = true }) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(selectedSortOption.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(15)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                
                // Alerts List
                if filteredAndSortedAlerts.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text(selectedFilterOption == .unviewed ? "No unviewed alerts" : "No alerts")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Alerts will appear here when reports are created near your location or favorite places")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredAndSortedAlerts, id: \.id) { alert in
                            AlertRow(
                                alert: alert,
                                userLocation: userLocation,
                                onTap: {
                                    selectedAlert = alert
                                    showingAlertDetails = true
                                    alertManager.markAlertAsViewed(alert.report.id)
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(preferencesManager.currentLanguage == "es" ? "Alertas" : "Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if alertManager.hasUnviewedAlerts {
                        Button(preferencesManager.currentLanguage == "es" ? "Marcar todas leídas" : "Mark All Read") {
                            markAllAlertsAsViewed()
                        }
                        .font(.caption)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.currentLanguage == "es" ? "Listo" : "Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            locationManager.getLastLocation { location in
                userLocation = location
            }
        }
        .actionSheet(isPresented: $showingSortOptions) {
            ActionSheet(
                title: Text(preferencesManager.currentLanguage == "es" ? "Ordenar Alertas" : "Sort Alerts"),
                buttons: AlertSortOption.allCases.map { option in
                    .default(Text(option.displayName)) {
                        selectedSortOption = option
                    }
                } + [.cancel()]
            )
        }
        .actionSheet(isPresented: $showingFilterOptions) {
            ActionSheet(
                title: Text(preferencesManager.currentLanguage == "es" ? "Filtrar Alertas" : "Filter Alerts"),
                buttons: AlertFilterOption.allCases.map { option in
                    .default(Text(option.displayName)) {
                        selectedFilterOption = option
                    }
                } + [.cancel()]
            )
        }
        .sheet(isPresented: $showingAlertDetails) {
            if let alert = selectedAlert {
                ReportDetailsView(
                    report: alert.report,
                    onClose: {
                        showingAlertDetails = false
                        selectedAlert = nil
                    }
                )
            }
        }
    }
    
    // MARK: - Actions
    private func markAllAlertsAsViewed() {
        for alert in alertManager.activeAlerts {
            alertManager.markAlertAsViewed(alert.report.id)
        }
    }
}

// MARK: - Alert Row View
struct AlertRow: View {
    let alert: Alert
    let userLocation: CLLocation?
    let onTap: () -> Void
    
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var displayText: String = ""
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Alert Status Indicator
                Circle()
                    .fill(alert.isViewed ? Color.gray : Color.red)
                    .frame(width: 8, height: 8)
                
                // Category Icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color("categorySafety"))
                    .frame(width: 24, height: 24)
                
                // Alert Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(alert.report.category.getDisplayName(isSpanish: preferencesManager.currentLanguage == "es"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(alert.report.timeAgo(preferencesManager: preferencesManager))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text(displayText.isEmpty ? alert.report.originalText : displayText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        // Distance from user
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(formatDistance(alert.distanceFromUser))
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        // Photo indicator
                        if alert.report.hasPhoto {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                Text("Photo")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            // Auto-translate the report text when the row appears
            displayText = await SimpleTranslationService.shared.autoTranslateToCurrentLanguage(alert.report.originalText)
        }
    }
    
    // MARK: - Helper Methods
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1609 {
            let feet = Int(meters * 3.28084)
            return "\(feet) \(preferencesManager.localizedString("ft"))"
        } else {
            let miles = String(format: "%.1f", meters / 1609.0)
            let milesText = miles == "1.0" ? preferencesManager.localizedString("mile") : preferencesManager.localizedString("miles")
            return "\(miles) \(milesText)"
        }
    }
}

#Preview {
    AlertsView()
}
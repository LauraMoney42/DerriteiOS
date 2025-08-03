//  AlertsView.swift
//  Derrite

import SwiftUI
import CoreLocation

enum AlertSortOption: String, CaseIterable {
    case newest = "Most Recent"
    case nearest = "Nearest"

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
    @State private var sortUpdateTrigger = UUID()

    private var filteredAndSortedAlerts: [Alert] {
        var alerts = alertManager.activeAlerts
        
        // Trigger recalculation when sort option changes
        _ = sortUpdateTrigger

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
        case .newest:
            alerts.sort { $0.report.timestamp > $1.report.timestamp }
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
                        .background(Color(UIColor.systemBlue).opacity(0.1))
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
                        .background(Color(UIColor.systemBlue).opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(15)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))

                // Helper Text
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(preferencesManager.currentLanguage == "es" ? 
                         "La lista se actualiza según la vista del mapa. Aleja el zoom para ver alertas de un área más amplia." :
                         "List updates based on map view. Zoom out to see alerts in a larger area.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))

                // Alerts List
                if filteredAndSortedAlerts.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text(selectedFilterOption == .unviewed ? "No unviewed alerts" : "No alerts")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Alerts will appear here when reports are created near your location or favorite places")
                            .font(.body)
                            .foregroundColor(.secondary)
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
                    .listStyle(InsetGroupedListStyle())
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
        .confirmationDialog(
            preferencesManager.currentLanguage == "es" ? "Ordenar Alertas" : "Sort Alerts",
            isPresented: $showingSortOptions,
            titleVisibility: .visible
        ) {
            ForEach(AlertSortOption.allCases, id: \.self) { option in
                Button(option.displayName) {
                    selectedSortOption = option
                    sortUpdateTrigger = UUID()
                }
            }
            Button(preferencesManager.currentLanguage == "es" ? "Cancelar" : "Cancel", role: .cancel) { }
        }
        .confirmationDialog(
            preferencesManager.currentLanguage == "es" ? "Filtrar Alertas" : "Filter Alerts",
            isPresented: $showingFilterOptions,
            titleVisibility: .visible
        ) {
            ForEach(AlertFilterOption.allCases, id: \.self) { option in
                Button(option.displayName) {
                    selectedFilterOption = option
                }
            }
            Button(preferencesManager.currentLanguage == "es" ? "Cancelar" : "Cancel", role: .cancel) { }
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
    @State private var address: String = ""
    @State private var isLoadingAddress = true

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Alert Status Indicator
                Circle()
                    .fill(alert.isViewed ? Color.secondary : Color.red)
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
                            .foregroundColor(.secondary)
                    }

                    Text(displayText.isEmpty ? alert.report.originalText : displayText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        // Address
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            if isLoadingAddress {
                                Text(preferencesManager.localizedString("loading_address"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(address.isEmpty ? formatCoordinates(alert.report.location) : address)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // Photo indicator
                        if alert.report.hasPhoto {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text("Photo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            // Auto-translate the report text when the row appears
            displayText = await SimpleTranslationService.shared.autoTranslateToCurrentLanguage(alert.report.originalText)
            // Load address for the report location
            loadAddress()
        }
    }

    // MARK: - Helper Methods
    private func loadAddress() {
        GeocodingService.shared.getAddress(from: alert.report.location) { loadedAddress in
            DispatchQueue.main.async {
                self.isLoadingAddress = false
                self.address = loadedAddress
            }
        }
    }

    private func formatCoordinates(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}

#Preview {
    AlertsView()
}
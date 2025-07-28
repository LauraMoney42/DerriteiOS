//
//  ContentView.swift
//  Derrite
//
//  Created by Laura Money on 7/26/25.
//

import SwiftUI
import MapKit
import Speech
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var reportManager = ReportManager.shared
    @StateObject private var alertManager = AlertManager.shared
    @StateObject private var favoriteManager = FavoriteManager.shared
    @StateObject private var preferencesManager = PreferencesManager.shared
    
    @State private var centerCoordinate = CLLocationCoordinate2D()
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var searchResultLocation: CLLocationCoordinate2D?
    @State private var showingAlert = false
    @State private var showingSettings = false
    @State private var showingAlerts = false
    @State private var showingFavorites = false
    @State private var showingReportInput = false
    @State private var showingFavoriteInput = false
    @State private var showingInstructions = true
    @State private var statusMessage = ""
    @State private var isStatusError = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedReport: Report?
    @State private var showingReportDetails = false
    @State private var showingContextMenu = false
    @State private var isListeningForSpeech = false
    @State private var mapType: MKMapType = .hybridFlyover
    @State private var activeAlert: AlertNotificationData?
    @State private var showingAlertNotification = false
    @State private var selectedFavorite: FavoritePlace?
    @State private var showingFavoriteDetails = false
    
    var body: some View {
        ZStack {
            // Map View
            MapView(
                centerCoordinate: $centerCoordinate,
                reports: $reportManager.activeReports,
                favorites: $favoriteManager.favorites,
                userLocation: $userLocation,
                searchResultLocation: $searchResultLocation,
                mapType: mapType,
                onLongPress: handleLongPress,
                onReportTap: handleReportTap,
                onFavoriteTap: handleFavoriteTap
            )
            .ignoresSafeArea()
            
            // Top Status Card
            if !statusMessage.isEmpty {
                VStack {
                    StatusCard(message: statusMessage, isError: isStatusError) {
                        withAnimation {
                            statusMessage = ""
                        }
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .transition(.move(edge: .top))
            }
            
            // Google Maps Style Search Bar with integrated location button
            VStack {
                // Search field with all controls inside
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    
                    TextField(preferencesManager.localizedString("search_address"), text: $searchText)
                        .foregroundColor(.gray)
                        .disabled(isSearching)
                        .onSubmit {
                            performSearch()
                        }
                    
                    // Right side controls
                    HStack(spacing: 8) {
                        if !searchText.isEmpty {
                            Button(action: clearSearch) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            }
                        }
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            // Microphone button
                            Button(action: startSpeechRecognition) {
                                Image(systemName: isListeningForSpeech ? "mic.fill" : "mic")
                                    .foregroundColor(isListeningForSpeech ? .red : .gray)
                                    .font(.system(size: 16))
                            }
                        }
                        
                        // Location button inside search bar
                        Button(action: getCurrentLocation) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.7))
                .cornerRadius(25)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, -5)
                
                Spacer()
            }
            
            
            // Instructions Overlay
            if showingInstructions && !preferencesManager.getUserHasCreatedReports() {
                InstructionOverlay {
                    withAnimation {
                        showingInstructions = false
                        preferencesManager.setUserHasCreatedReports(true)
                    }
                }
            }
            
            // Persistent Alert Notification Overlay
            if showingAlertNotification, let alertData = activeAlert {
                AlertNotificationView(
                    alertMessage: alertData.message,
                    reportLocation: alertData.locationName,
                    distance: alertData.distance,
                    report: alertData.report,
                    shouldOverrideSilent: alertData.shouldOverrideSilent,
                    onDismiss: {
                        dismissAlert()
                    },
                    onViewDetails: { report in
                        // Open report details
                        selectedReport = report
                        showingReportDetails = true
                        dismissAlert()
                    }
                )
                .zIndex(1000) // Ensure it appears above everything
            }
            
            // Bottom Menu Bar - moved to very bottom
            VStack {
                Spacer()
                
                HStack {
                    // Language Toggle
                    Button(action: toggleLanguage) {
                        Text(preferencesManager.currentLanguage == "es" ? "English" : "Español")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.gray)
                            .cornerRadius(15)
                    }
                    
                    Spacer()
                    
                    // Settings
                    Button(action: { showingSettings = true }) {
                        VStack(spacing: 2) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                            Text(preferencesManager.localizedString("settings"))
                                .font(.caption)
                        }
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Alerts
                    Button(action: { showingAlerts = true }) {
                        VStack(spacing: 2) {
                            Image(systemName: "bell.fill")
                                .font(.title2)
                                .foregroundColor(alertManager.hasUnviewedAlerts ? .red : .gray)
                            
                            Text(preferencesManager.localizedString("alerts"))
                                .font(.caption)
                                .foregroundColor(alertManager.hasUnviewedAlerts ? .red : .gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Favorites
                    Button(action: { showingFavorites = true }) {
                        VStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                            
                            Text(preferencesManager.localizedString("favorites"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(radius: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, -10) // Pushed down lower
            }
        }
        .onAppear {
            setupApp()
        }
        .sheet(isPresented: $showingReportInput) {
            if let location = selectedLocation {
                ReportInputView(
                    location: location,
                    onSubmit: { text, photo in
                        createReport(at: location, text: text, photo: photo)
                    },
                    onCancel: {
                        showingReportInput = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingReportDetails) {
            if let report = selectedReport {
                ReportDetailsView(
                    report: report,
                    onClose: {
                        showingReportDetails = false
                        selectedReport = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingFavoriteInput) {
            if let location = selectedLocation {
                FavoriteInputView(
                    location: location,
                    onSubmit: { name, description in
                        addFavorite(at: location, name: name, description: description)
                    },
                    onCancel: {
                        showingFavoriteInput = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingAlerts) {
            AlertsView()
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesView(onFavoriteSelected: { favorite in
                // Close favorites view and zoom to selected favorite
                showingFavorites = false
                zoomToFavorite(favorite)
            })
        }
        .sheet(isPresented: $showingFavoriteDetails) {
            if let favorite = selectedFavorite {
                FavoriteDetailsView(
                    favorite: favorite,
                    onClose: {
                        showingFavoriteDetails = false
                        selectedFavorite = nil
                    },
                    onEdit: {
                        // TODO: Implement edit functionality
                        showingFavoriteDetails = false
                        selectedFavorite = nil
                        showStatus(preferencesManager.localizedString("edit_functionality_coming_soon"), isError: false)
                    },
                    onDelete: {
                        // Delete the favorite
                        if let favorite = selectedFavorite {
                            favoriteManager.deleteFavorite(favorite.id)
                            showStatus("\(favorite.name) \(preferencesManager.localizedString("removed_from_favorites"))", isError: false)
                        }
                        showingFavoriteDetails = false
                        selectedFavorite = nil
                    }
                )
            }
        }
        .actionSheet(isPresented: $showingContextMenu) {
            ActionSheet(
                title: Text(preferencesManager.localizedString("what_would_you_like_to_do")),
                buttons: [
                    .default(Text(preferencesManager.localizedString("report_safety_issue"))) {
                        if let location = selectedLocation {
                            createReport(at: location)
                        }
                    },
                    .default(Text(preferencesManager.localizedString("add_to_favorites"))) {
                        if let location = selectedLocation {
                            createFavorite(at: location)
                        }
                    },
                    .cancel(Text(preferencesManager.localizedString("cancel")))
                ]
            )
        }
    }
    
    // MARK: - Setup
    private func setupApp() {
        // Check for jailbreak
        if SecurityManager.shared.isJailbroken() {
            statusMessage = preferencesManager.localizedString("security_warning_jailbroken")
            isStatusError = true
            return
        }
        
        // Request location permission
        locationManager.requestLocationPermission()
        
        // Start location updates and auto-zoom to user location
        locationManager.startLocationUpdates { location in
            userLocation = location.coordinate
            
            // Auto-zoom to user location on first load
            if centerCoordinate.latitude == 0 && centerCoordinate.longitude == 0 {
                centerCoordinate = location.coordinate
                showStatus(preferencesManager.localizedString("your_location"), isError: false)
            }
            
            alertManager.checkForNewAlerts(location)
            favoriteManager.checkForFavoriteAlerts()
        }
        
        // Set up closures
        alertManager.onNewAlerts = { alerts in
            if let firstAlert = alerts.first {
                self.showPersistentAlert(for: firstAlert.report, isFromFavorite: false)
            }
        }
        
        favoriteManager.onNewFavoriteAlerts = { alerts in
            if let firstAlert = alerts.first {
                self.showPersistentAlert(for: firstAlert.report, isFromFavorite: true, favoriteName: firstAlert.favoritePlace.name, favoriteDistance: firstAlert.distanceFromFavorite)
            }
        }
        
        // Load initial data
        reportManager.fetchAllReports { success, message in
            if !success {
                showStatus(message, isError: true)
            } else {
                // Check for alerts after reports are loaded
                self.checkAlertsWithCurrentLocation()
            }
        }
        
        // Start periodic tasks
        startPeriodicTasks()
    }
    
    // MARK: - Actions
    private func handleLongPress(_ location: CLLocationCoordinate2D) {
        selectedLocation = location
        showingInstructions = false
        showingContextMenu = true
    }
    
    private func handleReportTap(_ report: Report) {
        // Show report details
        selectedReport = report
        showingReportDetails = true
        alertManager.markAlertAsViewed(report.id)
    }
    
    private func handleFavoriteTap(_ favorite: FavoritePlace) {
        // Zoom to favorite location first
        centerCoordinate = favorite.location
        showStatus("\(preferencesManager.localizedString("showing")) \(favorite.name)", isError: false)
        
        // Then show favorite details
        selectedFavorite = favorite
        showingFavoriteDetails = true
    }
    
    private func getCurrentLocation() {
        showStatus(preferencesManager.localizedString("finding_location"), isError: false)
        
        locationManager.getLastLocation { location in
            if let location = location {
                userLocation = location.coordinate
                centerCoordinate = location.coordinate
                
                let description = locationManager.getLocationDescription(for: location)
                showStatus(description, isError: false)
            } else {
                showStatus(preferencesManager.localizedString("unable_to_get_location"), isError: true)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            showStatus(preferencesManager.localizedString("please_enter_address"), isError: true)
            return 
        }
        
        isSearching = true
        showStatus(preferencesManager.localizedString("searching_address"), isError: false)
        
        locationManager.searchAddress(query: searchText) { results in
            DispatchQueue.main.async {
                isSearching = false
                
                if let results = results, let firstResult = results.first {
                    searchResultLocation = firstResult.placemark.coordinate
                    centerCoordinate = firstResult.placemark.coordinate
                    
                    let address = locationManager.getFormattedAddress(for: firstResult)
                    showStatus("\(preferencesManager.localizedString("found")): \(address)", isError: false)
                } else {
                    showStatus(preferencesManager.localizedString("address_not_found"), isError: true)
                }
            }
        }
    }
    
    private func clearSearch() {
        searchText = ""
        searchResultLocation = nil
    }
    
    private func startSpeechRecognition() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.performSpeechRecognition()
                case .denied, .restricted, .notDetermined:
                    self.showStatus(self.preferencesManager.localizedString("speech_recognition_not_available"), isError: true)
                @unknown default:
                    self.showStatus(self.preferencesManager.localizedString("speech_recognition_not_available"), isError: true)
                }
            }
        }
    }
    
    private func performSpeechRecognition() {
        // For now, show a placeholder. Full speech recognition would require more setup
        isListeningForSpeech = true
        showStatus(preferencesManager.localizedString("speech_recognition_coming_soon"), isError: false)
        
        // Simulate listening for 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isListeningForSpeech = false
        }
    }
    
    private func zoomToFavorite(_ favorite: FavoritePlace) {
        // Zoom to the favorite location
        centerCoordinate = favorite.location
        showStatus("\(preferencesManager.localizedString("showing")) \(favorite.name)", isError: false)
    }
    
    
    private func createReport(at location: CLLocationCoordinate2D) {
        selectedLocation = location
        showingReportInput = true
    }
    
    private func createReport(at location: CLLocationCoordinate2D, text: String, photo: UIImage?) {
        let report = reportManager.createReport(
            location: location,
            text: text,
            detectedLanguage: preferencesManager.currentLanguage,
            photo: photo,
            category: .safety
        )
        
        showStatus(preferencesManager.localizedString("safety_report_submitted"), isError: false)
        
        // Check for favorite alerts after creating a report
        favoriteManager.checkForFavoriteAlerts()
        
        reportManager.submitReport(report) { success, message in
            if !success {
                showStatus(message, isError: true)
            }
        }
        
        showingReportInput = false
    }
    
    private func createFavorite(at location: CLLocationCoordinate2D) {
        selectedLocation = location
        showingFavoriteInput = true
    }
    
    private func addFavorite(at location: CLLocationCoordinate2D, name: String, description: String) {
        let favorite = FavoritePlace(
            name: name,
            description: description,
            location: location
        )
        
        favoriteManager.addFavorite(favorite)
        showStatus("\(name) \(preferencesManager.localizedString("added_to_favorites"))", isError: false)
        showingFavoriteInput = false
    }
    
    private func toggleLanguage() {
        let newLanguage = preferencesManager.currentLanguage == "es" ? "en" : "es"
        preferencesManager.saveLanguage(newLanguage)
        preferencesManager.setLanguageChange(true)
    }
    
    private func showStatus(_ message: String, isError: Bool) {
        withAnimation {
            statusMessage = message
            isStatusError = isError
        }
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                statusMessage = ""
            }
        }
    }
    
    private func startPeriodicTasks() {
        // Periodic report sync
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            reportManager.fetchAllReports { _, _ in
                // Check for new alerts after fetching reports
                self.checkAlertsWithCurrentLocation()
                favoriteManager.checkForFavoriteAlerts()
            }
        }
        
        // Cleanup expired reports
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            _ = reportManager.cleanupExpiredReports()
        }
    }
    
    private func checkAlertsWithCurrentLocation() {
        if let userLoc = self.userLocation {
            let location = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            print("🔍 Checking for alerts with user location: \(userLoc)")
            alertManager.checkForNewAlerts(location)
        } else {
            // Try to get current location
            locationManager.getLastLocation { location in
                if let location = location {
                    print("🔍 Checking for alerts with fetched location: \(location.coordinate)")
                    DispatchQueue.main.async {
                        self.alertManager.checkForNewAlerts(location)
                    }
                } else {
                    print("⚠️ No location available for alert checking")
                }
            }
        }
    }
    
    // MARK: - Alert Management
    private func showPersistentAlert(for report: Report, isFromFavorite: Bool, favoriteName: String? = nil, favoriteDistance: Double? = nil) {
        guard preferencesManager.enableSoundAlerts else { return }
        
        // Calculate location name and distance
        let reportLocation = CLLocation(latitude: report.location.latitude, longitude: report.location.longitude)
        var locationName = "Unknown location"
        var distanceText = ""
        var actualDistance: Double = Double.greatestFiniteMagnitude
        
        // Determine actual distance for emergency override check
        if isFromFavorite, let favDistance = favoriteDistance {
            actualDistance = favDistance
        } else if let userLoc = self.userLocation {
            let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            actualDistance = userLocation.distance(from: reportLocation)
        }
        
        // Only override silent mode if within the emergency override distance
        let emergencyOverrideMeters = preferencesManager.emergencyOverrideDistanceMiles * 1609.34
        let shouldOverrideSilent = preferencesManager.emergencyAlertBypassSilent && actualDistance <= emergencyOverrideMeters
        
        // Get location name through reverse geocoding
        locationManager.reverseGeocodeLocation(reportLocation) { placemark in
            DispatchQueue.main.async {
                if let placemark = placemark {
                    if let name = placemark.name {
                        locationName = name
                    } else if let thoroughfare = placemark.thoroughfare {
                        locationName = thoroughfare
                    } else if let locality = placemark.locality {
                        locationName = locality
                    }
                }
                
                // Calculate distance
                if isFromFavorite, let favName = favoriteName, let favDistance = favoriteDistance {
                    locationName = favName
                    distanceText = self.formatDistance(favDistance)
                } else if let userLoc = self.userLocation {
                    let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                    let distance = userLocation.distance(from: reportLocation)
                    distanceText = self.formatDistance(distance)
                }
                
                // Create alert data
                let alertData = AlertNotificationData(
                    message: isFromFavorite ? preferencesManager.localizedString("safety_issue_near_favorite") : preferencesManager.localizedString("safety_issue_in_area"),
                    locationName: locationName,
                    distance: distanceText,
                    reportId: report.id,
                    report: report,
                    shouldOverrideSilent: shouldOverrideSilent
                )
                
                // Show persistent alert
                self.activeAlert = alertData
                self.showingAlertNotification = true
            }
        }
    }
    
    private func dismissAlert() {
        // Mark alert as viewed if needed
        if let alertData = activeAlert {
            alertManager.markAlertAsViewed(alertData.reportId)
        }
        
        // Dismiss the alert
        activeAlert = nil
        showingAlertNotification = false
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1609 { // Less than 1 mile
            let feet = Int(meters * 3.28084)
            return "\(feet) \(preferencesManager.localizedString("ft"))"
        } else {
            let miles = String(format: "%.1f", meters / 1609.0)
            let milesText = miles == "1.0" ? preferencesManager.localizedString("mile") : preferencesManager.localizedString("miles")
            return "\(miles) \(milesText)"
        }
    }
}

// MARK: - Alert Notification Data
struct AlertNotificationData {
    let message: String
    let locationName: String
    let distance: String
    let reportId: String
    let report: Report
    let shouldOverrideSilent: Bool
}


// MARK: - Supporting Views
struct StatusCard: View {
    let message: String
    let isError: Bool
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Text(message)
                .foregroundColor(isError ? .red : .gray)
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 4)
        .padding(.horizontal)
    }
}

struct InstructionOverlay: View {
    let onDismiss: () -> Void
    @StateObject private var preferencesManager = PreferencesManager.shared
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Text(preferencesManager.localizedString("anonymous_safety_reporting"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(preferencesManager.localizedString("long_press_instructions"))
                    .multilineTextAlignment(.center)
                
                Button(preferencesManager.localizedString("view_user_guide")) {
                    // Show user guide
                }
                .foregroundColor(.blue)
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            
            Spacer()
        }
        .background(Color.black.opacity(0.3))
        .onTapGesture {
            onDismiss()
        }
    }
}

#Preview {
    ContentView()
}

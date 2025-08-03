//  ContentView.swift
//  Derrite
//  Created by Laura Money on 7/26/25.

import SwiftUI
import MapKit
import Speech
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var reportManager = ReportManager.shared
    @StateObject private var alertManager = AlertManager.shared
    @StateObject private var favoriteManager = FavoriteManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var preferencesManager = PreferencesManager.shared
    @StateObject private var authManager = AuthenticationManager.shared

    private let inputValidator = InputValidator.shared

    @State private var centerCoordinate = CLLocationCoordinate2D()
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var searchResultLocation: CLLocationCoordinate2D?
    @State private var currentMapRegion: MKCoordinateRegion?
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
    @State private var userHasInteractedWithMap = false
    @State private var hasSetInitialLocation = false
    @State private var shouldForceMapUpdate = false
    @State private var mapUpdateType: MapUpdateType = .normal

    var body: some View {
        ZStack {
            if authManager.isAppLocked {
                // Show authentication lock screen
                AuthenticationLockView {
                    // Unlock the app when authentication succeeds
                    authManager.unlockApp()
                }
            } else {
                // Main app content
                mainAppView
            }
        }
        .onAppear {
            authManager.startAutoLockTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Lock the app when it goes to background/inactive
            if authManager.isAuthenticationEnabled && authManager.autoLockInterval == .immediate {
                authManager.lockApp()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Always lock when entering background for security
            if authManager.isAuthenticationEnabled {
                authManager.lockApp()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Check authentication status when returning from background
            authManager.checkAuthenticationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Also check when becoming active (covers all cases)
            authManager.checkAuthenticationStatus()
        }
    }

    private var mainAppView: some View {
        ZStack {
            // Map View
            MapView(
                centerCoordinate: $centerCoordinate,
                reports: $reportManager.activeReports,
                favorites: $favoriteManager.favorites,
                userLocation: $userLocation,
                searchResultLocation: $searchResultLocation,
                shouldForceUpdate: $shouldForceMapUpdate,
                mapUpdateType: $mapUpdateType,
                mapType: mapType,
                onLongPress: handleLongPress,
                onReportTap: handleReportTap,
                onFavoriteTap: handleFavoriteTap,
                onRegionChange: { region in
                    DispatchQueue.main.async {
                        self.currentMapRegion = region
                        // Mark that user has interacted with map when region changes
                        self.userHasInteractedWithMap = true
                        self.checkAlertsForCurrentMapRegion()
                    }
                },
                onUpdateComplete: {
                    DispatchQueue.main.async {
                        self.shouldForceMapUpdate = false
                        self.mapUpdateType = .normal
                    }
                }
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
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))

                    TextField(preferencesManager.localizedString("search_address"), text: $searchText)
                        .foregroundColor(.primary)
                        .disabled(isSearching)
                        .onSubmit {
                            performSearch()
                        }

                    // Right side controls
                    HStack(spacing: 8) {
                        if !searchText.isEmpty {
                            Button(action: clearSearch) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                        }

                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }

                        // Location button inside search bar
                        Button(action: getCurrentLocation) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground).opacity(0.9))
                .cornerRadius(25)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, -5)

                Spacer()
            }



            // Persistent Alert Notification Overlay - positioned at top
            if showingAlertNotification, let alertData = activeAlert {
                VStack {
                    AlertNotificationView(
                        alertMessage: alertData.message,
                        reportLocation: alertData.locationName,
                        distance: alertData.distance,
                        address: alertData.address,
                        report: alertData.report,
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
                    
                    Spacer() // Push the alert to the top
                }
                .zIndex(1000) // Ensure it appears above everything
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showingAlertNotification)
            }

            // Bottom Menu Bar - moved to very bottom
            VStack {
                Spacer()

                HStack {
                    // Language Toggle
                    Button(action: toggleLanguage) {
                        Text(preferencesManager.currentLanguage == "es" ? "English" : "Español")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemBlue))
                            .foregroundColor(.white)
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
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Favorites
                    Button(action: { showingFavorites = true }) {
                        VStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            Text(preferencesManager.localizedString("favorites"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Alerts
                    Button(action: { showingAlerts = true }) {
                        VStack(spacing: 2) {
                            Image(systemName: "bell.fill")
                                .font(.title2)
                                .foregroundColor(alertManager.hasUnviewedAlerts ? .red : .secondary)

                            Text(preferencesManager.localizedString("alerts"))
                                .font(.caption)
                                .foregroundColor(alertManager.hasUnviewedAlerts ? .red : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground).opacity(0.9))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(radius: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, -10) // Pushed down lower
            }

            // User Guide Overlay
            if showingInstructions && !preferencesManager.getUserHasCreatedReports() {
                UserGuideOverlay {
                    withAnimation {
                        showingInstructions = false
                        preferencesManager.setUserHasCreatedReports(true)
                    }
                }
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
            DispatchQueue.main.async {
                self.userLocation = location.coordinate

                // Auto-zoom to user location on first load only
                if !self.hasSetInitialLocation && (self.centerCoordinate.latitude == 0 && self.centerCoordinate.longitude == 0) {
                    self.centerCoordinate = location.coordinate
                    self.mapUpdateType = .userLocation
                    self.shouldForceMapUpdate = true
                    // Mark that we've set the initial location to prevent future auto-zooms
                    self.hasSetInitialLocation = true
                }

                self.alertManager.checkForNewAlerts(location)
                self.favoriteManager.checkForFavoriteAlerts()
            }
        }

        // Set up closures
        alertManager.onNewAlerts = { alerts in
            DispatchQueue.main.async {
                if let firstAlert = alerts.first {
                    self.showPersistentAlert(for: firstAlert.report, isFromFavorite: false)
                }
            }
        }

        favoriteManager.onNewFavoriteAlerts = { alerts in
            DispatchQueue.main.async {
                if let firstAlert = alerts.first {
                    self.showPersistentAlert(for: firstAlert.report, isFromFavorite: true, favoriteName: firstAlert.favoritePlace.name, favoriteDistance: firstAlert.distanceFromFavorite)
                }
            }
        }

        // Load initial data
        reportManager.fetchAllReports { success, message in
            if !success {
                showStatus(message, isError: true)
            } else {
                // Check for alerts after reports are loaded
                if self.currentMapRegion != nil {
                    self.checkAlertsForCurrentMapRegion()
                } else {
                    self.checkAlertsWithCurrentLocation()
                }
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
        mapUpdateType = .favorite
        shouldForceMapUpdate = true
        showStatus("\(preferencesManager.localizedString("showing")) \(favorite.name)", isError: false)

        // Then show favorite details
        selectedFavorite = favorite
        showingFavoriteDetails = true
    }

    private func getCurrentLocation() {
        locationManager.getLastLocation { location in
            DispatchQueue.main.async {
                if let location = location {
                    self.userLocation = location.coordinate
                    self.centerCoordinate = location.coordinate
                    self.mapUpdateType = .userLocation
                    self.shouldForceMapUpdate = true
                    // Keep the interaction flag true since user explicitly requested location
                    // This prevents unwanted auto-zooming while still allowing the requested zoom
                    self.userHasInteractedWithMap = true

                    self.locationManager.getLocationDescription(for: location) { description in
                        self.showStatus(description, isError: false)
                    }
                } else {
                    self.showStatus(self.preferencesManager.localizedString("unable_to_get_location"), isError: true)
                }
            }
        }
    }

    private func performSearch() {
        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Validate search query
        let validation = inputValidator.safeValidateSearchQuery(searchText)
        if !validation.isValid {
            showStatus(validation.error ?? "Invalid search query", isError: true)
            return
        }

        guard let validatedQuery = validation.sanitizedText else {
            showStatus("Failed to process search query", isError: true)
            return
        }

        isSearching = true
        showStatus(preferencesManager.localizedString("searching_address"), isError: false)

        locationManager.searchAddress(query: validatedQuery) { results in
            DispatchQueue.main.async {
                isSearching = false

                if let results = results, let firstResult = results.first {
                    searchResultLocation = firstResult.placemark.coordinate
                    centerCoordinate = firstResult.placemark.coordinate
                    mapUpdateType = .search
                    shouldForceMapUpdate = true

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
        mapUpdateType = .favorite
        shouldForceMapUpdate = true
        showStatus("\(preferencesManager.localizedString("showing")) \(favorite.name)", isError: false)
    }


    private func createReport(at location: CLLocationCoordinate2D) {
        // Validate coordinates
        do {
            let validatedLocation = try inputValidator.validateCoordinate(location)
            selectedLocation = validatedLocation
            showingReportInput = true
        } catch {
            showStatus("Invalid location coordinates", isError: true)
        }
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

        // Submit report to backend
        reportManager.submitReport(report) { success, message in
            if !success {
                showStatus(message, isError: true)
            }
        }

        // Delay alert checking to ensure user-created report tracking is properly saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            favoriteManager.checkForFavoriteAlerts()
        }

        showingReportInput = false
    }

    private func createFavorite(at location: CLLocationCoordinate2D) {
        // Validate coordinates
        do {
            let validatedLocation = try inputValidator.validateCoordinate(location)
            selectedLocation = validatedLocation
            showingFavoriteInput = true
        } catch {
            showStatus("Invalid location coordinates", isError: true)
        }
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
                if self.currentMapRegion != nil {
                    self.checkAlertsForCurrentMapRegion()
                } else {
                    self.checkAlertsWithCurrentLocation()
                }
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
            alertManager.checkForNewAlerts(location)
        } else {
            // Try to get current location
            locationManager.getLastLocation { location in
                if let location = location {
                    // AlertManager should handle its own thread safety, but ensure we don't modify ContentView state
                    self.alertManager.checkForNewAlerts(location)
                }
            }
        }
    }

    private func checkAlertsForCurrentMapRegion() {
        guard let region = currentMapRegion else { return }
        alertManager.checkForNewAlertsInRegion(region)
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

        // No silent mode override in MVP1

        // Get location name through reverse geocoding
        GeocodingService.shared.getAddress(from: report.location) { address in
            DispatchQueue.main.async {
                let reportAddress = address

                // Calculate distance with proper descriptive text
                if isFromFavorite, let favName = favoriteName, let favDistance = favoriteDistance {
                    locationName = favName
                    let distance = self.formatDistance(favDistance)
                    distanceText = "\(distance) \(self.preferencesManager.localizedString("from")) \(favName)"
                } else if let userLoc = self.userLocation {
                    let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                    let distance = userLocation.distance(from: reportLocation)
                    let formattedDistance = self.formatDistance(distance)
                    distanceText = "\(formattedDistance) \(self.preferencesManager.localizedString("from")) \(self.preferencesManager.localizedString("your_location"))"
                    locationName = "Unknown location"
                }

                // Create alert data
                let alertData = AlertNotificationData(
                    message: isFromFavorite ? self.preferencesManager.localizedString("safety_issue_near_favorite") : self.preferencesManager.localizedString("safety_issue_in_area"),
                    locationName: locationName,
                    distance: distanceText,
                    address: reportAddress,
                    reportId: report.id,
                    report: report
                )

                // Show persistent alert with animation
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.activeAlert = alertData
                    self.showingAlertNotification = true
                }
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
    let address: String
    let reportId: String
    let report: Report
}

// MARK: - Supporting Views
struct StatusCard: View {
    let message: String
    let isError: Bool
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .foregroundColor(isError ? .red : .secondary)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 4)
        .padding(.horizontal)
    }
}

struct UserGuideOverlay: View {
    let onDismiss: () -> Void
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var showingUserGuide = false

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
                    showingUserGuide = true
                }
                .foregroundColor(.blue)
                .font(.headline)
            }
            .padding(30)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)

            Spacer()
        }
        .background(Color(UIColor.label).opacity(0.3))
        .onTapGesture {
            onDismiss()
        }
        .sheet(isPresented: $showingUserGuide) {
            UserGuideView()
        }
    }
}

struct UserGuideView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Welcome Section
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text(preferencesManager.localizedString("app_name"))
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(preferencesManager.localizedString("anonymous_safety_reporting"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)

                    // 1. Enable Location Access
                    HowToStep(
                        icon: "location.fill",
                        title: preferencesManager.localizedString("enable_location_access"),
                        description: preferencesManager.localizedString("enable_location_description")
                    )

                    // 2. Smart Map Alerts
                    HowToStep(
                        icon: "map.fill",
                        title: preferencesManager.localizedString("map_viewport_alerts"),
                        description: preferencesManager.localizedString("map_viewport_alerts_description")
                    )

                    // 3. Report Safety Issues
                    HowToStep(
                        icon: "hand.tap.fill",
                        title: preferencesManager.localizedString("report_safety_issues"),
                        description: preferencesManager.localizedString("report_issues_description")
                    )

                    // 4. Add Favorite Places
                    HowToStep(
                        icon: "heart.fill",
                        title: preferencesManager.localizedString("add_favorite_places"),
                        description: preferencesManager.localizedString("add_favorites_description")
                    )

                    // 5. Secure Your App
                    HowToStep(
                        icon: "lock.shield.fill",
                        title: preferencesManager.localizedString("secure_your_app"),
                        description: preferencesManager.localizedString("secure_app_description")
                    )

                    // 6. Respond to Alerts
                    HowToStep(
                        icon: "exclamationmark.triangle.fill",
                        title: preferencesManager.localizedString("respond_to_alerts"),
                        description: preferencesManager.localizedString("respond_alerts_description")
                    )

                    // 7. View Recent Alerts
                    HowToStep(
                        icon: "clock.fill",
                        title: preferencesManager.localizedString("view_recent_alerts"),
                        description: preferencesManager.localizedString("recent_alerts_description")
                    )

                    // Privacy Note
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text(preferencesManager.localizedString("your_privacy_protected"))
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        Text(preferencesManager.localizedString("privacy_protection_details"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle(preferencesManager.localizedString("how_to_use"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.localizedString("done")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct HowToStep: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct AlertGuideSection: View {
    let icon: String
    let title: String
    let description: String
    let isImportant: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)

                Text(description)
                    .font(.body)
                    .fontWeight(isImportant ? .medium : .regular)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct GuideSection: View {
    let icon: String
    let title: String
    let description: String
    let isImportant: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    } // End of mainAppView
}

#Preview {
    ContentView()
}

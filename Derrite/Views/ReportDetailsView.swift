//  ReportDetailsView.swift
//  Derrite

import SwiftUI
import CoreLocation

struct ReportDetailsView: View {
    let report: Report
    let onClose: () -> Void

    @StateObject private var preferencesManager = PreferencesManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var favoriteManager = FavoriteManager.shared
    @State private var distanceInfo: String = ""
    @State private var userLocation: CLLocation?
    @State private var locationAddress: String = ""

    // Translation states
    @State private var translatedText: String = ""
    @State private var showingTranslation: Bool = false
    @State private var isTranslating: Bool = false
    @State private var translationError: String?
    @State private var autoTranslationCompleted: Bool = false
    @State private var showingEnlargedPhoto = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time Badge
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("\(preferencesManager.localizedString("reported")) \(report.timeAgo(preferencesManager: preferencesManager))")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemBlue).opacity(0.1))
                    .cornerRadius(12)

                    // Distance Information
                    if !distanceInfo.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(distanceInfo)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Photo (if available)
                    if let photo = report.photo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preferencesManager.localizedString("photo_evidence"))
                                .font(.headline)
                                .foregroundColor(.primary)

                            Button(action: {
                                showingEnlargedPhoto = true
                            }) {
                                Image(uiImage: photo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(12)
                                    .shadow(radius: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text(preferencesManager.currentLanguage == "es" ? "Toca para ampliar" : "Tap to enlarge")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .italic()
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(preferencesManager.localizedString("description"))
                                .font(.headline)
                                .foregroundColor(.primary)

                            Spacer()

                            // Translation button
                            if !report.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(action: {
                                    if showingTranslation {
                                        showingTranslation = false
                                    } else {
                                        translateText()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        if isTranslating {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: showingTranslation ? "eye" : "translate")
                                        }

                                        Text(showingTranslation ?
                                             preferencesManager.localizedString("show_original") :
                                             preferencesManager.localizedString("translate"))
                                            .font(.caption)
                                    }
                                }
                                .disabled(isTranslating)
                                .foregroundColor(.blue)
                            }
                        }

                        // Description text
                        VStack(alignment: .leading, spacing: 8) {
                            Text(showingTranslation && !translatedText.isEmpty ? translatedText : report.originalText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)

                            // Translation status/error
                            if isTranslating {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text(preferencesManager.localizedString("translating"))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            } else if let error = translationError {
                                Text(preferencesManager.localizedString("translation_error"))
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if showingTranslation && !translatedText.isEmpty {
                                Text("⚡ " + (preferencesManager.currentLanguage == "es" ? "Traducido" : "Translated"))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    // Location Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferencesManager.localizedString("location"))
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(locationAddress.isEmpty ? preferencesManager.localizedString("loading_address") : locationAddress)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                Text(formatCoordinates(report.location))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }

                    // Expiration Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferencesManager.localizedString("report_status"))
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack {
                            Circle()
                                .fill(report.isExpired ? Color.red : Color.green)
                                .frame(width: 8, height: 8)

                            Text(report.isExpired ? preferencesManager.localizedString("expired") : preferencesManager.localizedString("active"))
                                .font(.caption)
                                .foregroundColor(report.isExpired ? .red : .green)

                            Spacer()

                            if !report.isExpired {
                                Text("\(preferencesManager.localizedString("expires")): \(formatExpirationTime())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }

                    // Safety Notice
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.blue)
                            Text(preferencesManager.localizedString("privacy_notice"))
                                .font(.headline)
                                .foregroundColor(.primary)
                        }

                        Text(preferencesManager.localizedString("report_submitted_anonymously"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding()
                    .background(Color(UIColor.systemBlue).opacity(0.1))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(preferencesManager.localizedString("report"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.localizedString("close")) {
                        onClose()
                    }
                }
            }
        }
        .onAppear {
            calculateDistanceInfo()
            performAutoTranslation()
            loadLocationAddress()
        }
        .sheet(isPresented: $showingEnlargedPhoto) {
            if let photo = report.photo {
                EnlargedPhotoView(photo: photo)
            }
        }
    }

    // MARK: - Helper Methods
    private func calculateDistanceInfo() {
        let reportLocation = CLLocation(latitude: report.location.latitude, longitude: report.location.longitude)

        // Get current user location
        locationManager.getLastLocation { location in
            DispatchQueue.main.async {
                self.userLocation = location
                self.updateDistanceInfo(reportLocation: reportLocation, userLocation: location)
            }
        }
    }

    private func updateDistanceInfo(reportLocation: CLLocation, userLocation: CLLocation?) {
        var closestDistance: Double = Double.greatestFiniteMagnitude
        var closestName = ""
        var isFromFavorite = false

        // Check distance to favorites first
        for favorite in favoriteManager.favorites {
            let favoriteLocation = CLLocation(latitude: favorite.location.latitude, longitude: favorite.location.longitude)
            let distance = favoriteLocation.distance(from: reportLocation)

            if distance < closestDistance {
                closestDistance = distance
                closestName = favorite.name
                isFromFavorite = true
            }
        }

        // Check distance to user location
        if let userLoc = userLocation {
            let distanceFromUser = userLoc.distance(from: reportLocation)

            if distanceFromUser < closestDistance {
                closestDistance = distanceFromUser
                closestName = preferencesManager.localizedString("your_location")
                isFromFavorite = false
            }
        }

        // Only show distance if it's reasonable (within 50 miles)
        if closestDistance < 80467 { // 50 miles in meters
            let distanceText = formatDistance(closestDistance)
            distanceInfo = "\(distanceText) \(preferencesManager.localizedString("from")) \(closestName)"
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1609 { // Less than 1 mile
            let feet = Int(meters * 3.28084)
            return "\(feet) " + preferencesManager.localizedString("ft")
        } else {
            let miles = String(format: "%.1f", meters / 1609.0)
            return "\(miles) " + (miles == "1.0" ? preferencesManager.localizedString("mile") : preferencesManager.localizedString("miles"))
        }
    }

    private func formatCoordinates(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    private func formatExpirationTime() -> String {
        let expirationDate = Date(timeIntervalSince1970: report.expiresAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: expirationDate)
    }

    private func loadLocationAddress() {
        GeocodingService.shared.getAddress(from: report.location) { address in
            self.locationAddress = address
        }
    }

    // MARK: - Translation Methods
    private func translateText() {
        guard !isTranslating else { return }

        isTranslating = true
        translationError = nil

        Task {
            let result = await SimpleTranslationService.shared.translateUserContent(
                report.originalText,
                toCurrentLanguage: true
            )

            await MainActor.run {
                isTranslating = false

                switch result {
                case .success(let translation):
                    translatedText = translation
                    showingTranslation = true
                case .failure(let error):
                    translationError = preferencesManager.localizedString("translation_error")
                }
            }
        }
    }

    /// Automatically translates the report text if it's in a different language than the app
    private func performAutoTranslation() {
        guard !autoTranslationCompleted else { return }

        Task {
            let autoTranslated = await SimpleTranslationService.shared.autoTranslateToCurrentLanguage(report.originalText)

            await MainActor.run {
                autoTranslationCompleted = true

                // Only show auto-translation if it's different from the original
                if autoTranslated != report.originalText {
                    translatedText = autoTranslated
                    showingTranslation = true
                }
            }
        }
    }
}

// MARK: - Enlarged Photo View
struct EnlargedPhotoView: View {
    let photo: UIImage
    @Environment(\.presentationMode) var presentationMode
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                        .offset(x: offset.width, y: offset.height)
                        .scaleEffect(scale)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = max(1.0, min(scale * delta, 4.0))
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .background(Color.black)
        }
    }
}

#Preview {
    ReportDetailsView(
        report: Report(
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            originalText: "Sample safety report for preview",
            originalLanguage: "en",
            hasPhoto: false,
            expiresAt: Date().timeIntervalSince1970 + 3600
        ),
        onClose: {}
    )
}
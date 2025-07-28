//
//  SettingsView.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingAbout = false
    @State private var showingPrivacy = false
    
    var body: some View {
        NavigationView {
            List {
                // App Information Section
                Section {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text("Derrite")
                                .font(.headline)
                            Text(preferencesManager.localizedString("anonymous_safety_reporting"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text(preferencesManager.localizedString("version"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                
                // Language Section
                Section(preferencesManager.localizedString("language")) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        Text(preferencesManager.localizedString("app_language"))
                        
                        Spacer()
                        
                        Button(action: toggleLanguage) {
                            Text(preferencesManager.currentLanguage == "es" ? "Español" : "English")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Notifications Section
                Section(preferencesManager.localizedString("notifications")) {
                    NavigationLink(destination: SafetyAlertsSettingsView()) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(preferencesManager.localizedString("alerts"))
                                Text(preferencesManager.localizedString("get_notified_nearby_reports"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text(preferencesManager.enableSoundAlerts ? preferencesManager.localizedString("on") : preferencesManager.localizedString("off"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(preferencesManager.localizedString("vibration"))
                            Text(preferencesManager.localizedString("vibrate_for_alert_notifications"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $preferencesManager.enableVibration)
                            .labelsHidden()
                    }
                }
                
                // Privacy & Security Section
                Section(preferencesManager.localizedString("privacy_and_security")) {
                    Button(action: { showingPrivacy = true }) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(preferencesManager.localizedString("privacy_protection"))
                                    .foregroundColor(.primary)
                                Text(preferencesManager.localizedString("learn_how_data_protected"))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(preferencesManager.localizedString("location_privacy"))
                            Text(preferencesManager.localizedString("coordinates_automatically_fuzzed"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Image(systemName: "camera")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(preferencesManager.localizedString("photo_security"))
                            Text(preferencesManager.localizedString("exif_data_automatically_removed"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                // About Section
                Section(preferencesManager.localizedString("about")) {
                    Button(action: { showingAbout = true }) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            Text(preferencesManager.localizedString("about_derrite"))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(preferencesManager.localizedString("how_to_use"))
                            Text(preferencesManager.localizedString("long_press_map_to_report"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Debug Section (only in debug builds)
                #if DEBUG
                Section(preferencesManager.localizedString("debug")) {
                    Button(action: clearAllData) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 30)
                            
                            Text(preferencesManager.localizedString("clear_all_data"))
                                .foregroundColor(.red)
                        }
                    }
                }
                #endif
            }
            .navigationTitle(preferencesManager.localizedString("settings"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.localizedString("done")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyView()
        }
    }
    
    // MARK: - Actions
    private func toggleLanguage() {
        let newLanguage = preferencesManager.currentLanguage == "es" ? "en" : "es"
        preferencesManager.saveLanguage(newLanguage)
        preferencesManager.setLanguageChange(true)
    }
    
    private func clearAllData() {
        // Clear all stored data (debug only)
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        SecureStorage.shared.clearAllSecureData()
        
        // Reset preferences
        preferencesManager.setUserHasCreatedReports(false)
        preferencesManager.saveLanguage("en")
    }
}

// MARK: - About View
struct AboutView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // App Icon and Name
                    VStack {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(preferencesManager.localizedString("app_name"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(preferencesManager.localizedString("anonymous_safety_reporting"))
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    
                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text(preferencesManager.localizedString("about"))
                            .font(.headline)
                        
                        Text(preferencesManager.localizedString("derrite_description"))
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Text(preferencesManager.localizedString("features"))
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "shield.checkered", text: preferencesManager.localizedString("anonymous_reporting_no_personal_data"))
                            FeatureRow(icon: "location", text: preferencesManager.localizedString("location_privacy_coordinate_fuzzing"))
                            FeatureRow(icon: "camera", text: preferencesManager.localizedString("photo_security_exif_removal"))
                            FeatureRow(icon: "bell", text: preferencesManager.localizedString("realtime_alerts_nearby_reports"))
                            FeatureRow(icon: "star", text: preferencesManager.localizedString("monitor_favorite_locations"))
                            FeatureRow(icon: "globe", text: preferencesManager.localizedString("bilingual_support"))
                        }
                        
                        Text(preferencesManager.localizedString("security"))
                            .font(.headline)
                        
                        Text(preferencesManager.localizedString("privacy_top_priority"))
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                }
            }
            .navigationTitle(preferencesManager.localizedString("about"))
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

// MARK: - Privacy View
struct PrivacyView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(preferencesManager.localizedString("privacy_protection_title"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(preferencesManager.localizedString("privacy_security_fundamental"))
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        PrivacySection(
                            title: preferencesManager.localizedString("anonymous_reporting_title"),
                            description: preferencesManager.localizedString("anonymous_reporting_desc")
                        )
                        
                        PrivacySection(
                            title: preferencesManager.localizedString("location_privacy_title"),
                            description: preferencesManager.localizedString("location_privacy_desc")
                        )
                        
                        PrivacySection(
                            title: preferencesManager.localizedString("photo_security_title"),
                            description: preferencesManager.localizedString("photo_security_desc")
                        )
                        
                        PrivacySection(
                            title: preferencesManager.localizedString("local_data_storage"),
                            description: preferencesManager.localizedString("local_data_storage_desc")
                        )
                        
                        PrivacySection(
                            title: preferencesManager.localizedString("no_tracking"),
                            description: preferencesManager.localizedString("no_tracking_desc")
                        )
                        
                        PrivacySection(
                            title: preferencesManager.localizedString("secure_communication"),
                            description: preferencesManager.localizedString("secure_communication_desc")
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle(preferencesManager.localizedString("privacy"))
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

// MARK: - Helper Views
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

struct PrivacySection: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(.green)
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    SettingsView()
}
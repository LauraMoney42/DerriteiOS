//  SafetyAlertsSettingsView.swift
//  Derrite

import SwiftUI

struct SafetyAlertsSettingsView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode

    private let distanceOptions: [Double] = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0]

    var body: some View {
        NavigationView {
            List {
                // Information Section - moved to top
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(preferencesManager.localizedString("how_it_works"))
                                .font(.headline)
                        }

                        Text(preferencesManager.localizedString("emergency_alerts_explanation"))
                            .font(.body)
                            .foregroundColor(.primary)


                        Text(preferencesManager.localizedString("reports_expire_8_hours"))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding(.vertical, 4)
                }

                // Sound Alerts Section
                Section(preferencesManager.localizedString("sound")) {
                    HStack {
                        Image(systemName: "speaker.2.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)

                        VStack(alignment: .leading) {
                            Text(preferencesManager.localizedString("sound_alerts"))
                            Text(preferencesManager.localizedString("play_sound_when_receiving"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Toggle("", isOn: $preferencesManager.enableSoundAlerts)
                            .labelsHidden()
                    }
                }

                // Vibration Section
                Section(preferencesManager.localizedString("vibration")) {
                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                            .frame(width: 30)

                        VStack(alignment: .leading) {
                            Text(preferencesManager.localizedString("vibration"))
                            Text(preferencesManager.localizedString("vibrate_for_alerts"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Toggle("", isOn: $preferencesManager.enableVibration)
                            .labelsHidden()
                    }
                }

                // Notification Distance Section
                Section(footer: Text(preferencesManager.localizedString("choose_notification_distance"))) {
                    Text(preferencesManager.localizedString("notification_distance"))
                        .font(.headline)
                        .padding(.vertical, 4)

                    ForEach(distanceOptions, id: \.self) { distance in
                        Button(action: {
                            preferencesManager.alertDistanceMiles = distance
                        }) {
                            HStack {
                                Image(systemName: preferencesManager.alertDistanceMiles == distance ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(preferencesManager.alertDistanceMiles == distance ? .blue : .gray)
                                    .frame(width: 30)

                                Text(formatDistance(distance))
                                    .foregroundColor(.primary)

                                Spacer()

                                if preferencesManager.alertDistanceMiles == distance {
                                    Text(preferencesManager.localizedString("selected"))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

            }
            .navigationTitle(preferencesManager.localizedString("alert_settings"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.localizedString("done")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func formatDistance(_ distance: Double) -> String {
        if distance == 1.0 {
            return "1 " + preferencesManager.localizedString("mile")
        } else if distance < 1.0 {
            return String(format: "%.1f ", distance) + preferencesManager.localizedString("mile")
        } else {
            return "\(Int(distance)) " + preferencesManager.localizedString("miles")
        }
    }
}

#Preview {
    SafetyAlertsSettingsView()
}
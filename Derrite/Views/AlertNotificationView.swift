//  AlertNotificationView.swift
//  Derrite

import SwiftUI
import AVFoundation
import AudioToolbox

struct AlertNotificationView: View {
    let alertMessage: String
    let reportLocation: String
    let distance: String
    let address: String
    let report: Report
    let onDismiss: () -> Void
    let onViewDetails: (Report) -> Void

    @StateObject private var preferencesManager = PreferencesManager.shared

    var body: some View {
        // Alert notification card without VStack wrapper
        VStack(spacing: 12) {
            // Alert header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(alertMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)

                    if !distance.isEmpty {
                        Text(distance)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }

            // Report details
            VStack(alignment: .leading, spacing: 8) {
                Text(report.originalText)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                if !address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons
            HStack(spacing: 12) {
                Spacer()

                Button(action: {
                    onViewDetails(report)
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text(preferencesManager.currentLanguage == "es" ? "Ver detalles" : "View Details")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.systemBlue).opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.9))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.6), lineWidth: 2)
        )
        .shadow(radius: 12)
        .padding(.horizontal, 16)
        .padding(.top, 50) // Add top padding to ensure it's below the status bar
        .onAppear {
            // Just play a simple notification sound
            AudioServicesPlaySystemSound(1007) // Pleasant notification sound
        }
    }
}
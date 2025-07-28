//
//  AlertNotificationView.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import SwiftUI
import AVFoundation
import AudioToolbox
import CoreLocation

struct AlertNotificationView: View {
    let alertMessage: String
    let reportLocation: String
    let distance: String
    let report: Report
    let shouldOverrideSilent: Bool
    let onDismiss: () -> Void
    let onViewDetails: (Report) -> Void
    
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isAlarmPlaying = false
    @State private var audioSession: AVAudioSession?
    
    var body: some View {
        VStack(spacing: 0) {
            // Alert notification card
            VStack(spacing: 12) {
                // Alert header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    
                    Text(preferencesManager.currentLanguage == "es" ? "Alerta de Seguridad" : "Safety Alert")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    // Dismiss button (X)
                    Button(action: {
                        stopAlarm()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                
                // Alert message
                VStack(alignment: .leading, spacing: 8) {
                    Text(preferencesManager.currentLanguage == "es" ? 
                         "Problema de seguridad reportado cerca de:" :
                         "Safety issue reported near:")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text(reportLocation)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(distance.isEmpty ? "" : "\(distance) away")
                        .font(.body)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: {
                        stopAlarm()
                    }) {
                        HStack {
                            Image(systemName: isAlarmPlaying ? "speaker.slash" : "speaker")
                                .font(.caption)
                            Text(isAlarmPlaying ? 
                                 (preferencesManager.currentLanguage == "es" ? "Silenciar" : "Mute") :
                                 (preferencesManager.currentLanguage == "es" ? "Silenciado" : "Muted"))
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isAlarmPlaying ? Color.red.opacity(0.8) : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    
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
                        .background(Color.blue.opacity(0.8))
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
            
            Spacer()
        }
        .onAppear {
            startAlarm()
        }
        .onDisappear {
            stopAlarm()
        }
    }
    
    // MARK: - Alarm Functions
    private func startAlarm() {
        guard preferencesManager.enableSoundAlerts else { return }
        
        // Set playing flag first
        isAlarmPlaying = true
        
        // Only setup special audio session if this specific alert should override silent mode
        if shouldOverrideSilent {
            setupAudioSession()
        }
        
        // Start playing sound
        playAlarmSound()
    }
    
    private func stopAlarm() {
        // Stop playing flag first to stop repeating timer
        isAlarmPlaying = false
        
        // Stop any audio player
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Restore audio session if it was modified
        if shouldOverrideSilent {
            restoreAudioSession()
        }
    }
    
    private func setupAudioSession() {
        guard shouldOverrideSilent else { return }
        
        do {
            audioSession = AVAudioSession.sharedInstance()
            
            // Configure audio session to bypass silent mode for emergency alerts
            try audioSession?.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession?.setActive(true)
            
            print("🔊 Emergency alert audio session activated - will bypass silent mode")
        } catch {
            print("⚠️ Failed to setup emergency audio session: \(error)")
        }
    }
    
    private func restoreAudioSession() {
        guard let audioSession = audioSession else { return }
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("🔇 Emergency alert audio session deactivated")
        } catch {
            print("⚠️ Failed to restore audio session: \(error)")
        }
        
        self.audioSession = nil
    }
    
    private func playAlarmSound() {
        // Use iPhone classic alarm sound (1013) - this is the classic beeping alarm
        AudioServicesPlaySystemSound(1013) // iPhone classic alarm sound
        
        // Add vibration for additional feedback
        if preferencesManager.enableVibration {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        
        // Repeat the sound every 2 seconds while alarm is active
        if isAlarmPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.isAlarmPlaying {
                    self.playAlarmSound()
                }
            }
        }
    }
    
    private func playEmergencyAlarm() {
        // Create a custom alarm tone programmatically
        guard let url = createAlarmTone() else {
            // Fallback to system sound if tone creation fails
            AudioServicesPlaySystemSound(1011) // More urgent/alarming sound
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 0 // Play once, we'll repeat via timer
            audioPlayer?.volume = 1.0 // Full volume
            audioPlayer?.play()
        } catch {
            print("⚠️ Failed to play emergency alarm: \(error)")
            // Fallback to system sound
            AudioServicesPlaySystemSound(1011) // More urgent/alarming sound
        }
    }
    
    private func createAlarmTone() -> URL? {
        // Create a simple alarm tone in memory
        // This creates a short beeping sound programmatically
        let sampleRate: Double = 44100
        let duration: Double = 0.5
        let frequency: Double = 1000 // 1kHz tone
        
        let frameCount = Int(sampleRate * duration)
        let samples = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { samples.deallocate() }
        
        for i in 0..<frameCount {
            let sample = sin(2.0 * Double.pi * frequency * Double(i) / sampleRate)
            samples[i] = Float(sample * 0.5) // 50% volume to avoid distortion
        }
        
        // Create audio file URL in temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("emergency_alarm.wav")
        
        // For now, we'll use a system sound as creating WAV files programmatically is complex
        // In a production app, you'd include a custom alarm.wav file in the bundle
        return nil // This will trigger the fallback to system sound
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea() // Simulate map background
        
        AlertNotificationView(
            alertMessage: "Safety issue reported",
            reportLocation: "Downtown Coffee Shop",
            distance: "0.3 miles",
            report: Report(
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                originalText: "Test report",
                originalLanguage: "en",
                hasPhoto: false,
                expiresAt: Date().timeIntervalSince1970 + 8*3600,
                category: .safety
            ),
            shouldOverrideSilent: true,
            onDismiss: {},
            onViewDetails: { _ in }
        )
    }
}
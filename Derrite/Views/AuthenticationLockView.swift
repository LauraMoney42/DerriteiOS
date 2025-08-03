//  AuthenticationLockView.swift
//  Derrite

import SwiftUI

struct AuthenticationLockView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var enteredPIN = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var failedAttempts = 0
    @State private var showingBiometricPrompt = false
    @State private var isAuthenticating = false
    @State private var hasAttemptedBiometricAuth = false
    @State private var showPinFallback = false

    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Title
                VStack(spacing: 16) {
                    Text("Alerta")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                // Authentication Method
                VStack(spacing: 24) {
                    if authManager.isBiometricsEnabled && !showPinFallback {
                        biometricAuthenticationView
                        
                        // Always show PIN option if PIN is available (not just on error)
                        if authManager.hasPinAvailable {
                            VStack(spacing: 16) {
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                
                                Button(action: {
                                    withAnimation {
                                        showPinFallback = true
                                        showError = false
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .font(.system(size: 16))
                                        Text(preferencesManager.currentLanguage == "es" ?
                                             "Usar PIN" :
                                             "Use PIN")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.white.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                    } 
                    
                    if (authManager.isPinEnabled || authManager.hasPinAvailable || showPinFallback) && (showPinFallback || !authManager.isBiometricsEnabled) {
                        if showPinFallback && authManager.isBiometricsEnabled {
                            // Show back to Face ID button
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        showPinFallback = false
                                        hasAttemptedBiometricAuth = false
                                        showError = false
                                        enteredPIN = ""
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.left")
                                        Text(preferencesManager.currentLanguage == "es" ?
                                             "Volver a Face ID" :
                                             "Back to Face ID")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            .padding(.bottom, 10)
                        }
                        
                        pinAuthenticationView
                        
                        // Show Face ID retry option if available
                        if authManager.isBiometricsEnabled && showPinFallback {
                            VStack(spacing: 16) {
                                Divider()
                                    .background(Color.white.opacity(0.3))
                                
                                Button(action: {
                                    withAnimation {
                                        showPinFallback = false
                                        hasAttemptedBiometricAuth = false
                                        showError = false
                                        enteredPIN = ""
                                    }
                                    // Trigger Face ID after animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        attemptBiometricAuthentication()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: authManager.biometricType() == .faceID ? "faceid" : "touchid")
                                            .font(.system(size: 16))
                                        Text(preferencesManager.currentLanguage == "es" ?
                                             "Intentar \(authManager.biometricTypeDisplayName)" :
                                             "Try \(authManager.biometricTypeDisplayName)")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.white.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Footer
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.white.opacity(0.7))
                        Text(preferencesManager.currentLanguage == "es" ?
                             "Tus datos están seguros" :
                             "Your data is secure")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text(preferencesManager.currentLanguage == "es" ?
                         "Toda la información se almacena localmente" :
                         "All information is stored locally")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Give users time to see the PIN option before auto-triggering Face ID
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if authManager.isBiometricsEnabled && !hasAttemptedBiometricAuth && !showPinFallback {
                    hasAttemptedBiometricAuth = true
                    attemptBiometricAuthentication()
                }
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    private var biometricAuthenticationView: some View {
        VStack(spacing: 20) {
            Text(preferencesManager.currentLanguage == "es" ?
                 "Desbloquear con \(authManager.biometricTypeDisplayName)" :
                 "Unlock with \(authManager.biometricTypeDisplayName)")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Button(action: attemptBiometricAuthentication) {
                VStack(spacing: 12) {
                    Image(systemName: authManager.biometricType() == .faceID ? "faceid" : "touchid")
                        .font(.system(size: 50))
                        .foregroundColor(.white)

                    Text(preferencesManager.currentLanguage == "es" ?
                         "Tocar para autenticar" :
                         "Tap to authenticate")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(width: 200, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var pinAuthenticationView: some View {
        VStack(spacing: 20) {
            Text(preferencesManager.currentLanguage == "es" ?
                 "Ingresa tu PIN" :
                 "Enter your PIN")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)

            // PIN Display
            HStack(spacing: 16) {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(index < enteredPIN.count ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .scaleEffect(index < enteredPIN.count ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: enteredPIN.count)
                }
            }
            .padding(.vertical, 10)

            // Number Pad
            VStack(spacing: 16) {
                ForEach(0..<3) { row in
                    HStack(spacing: 24) {
                        ForEach(1..<4) { col in
                            let number = row * 3 + col
                            NumberButton(number: "\(number)") {
                                addDigit("\(number)")
                            }
                        }
                    }
                }

                // Bottom row: blank, 0, delete
                HStack(spacing: 24) {
                    // Blank space
                    Color.clear
                        .frame(width: 60, height: 60)

                    // Zero
                    NumberButton(number: "0") {
                        addDigit("0")
                    }

                    // Delete
                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                }
            }

            if failedAttempts > 0 {
                Text(preferencesManager.currentLanguage == "es" ?
                     "PIN incorrecto. Intentos fallidos: \(failedAttempts)" :
                     "Incorrect PIN. Failed attempts: \(failedAttempts)")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.top, 10)
            }
            
        }
    }

    private func attemptBiometricAuthentication() {
        guard !showingBiometricPrompt && !isAuthenticating else { 
            return 
        }
        
        isAuthenticating = true
        showingBiometricPrompt = true
        
        authManager.authenticateWithBiometrics { result in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.showingBiometricPrompt = false
                
                switch result {
                case .success:
                    self.onUnlock()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    // Keep hasAttemptedBiometricAuth = true so PIN fallback shows
                }
            }
        }
    }

    private func addDigit(_ digit: String) {
        guard enteredPIN.count < 8 && !isAuthenticating else { return }
        enteredPIN += digit

        // Auto-authenticate when PIN is long enough
        if enteredPIN.count >= 4 {
            authenticateWithPIN()
        }
    }

    private func deleteDigit() {
        if !enteredPIN.isEmpty {
            enteredPIN.removeLast()
        }
    }

    private func authenticateWithPIN() {
        guard !isAuthenticating else { return }
        
        // Check if PIN is available
        if !authManager.hasPinAvailable {
            errorMessage = preferencesManager.currentLanguage == "es" ?
                "No hay PIN configurado. Usa Face ID o configura un PIN en Configuración." :
                "No PIN set up. Use Face ID or set up a PIN in Settings."
            showError = true
            return
        }
        
        isAuthenticating = true
        
        authManager.authenticateWithPIN(enteredPIN) { result in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                
                switch result {
                case .success:
                    self.onUnlock()
                case .failure:
                    self.failedAttempts += 1
                    self.enteredPIN = ""

                    // Add haptic feedback for failed attempt
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()

                    if self.failedAttempts >= 5 {
                        self.errorMessage = self.preferencesManager.currentLanguage == "es" ?
                            "Demasiados intentos fallidos. Considera restablecer la app." :
                            "Too many failed attempts. Consider resetting the app."
                        self.showError = true
                    }
                }
            }
        }
    }
}

struct NumberButton: View {
    let number: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: number)
    }
}

#Preview {
    AuthenticationLockView {
        // Unlocked
    }
}
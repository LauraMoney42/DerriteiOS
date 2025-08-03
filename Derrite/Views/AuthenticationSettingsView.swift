//  AuthenticationSettingsView.swift
//  Derrite

import SwiftUI

struct AuthenticationSettingsView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedMethod: AuthenticationManager.AuthenticationMethod
    @State private var selectedAutoLock: AuthenticationManager.AutoLockInterval
    @State private var showingPINSetup = false
    @State private var showingError = false
    @State private var errorMessage = ""

    init() {
        let authManager = AuthenticationManager.shared
        _selectedMethod = State(initialValue: authManager.authenticationMethod)
        _selectedAutoLock = State(initialValue: authManager.autoLockInterval)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.blue)
                            Text(preferencesManager.currentLanguage == "es" ?
                                 "Seguridad de la App" :
                                 "App Security")
                                .font(.headline)
                        }

                        Text(preferencesManager.currentLanguage == "es" ?
                             "Protege tus reportes de seguridad con autenticación local. Todos los datos permanecen en tu dispositivo." :
                             "Protect your safety reports with local authentication. All data stays on your device.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                Section(preferencesManager.currentLanguage == "es" ?
                       "Método de Autenticación" :
                       "Authentication Method") {

                    ForEach(AuthenticationManager.AuthenticationMethod.allCases, id: \.self) { method in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    methodIcon(for: method)
                                    Text(method.localizedDisplayName(using: preferencesManager))
                                        .font(.body)
                                }

                                if method == .biometric && !authManager.isBiometricAuthenticationAvailable() {
                                    Text(preferencesManager.currentLanguage == "es" ?
                                         "No disponible en este dispositivo" :
                                         "Not available on this device")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                if method == .biometric && authManager.isBiometricAuthenticationAvailable() {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(authManager.biometricTypeDisplayName)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        if !authManager.hasPinAvailable {
                                            Text(preferencesManager.currentLanguage == "es" ?
                                                 "Requiere PIN como respaldo" :
                                                 "Requires PIN fallback")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        } else {
                                            Text(preferencesManager.currentLanguage == "es" ?
                                                 "PIN configurado ✓" :
                                                 "PIN configured ✓")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }

                            Spacer()

                            if selectedMethod == method {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if method == .biometric && !authManager.isBiometricAuthenticationAvailable() {
                                return // Don't allow selection if not available
                            }
                            
                            if method == .biometric && !authManager.hasPinAvailable {
                                // Show PIN setup first for Face ID
                                errorMessage = preferencesManager.currentLanguage == "es" ?
                                    "Face ID requiere un PIN como respaldo. Configurando PIN..." :
                                    "Face ID requires a PIN fallback. Setting up PIN..."
                                showingError = true
                                selectedMethod = .pin // Automatically switch to PIN setup
                                return
                            }
                            
                            selectedMethod = method
                        }
                        .disabled(method == .biometric && !authManager.isBiometricAuthenticationAvailable())
                    }
                }

                if selectedMethod != .none {
                    Section(preferencesManager.currentLanguage == "es" ?
                           "Bloqueo Automático" :
                           "Auto-Lock") {

                        ForEach(AuthenticationManager.AutoLockInterval.allCases, id: \.self) { interval in
                            HStack {
                                Text(interval.localizedDisplayName(using: preferencesManager))
                                Spacer()
                                if selectedAutoLock == interval {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAutoLock = interval
                            }
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text(preferencesManager.currentLanguage == "es" ?
                                     "Privacidad" :
                                     "Privacy")
                                    .font(.headline)
                            }

                            Text(preferencesManager.currentLanguage == "es" ?
                                 "• Todos los datos de autenticación se almacenan localmente en tu dispositivo\n• No se envía información biométrica o PIN a ningún servidor\n• Solo tú puedes acceder a tus reportes de seguridad" :
                                 "• All authentication data is stored locally on your device\n• No biometric or PIN information is sent to any server\n• Only you can access your safety reports")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(preferencesManager.currentLanguage == "es" ?
                           "Autenticación" :
                           "Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(preferencesManager.currentLanguage == "es" ?
                           "Cancelar" :
                           "Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.currentLanguage == "es" ?
                           "Guardar" :
                           "Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingPINSetup) {
            PINSetupView { success in
                showingPINSetup = false
                if success {
                    // Check if user was trying to set up Face ID
                    if selectedMethod == .biometric && authManager.isBiometricAuthenticationAvailable() {
                        // Small delay to ensure PIN is fully saved
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.authManager.enableBiometricWithPinFallback { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success:
                                        self.presentationMode.wrappedValue.dismiss()
                                    case .failure(let error):
                                        self.errorMessage = error.localizedDescription
                                        self.showingError = true
                                    }
                                }
                            }
                        }
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    private func methodIcon(for method: AuthenticationManager.AuthenticationMethod) -> some View {
        Group {
            switch method {
            case .none:
                Image(systemName: "lock.open")
                    .foregroundColor(.gray)
            case .biometric:
                Image(systemName: authManager.biometricType() == .faceID ? "faceid" : "touchid")
                    .foregroundColor(authManager.isBiometricAuthenticationAvailable() ? .blue : .gray)
            case .pin:
                Image(systemName: "key")
                    .foregroundColor(.blue)
            }
        }
    }

    private func saveSettings() {
        // Save auto-lock interval
        authManager.autoLockInterval = selectedAutoLock

        // If method hasn't changed, just dismiss
        if selectedMethod == authManager.authenticationMethod {
            presentationMode.wrappedValue.dismiss()
            return
        }

        // Handle method change
        if selectedMethod == .biometric {
            // For biometric, use the special method that preserves PIN
            authManager.enableBiometricWithPinFallback { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        if case .noPinFallback = error {
                            // Show PIN setup first
                            self.errorMessage = self.preferencesManager.currentLanguage == "es" ?
                                "Face ID requiere un PIN como respaldo. Configurando PIN..." :
                                "Face ID requires a PIN fallback. Setting up PIN..."
                            self.showingError = true
                            self.selectedMethod = .pin // Switch to PIN setup
                        } else {
                            self.errorMessage = error.localizedDescription
                            self.showingError = true
                            self.selectedMethod = self.authManager.authenticationMethod
                        }
                    }
                }
            }
        } else {
            // For non-biometric methods, use the regular method
            authManager.setAuthenticationMethod(selectedMethod) { result in
                DispatchQueue.main.async {
                    switch result {
                case .success:
                    if selectedMethod == .pin {
                        // Show PIN setup
                        showingPINSetup = true
                    } else {
                        // Dismiss for .none
                        presentationMode.wrappedValue.dismiss()
                    }

                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                    // Reset selection on error
                    selectedMethod = authManager.authenticationMethod
                }
            }
            }
        }
    }
}

struct PINSetupView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var showError = false
    @State private var errorMessage = ""

    let onComplete: (Bool) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(preferencesManager.currentLanguage == "es" ?
                       "Configurar PIN" :
                       "Set Up PIN") {

                    SecureField(preferencesManager.currentLanguage == "es" ?
                               "Ingresa PIN (4-8 dígitos)" :
                               "Enter PIN (4-8 digits)", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)

                    SecureField(preferencesManager.currentLanguage == "es" ?
                               "Confirma PIN" :
                               "Confirm PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(preferencesManager.currentLanguage == "es" ?
                                 "Importante" :
                                 "Important")
                                .font(.headline)
                        }

                        Text(preferencesManager.currentLanguage == "es" ?
                             "Si olvidas tu PIN, necesitarás desinstalar y reinstalar la app, lo que eliminará todos tus datos locales." :
                             "If you forget your PIN, you'll need to uninstall and reinstall the app, which will delete all your local data.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(preferencesManager.currentLanguage == "es" ?
                           "PIN de Seguridad" :
                           "Security PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(preferencesManager.currentLanguage == "es" ?
                           "Cancelar" :
                           "Cancel") {
                        onComplete(false)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.currentLanguage == "es" ?
                           "Guardar" :
                           "Save") {
                        setupPIN()
                    }
                    .disabled(!isValidPIN)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }

    private var isValidPIN: Bool {
        return pin.count >= 4 && pin.count <= 8 && pin == confirmPin && pin.allSatisfy(\.isNumber)
    }

    private func setupPIN() {
        AuthenticationManager.shared.setPIN(pin) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    onComplete(true)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    AuthenticationSettingsView()
}
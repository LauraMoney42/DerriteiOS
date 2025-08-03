//  FavoriteInputView.swift
//  Derrite

import SwiftUI
import CoreLocation

struct FavoriteInputView: View {
    let location: CLLocationCoordinate2D
    let onSubmit: (String, String) -> Void
    let onCancel: () -> Void

    @StateObject private var preferencesManager = PreferencesManager.shared
    private let locationManager = LocationManager.shared
    private let inputValidator = InputValidator.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var favoriteName = ""
    @State private var favoriteDescription = ""
    @State private var isLoadingAddress = true
    @State private var locationAddress = ""
    @State private var validationError: String?
    @State private var showingValidationError = false

    private var isFormValid: Bool {
        // Only check if name is not empty for enabling the button
        return !favoriteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("❤️")
                                .font(.headline)
                            Text(preferencesManager.currentLanguage == "es" ? "Agregar a Favoritos" : "Add to Favorites")
                                .font(.headline)
                        }

                        if isLoadingAddress {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(preferencesManager.currentLanguage == "es" ? "Buscando dirección..." : "Finding address...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(locationAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(preferencesManager.currentLanguage == "es" ? "Detalles" : "Details") {
                    TextField(
                        preferencesManager.currentLanguage == "es" ? "Nombre del lugar" : "Place name",
                        text: $favoriteName
                    )
                    .textInputAutocapitalization(.words)
                    .onSubmit {
                        // Move focus to description field or dismiss keyboard if description is not empty
                        hideKeyboard()
                    }
                    .onChange(of: favoriteName) { _, newValue in
                        // Limit characters
                        if newValue.count > inputValidator.maxFavoriteNameLen {
                            favoriteName = String(newValue.prefix(inputValidator.maxFavoriteNameLen))
                        }

                        // Clear validation error when user starts typing
                        if showingValidationError {
                            showingValidationError = false
                            validationError = nil
                        }
                    }

                    TextField(
                        preferencesManager.currentLanguage == "es" ? "Descripción (opcional)" : "Description (optional)",
                        text: $favoriteDescription,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                    .onSubmit {
                        hideKeyboard()
                    }
                    .onChange(of: favoriteDescription) { _, newValue in
                        // Limit characters
                        if newValue.count > inputValidator.maxFavoriteDescLen {
                            favoriteDescription = String(newValue.prefix(inputValidator.maxFavoriteDescLen))
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.blue)
                            Text(preferencesManager.currentLanguage == "es" ? "Alertas" : "Alerts")
                                .font(.headline)
                        }

                        Text(preferencesManager.currentLanguage == "es" ?
                             "Recibirás notificaciones cuando se reporten problemas de seguridad cerca de este lugar favorito." :
                             "You'll receive notifications when safety issues are reported near this favorite place.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text(preferencesManager.currentLanguage == "es" ? "Ubicación" : "Location")
                                .font(.headline)
                        }

                        Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textSelection(.enabled)

                        Text(preferencesManager.currentLanguage == "es" ?
                             "Las coordenadas exactas se guardan solo localmente." :
                             "Exact coordinates are stored locally only.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(preferencesManager.currentLanguage == "es" ? "Nuevo Favorito" : "New Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(preferencesManager.currentLanguage == "es" ? "Cancelar" : "Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.currentLanguage == "es" ? "Guardar" : "Save") {
                        submitFavorite()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadLocationAddress()
        }
        .alert("Validation Error", isPresented: $showingValidationError) {
            Button("OK") {
                showingValidationError = false
                validationError = nil
            }
        } message: {
            Text(validationError ?? "Invalid input")
        }
    }

    // MARK: - Helper Methods
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func submitFavorite() {
        // Dismiss keyboard first
        hideKeyboard()
        
        // Validate favorite name
        let nameValidation = inputValidator.safeValidateFavoriteName(favoriteName)
        if !nameValidation.isValid {
            validationError = nameValidation.error
            showingValidationError = true
            return
        }

        // Validate description if provided
        var validatedDescription = ""
        if !favoriteDescription.isEmpty {
            let descValidation = inputValidator.safeValidateFavoriteDescription(favoriteDescription)
            if !descValidation.isValid {
                validationError = descValidation.error
                showingValidationError = true
                return
            }
            validatedDescription = descValidation.sanitizedDescription ?? ""
        }

        guard let validatedName = nameValidation.sanitizedName else {
            validationError = "Failed to process favorite name"
            showingValidationError = true
            return
        }

        onSubmit(validatedName, validatedDescription)
    }

    private func loadLocationAddress() {
        GeocodingService.shared.getAddress(from: location) { address in
            DispatchQueue.main.async {
                self.isLoadingAddress = false
                self.locationAddress = address

                // Auto-fill name if not already set and address doesn't look like coordinates
                if self.favoriteName.isEmpty && !address.contains(",") {
                    // Try to extract a meaningful name from the address
                    let components = address.components(separatedBy: ", ")
                    if let firstComponent = components.first, !firstComponent.isEmpty {
                        self.favoriteName = firstComponent
                    }
                }
            }
        }
    }
}

#Preview {
    FavoriteInputView(
        location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        onSubmit: { _, _ in },
        onCancel: {}
    )
}
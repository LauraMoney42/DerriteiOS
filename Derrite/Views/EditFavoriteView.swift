//  EditFavoriteView.swift
//  Derrite

import SwiftUI
import CoreLocation

struct EditFavoriteView: View {
    let favorite: FavoritePlace
    let onSave: (FavoritePlace) -> Void
    let onCancel: () -> Void

    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var favoriteName: String
    @State private var favoriteDescription: String
    @State private var enableSafetyAlerts: Bool
    @State private var alertDistance: Double
    @State private var address: String = ""
    @State private var isLoadingAddress = true

    private let alertDistanceOptions: [Double] = [804.5, 1609.0, 3218.0, 4827.0, 8047.0] // 0.5, 1, 2, 3, 5 miles

    init(favorite: FavoritePlace, onSave: @escaping (FavoritePlace) -> Void, onCancel: @escaping () -> Void) {
        self.favorite = favorite
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize state variables
        self._favoriteName = State(initialValue: favorite.name)
        self._favoriteDescription = State(initialValue: favorite.description)
        self._enableSafetyAlerts = State(initialValue: favorite.enableSafetyAlerts)
        self._alertDistance = State(initialValue: favorite.alertDistance)
    }

    private var isFormValid: Bool {
        !favoriteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("❤️")
                                .font(.headline)
                            Text(preferencesManager.currentLanguage == "es" ? "Editar favorito" : "Edit Favorite")
                                .font(.headline)
                        }

                        if isLoadingAddress {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading address...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text(address.isEmpty ? formatCoordinates(favorite.location) : address)
                                .font(.caption)
                                .foregroundColor(.gray)
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

                    TextField(
                        preferencesManager.currentLanguage == "es" ? "Descripción (opcional)" : "Description (optional)",
                        text: $favoriteDescription,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                }

                Section(preferencesManager.currentLanguage == "es" ? "Alertas" : "Alerts") {
                    Toggle(preferencesManager.currentLanguage == "es" ? "Alertas de seguridad" : "Safety Alerts", isOn: $enableSafetyAlerts)

                    if enableSafetyAlerts {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preferencesManager.currentLanguage == "es" ? "Distancia de alerta" : "Alert Distance")
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Picker(preferencesManager.currentLanguage == "es" ? "Distancia" : "Distance", selection: $alertDistance) {
                                ForEach(alertDistanceOptions, id: \.self) { distance in
                                    Text(formatAlertDistance(distance)).tag(distance)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())

                            Text(preferencesManager.currentLanguage == "es" ?
                                 "Recibirás notificaciones cuando se reporten problemas de seguridad dentro de esta distancia de este lugar." :
                                 "You'll receive notifications when safety issues are reported within this distance of this location.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text(preferencesManager.currentLanguage == "es" ? "Ubicación" : "Location")
                                .font(.headline)
                        }

                        Text(formatCoordinates(favorite.location))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textSelection(.enabled)

                        Text(preferencesManager.currentLanguage == "es" ?
                             "Las coordenadas están difuminadas por privacidad y no se pueden editar." :
                             "Coordinates are fuzzed for privacy and cannot be edited.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.blue)
                            Text(preferencesManager.currentLanguage == "es" ? "Privacidad" : "Privacy")
                                .font(.headline)
                        }

                        Text(preferencesManager.currentLanguage == "es" ?
                             "Todos los cambios se guardan solo localmente en tu dispositivo." :
                             "All changes are saved locally on your device only.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(preferencesManager.currentLanguage == "es" ? "Editar" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(preferencesManager.currentLanguage == "es" ? "Cancelar" : "Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.currentLanguage == "es" ? "Guardar" : "Save") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadAddress()
        }
    }

    // MARK: - Actions
    private func saveChanges() {
        let updatedFavorite = FavoritePlace(
            id: favorite.id,
            name: favoriteName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: favoriteDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            location: favorite.location,
            alertDistance: alertDistance,
            enableSafetyAlerts: enableSafetyAlerts,
            createdAt: favorite.createdAt
        )

        onSave(updatedFavorite)
    }

    // MARK: - Helper Methods
    private func loadAddress() {
        GeocodingService.shared.getAddress(from: favorite.location) { loadedAddress in
            DispatchQueue.main.async {
                self.isLoadingAddress = false
                self.address = loadedAddress
            }
        }
    }

    private func formatCoordinates(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    private func formatAlertDistance(_ meters: Double) -> String {
        let miles = meters / 1609.0
        if miles < 1.0 {
            return String(format: "%.1f mi", miles)
        } else {
            return "\(Int(miles)) mi"
        }
    }
}

#Preview {
    EditFavoriteView(
        favorite: FavoritePlace(
            name: "Home",
            description: "My home address",
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        ),
        onSave: { _ in },
        onCancel: {}
    )
}
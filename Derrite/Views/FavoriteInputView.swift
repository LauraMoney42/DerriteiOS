//
//  FavoriteInputView.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import SwiftUI
import CoreLocation

struct FavoriteInputView: View {
    let location: CLLocationCoordinate2D
    let onSubmit: (String, String) -> Void
    let onCancel: () -> Void
    
    @StateObject private var preferencesManager = PreferencesManager.shared
    private let locationManager = LocationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var favoriteName = ""
    @State private var favoriteDescription = ""
    @State private var isLoadingAddress = true
    @State private var locationAddress = ""
    
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
                            Text("Add to Favorites")
                                .font(.headline)
                        }
                        
                        if isLoadingAddress {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Finding address...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text(locationAddress)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Details") {
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
                             "Las coordenadas están difuminadas por privacidad." :
                             "Coordinates are fuzzed for privacy.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(preferencesManager.currentLanguage == "es" ? "Nuevo Favorito" : "New Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(preferencesManager.currentLanguage == "es" ? "Cancelar" : "Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.currentLanguage == "es" ? "Guardar" : "Save") {
                        let sanitizedName = favoriteName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let sanitizedDescription = favoriteDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSubmit(sanitizedName, sanitizedDescription)
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadLocationAddress()
        }
    }
    
    // MARK: - Helper Methods
    private func loadLocationAddress() {
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        locationManager.reverseGeocodeLocation(clLocation) { placemark in
            DispatchQueue.main.async {
                self.isLoadingAddress = false
                
                if let placemark = placemark {
                    var addressComponents: [String] = []
                    
                    if let name = placemark.name {
                        addressComponents.append(name)
                    }
                    if let locality = placemark.locality {
                        addressComponents.append(locality)
                    }
                    if let state = placemark.administrativeArea {
                        addressComponents.append(state)
                    }
                    
                    self.locationAddress = addressComponents.joined(separator: ", ")
                    
                    // Auto-fill name if not already set
                    if self.favoriteName.isEmpty, let name = placemark.name {
                        self.favoriteName = name
                    }
                } else {
                    self.locationAddress = String(format: "%.4f, %.4f", self.location.latitude, self.location.longitude)
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
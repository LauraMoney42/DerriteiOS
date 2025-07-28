//
//  FavoriteDetailsView.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import SwiftUI
import CoreLocation

struct FavoriteDetailsView: View {
    let favorite: FavoritePlace
    let onClose: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var address: String = ""
    @State private var isLoadingAddress = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name and Icon
                    HStack {
                        Text("❤️")
                            .font(.title2)
                        Text(favorite.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formatCreationDate())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Description (if available)
                    if !favorite.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preferencesManager.currentLanguage == "es" ? "Descripción" : "Description")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(favorite.description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    // Location Information
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferencesManager.currentLanguage == "es" ? "Ubicación" : "Location")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Address
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    if isLoadingAddress {
                                        Text("Loading address...")
                                            .font(.body)
                                            .foregroundColor(.gray)
                                    } else {
                                        Text(address.isEmpty ? "Address not available" : address)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                }
                                Spacer()
                            }
                            
                            // Coordinates
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatCoordinates(favorite.location))
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                    Text(preferencesManager.currentLanguage == "es" ? 
                                         "Coordenadas exactas guardadas localmente" :
                                         "Exact coordinates stored locally")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .italic()
                                }
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Alert Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preferencesManager.currentLanguage == "es" ? "Configuración de alertas" : "Alert Settings")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preferencesManager.currentLanguage == "es" ? "Alertas de seguridad" : "Safety Alerts")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(favorite.enableSafetyAlerts ? 
                                         (preferencesManager.currentLanguage == "es" ? "Activadas" : "Enabled") :
                                         (preferencesManager.currentLanguage == "es" ? "Desactivadas" : "Disabled"))
                                        .font(.caption)
                                        .foregroundColor(favorite.enableSafetyAlerts ? .green : .gray)
                                }
                                Spacer()
                                Image(systemName: favorite.enableSafetyAlerts ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(favorite.enableSafetyAlerts ? .green : .gray)
                            }
                            
                            HStack {
                                Image(systemName: "location.circle")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preferencesManager.currentLanguage == "es" ? "Distancia de alerta" : "Alert Distance")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(favorite.getAlertDistanceText(isSpanish: preferencesManager.currentLanguage == "es"))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Privacy Notice
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.blue)
                            Text(preferencesManager.currentLanguage == "es" ? "Aviso de privacidad" : "Privacy Notice")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Text(preferencesManager.currentLanguage == "es" ? 
                             "Este favorito se almacena solo localmente en tu dispositivo. No se comparte información con servicios externos." :
                             "This favorite is stored locally on your device only. No information is shared with external services.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(preferencesManager.currentLanguage == "es" ? "Detalles del favorito" : "Favorite Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(preferencesManager.currentLanguage == "es" ? "Cerrar" : "Close") {
                        onClose()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: onEdit) {
                            Label(preferencesManager.currentLanguage == "es" ? "Editar" : "Edit", systemImage: "pencil")
                        }
                        
                        Button(action: onDelete) {
                            Label(preferencesManager.currentLanguage == "es" ? "Eliminar" : "Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadAddress()
        }
    }
    
    // MARK: - Helper Methods
    private func loadAddress() {
        let location = CLLocation(latitude: favorite.location.latitude, longitude: favorite.location.longitude)
        
        LocationManager.shared.reverseGeocodeLocation(location) { placemark in
            DispatchQueue.main.async {
                isLoadingAddress = false
                
                if let placemark = placemark {
                    var addressComponents: [String] = []
                    
                    if let name = placemark.name {
                        addressComponents.append(name)
                    }
                    if let thoroughfare = placemark.thoroughfare {
                        if let subThoroughfare = placemark.subThoroughfare {
                            addressComponents.append("\(subThoroughfare) \(thoroughfare)")
                        } else {
                            addressComponents.append(thoroughfare)
                        }
                    }
                    if let locality = placemark.locality {
                        addressComponents.append(locality)
                    }
                    if let state = placemark.administrativeArea {
                        addressComponents.append(state)
                    }
                    
                    address = addressComponents.joined(separator: ", ")
                }
            }
        }
    }
    
    private func formatCoordinates(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
    
    private func formatCreationDate() -> String {
        let date = Date(timeIntervalSince1970: favorite.createdAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    FavoriteDetailsView(
        favorite: FavoritePlace(
            name: "Home",
            description: "My home address",
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        ),
        onClose: {},
        onEdit: {},
        onDelete: {}
    )
}
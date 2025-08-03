//  FavoritesView.swift
//  Derrite

import SwiftUI
import CoreLocation

enum FavoriteSortOption: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case alphabetical = "A-Z"
    case reverseAlphabetical = "Z-A"

    var displayName: String {
        return self.rawValue
    }
}

struct FavoritesView: View {
    let onFavoriteSelected: ((FavoritePlace) -> Void)?

    @StateObject private var favoriteManager = FavoriteManager.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var preferencesManager = PreferencesManager.shared
    @Environment(\.presentationMode) var presentationMode

    init(onFavoriteSelected: ((FavoritePlace) -> Void)? = nil) {
        self.onFavoriteSelected = onFavoriteSelected
    }

    @State private var selectedSortOption: FavoriteSortOption = .newest
    @State private var showingSortOptions = false
    @State private var selectedFavorite: FavoritePlace?
    @State private var showingFavoriteDetails = false
    @State private var showingDeleteAlert = false
    @State private var favoriteToDelete: FavoritePlace?
    @State private var userLocation: CLLocation?

    private var sortedFavorites: [FavoritePlace] {
        var favorites = favoriteManager.favorites

        switch selectedSortOption {
        case .newest:
            favorites.sort { $0.createdAt > $1.createdAt }
        case .oldest:
            favorites.sort { $0.createdAt < $1.createdAt }
        case .alphabetical:
            favorites.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .reverseAlphabetical:
            favorites.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }

        return favorites
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sort Control
                HStack {
                    Spacer()

                    Button(action: { showingSortOptions = true }) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(selectedSortOption.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.systemBlue).opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(15)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))

                // Favorites List
                if sortedFavorites.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()

                        Text("💔")
                            .font(.system(size: 60))

                        Text(preferencesManager.currentLanguage == "es" ? "Sin favoritos" : "No favorites")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(preferencesManager.currentLanguage == "es" ?
                             "Mantén presionado cualquier lugar en el mapa para agregarlo a favoritos" :
                             "Long press anywhere on the map to add it to favorites")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Spacer()
                    }
                } else {
                    List {
                        ForEach(sortedFavorites, id: \.id) { favorite in
                            FavoriteRow(
                                favorite: favorite,
                                userLocation: userLocation,
                                onTap: {
                                    // If callback is provided, zoom to favorite on map
                                    if let onFavoriteSelected = onFavoriteSelected {
                                        onFavoriteSelected(favorite)
                                    } else {
                                        // Otherwise show details
                                        selectedFavorite = favorite
                                        showingFavoriteDetails = true
                                    }
                                },
                                onDelete: {
                                    favoriteToDelete = favorite
                                    showingDeleteAlert = true
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    favoriteToDelete = favorite
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(preferencesManager.currentLanguage == "es" ? "Favoritos" : "Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.currentLanguage == "es" ? "Listo" : "Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            locationManager.getLastLocation { location in
                userLocation = location
            }
        }
        .actionSheet(isPresented: $showingSortOptions) {
            ActionSheet(
                title: Text(preferencesManager.currentLanguage == "es" ? "Ordenar favoritos" : "Sort Favorites"),
                buttons: FavoriteSortOption.allCases.map { option in
                    .default(Text(option.displayName)) {
                        selectedSortOption = option
                    }
                } + [.cancel(Text(preferencesManager.currentLanguage == "es" ? "Cancelar" : "Cancel"))]
            )
        }
        .sheet(isPresented: $showingFavoriteDetails) {
            if let favorite = selectedFavorite {
                FavoriteDetailsView(
                    favorite: favorite,
                    onClose: {
                        showingFavoriteDetails = false
                        selectedFavorite = nil
                    },
                    onDelete: {
                        showingFavoriteDetails = false
                        favoriteToDelete = favorite
                        showingDeleteAlert = true
                    }
                )
            }
        }
        .alert(preferencesManager.currentLanguage == "es" ? "Eliminar favorito" : "Delete Favorite", isPresented: $showingDeleteAlert) {
            Button(preferencesManager.currentLanguage == "es" ? "Cancelar" : "Cancel", role: .cancel) {
                favoriteToDelete = nil
            }
            Button(preferencesManager.currentLanguage == "es" ? "Eliminar" : "Delete", role: .destructive) {
                if let favorite = favoriteToDelete {
                    favoriteManager.deleteFavorite(favorite.id)
                }
                favoriteToDelete = nil
            }
        } message: {
            if let favorite = favoriteToDelete {
                Text(preferencesManager.currentLanguage == "es" ?
                     "¿Estás seguro de que quieres eliminar '\(favorite.name)'?" :
                     "Are you sure you want to delete '\(favorite.name)'?")
            }
        }
    }
}

// MARK: - Favorite Row View
struct FavoriteRow: View {
    let favorite: FavoritePlace
    let userLocation: CLLocation?
    let onTap: () -> Void
    let onDelete: () -> Void

    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var address: String = ""
    @State private var isLoadingAddress = true

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Favorite Icon
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.6)) // Lighter, less saturated pink

                // Favorite Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(favorite.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(formatDate(favorite.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !favorite.description.isEmpty {
                        Text(favorite.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Address
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .font(.caption)

                        if isLoadingAddress {
                            Text("Loading address...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(address.isEmpty ? formatCoordinates(favorite.location) : address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Distance from user
                        if let userLoc = userLocation {
                            let distance = userLoc.distance(from: CLLocation(latitude: favorite.location.latitude, longitude: favorite.location.longitude))
                            Text(formatDistance(distance))
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadAddress()
        }
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

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1609 {
            let feet = Int(meters * 3.28084)
            return "\(feet) ft"
        } else {
            let miles = String(format: "%.1f", meters / 1609.0)
            return "\(miles) mi"
        }
    }

    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    FavoritesView()
}
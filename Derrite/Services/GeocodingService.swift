//  GeocodingService.swift
//  Derrite

import Foundation
import CoreLocation

class GeocodingService: ObservableObject {
    static let shared = GeocodingService()

    private let geocoder = CLGeocoder()
    private var addressCache: [String: String] = [:]

    private init() {}

    /// Get a readable address from coordinates
    func getAddress(from coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        let cacheKey = "\(coordinate.latitude),\(coordinate.longitude)"

        // Check cache first
        if let cachedAddress = addressCache[cacheKey] {
            completion(cachedAddress)
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(self?.formatCoordinates(coordinate) ?? "Unknown Location")
                    return
                }

                guard let placemark = placemarks?.first else {
                    completion(self?.formatCoordinates(coordinate) ?? "Unknown Location")
                    return
                }

                let address = self?.formatAddress(from: placemark) ?? self?.formatCoordinates(coordinate) ?? "Unknown Location"

                // Cache the result
                self?.addressCache[cacheKey] = address

                completion(address)
            }
        }
    }

    /// Get address synchronously from cache if available, otherwise return coordinates
    func getCachedAddress(from coordinate: CLLocationCoordinate2D) -> String {
        let cacheKey = "\(coordinate.latitude),\(coordinate.longitude)"
        return addressCache[cacheKey] ?? formatCoordinates(coordinate)
    }

    private func formatAddress(from placemark: CLPlacemark) -> String {
        var addressComponents: [String] = []

        // Street number and name
        if let streetNumber = placemark.subThoroughfare,
           let streetName = placemark.thoroughfare {
            addressComponents.append("\(streetNumber) \(streetName)")
        } else if let streetName = placemark.thoroughfare {
            addressComponents.append(streetName)
        }

        // Neighborhood or area
        if let neighborhood = placemark.subLocality {
            addressComponents.append(neighborhood)
        }

        // City
        if let city = placemark.locality {
            addressComponents.append(city)
        }

        // State abbreviation
        if let state = placemark.administrativeArea {
            addressComponents.append(state)
        }

        // If we have components, join them
        if !addressComponents.isEmpty {
            return addressComponents.joined(separator: ", ")
        }

        // Fallback to area of interest or name
        if let name = placemark.name {
            return name
        }

        // Last resort - return coordinates
        return formatCoordinates(CLLocationCoordinate2D(
            latitude: placemark.location?.coordinate.latitude ?? 0,
            longitude: placemark.location?.coordinate.longitude ?? 0
        ))
    }

    private func formatCoordinates(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    /// Clear the address cache to save memory
    func clearCache() {
        addressCache.removeAll()
    }
}
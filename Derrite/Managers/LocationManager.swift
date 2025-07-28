//
//  LocationManager.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import Foundation
import CoreLocation
import MapKit

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    private var locationCompletionHandler: ((CLLocation?) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func hasLocationPermission() -> Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    func startLocationUpdates(handler: @escaping (CLLocation) -> Void) {
        locationUpdateHandler = handler
        if hasLocationPermission() {
            locationManager.startUpdatingLocation()
        } else {
            requestLocationPermission()
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationUpdateHandler = nil
    }
    
    func getLastLocation(completion: @escaping (CLLocation?) -> Void) {
        if let location = currentLocation {
            completion(location)
        } else if hasLocationPermission() {
            locationCompletionHandler = completion
            locationManager.requestLocation()
        } else {
            completion(nil)
        }
    }
    
    func getCurrentLocation() -> CLLocation? {
        return currentLocation
    }
    
    func searchAddress(query: String, completion: @escaping ([MKMapItem]?) -> Void) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    completion(response?.mapItems)
                }
            }
        }
    }
    
    func getFormattedAddress(for mapItem: MKMapItem) -> String {
        let placemark = mapItem.placemark
        
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
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        return addressComponents.joined(separator: ", ")
    }
    
    func getLocationDescription(for location: CLLocation) -> String {
        let geocoder = CLGeocoder()
        var description = "Unknown location"
        let semaphore = DispatchSemaphore(value: 0)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var components: [String] = []
                
                if let thoroughfare = placemark.thoroughfare {
                    if let subThoroughfare = placemark.subThoroughfare {
                        components.append("\(subThoroughfare) \(thoroughfare)")
                    } else {
                        components.append(thoroughfare)
                    }
                }
                
                if let locality = placemark.locality {
                    components.append(locality)
                }
                
                description = components.joined(separator: ", ")
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 2)
        return description
    }
    
    func reverseGeocodeLocation(_ location: CLLocation, completion: @escaping (CLPlacemark?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(placemarks?.first)
            }
        }
    }
    
    // MARK: - Distance Calculation
    func distance(from location1: CLLocation, to location2: CLLocation) -> Double {
        return location1.distance(from: location2)
    }
    
    func distance(from coordinate1: CLLocationCoordinate2D, to coordinate2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
        let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        return distance(from: location1, to: location2)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if hasLocationPermission() {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        locationUpdateHandler?(location)
        
        if let handler = locationCompletionHandler {
            handler(location)
            locationCompletionHandler = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error.localizedDescription
        print("Location error: \(error.localizedDescription)")
        
        locationCompletionHandler?(nil)
        locationCompletionHandler = nil
    }
}
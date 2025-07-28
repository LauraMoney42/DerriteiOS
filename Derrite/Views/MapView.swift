//
//  MapView.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var reports: [Report]
    @Binding var favorites: [FavoritePlace]
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var searchResultLocation: CLLocationCoordinate2D?
    var mapType: MKMapType = .hybridFlyover
    
    let onLongPress: (CLLocationCoordinate2D) -> Void
    let onReportTap: (Report) -> Void
    let onFavoriteTap: (FavoritePlace) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Use specified map type
        mapView.mapType = mapType
        
        // Enable all POI (Points of Interest) categories for business names
        mapView.pointOfInterestFilter = .includingAll
        
        // Show building details and labels
        mapView.showsBuildings = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsTraffic = false // Keep privacy-focused
        
        // Enable zoom and pan gestures
        mapView.isZoomEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isScrollEnabled = true
        
        // Enable 3D buildings and better detail
        mapView.preferredConfiguration = MKStandardMapConfiguration()
        
        // Add long press gesture recognizer
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update center coordinate (for favorites or manual centering)
        if centerCoordinate.latitude != 0 && centerCoordinate.longitude != 0 {
            let currentCenter = mapView.region.center
            if abs(currentCenter.latitude - centerCoordinate.latitude) > 0.0001 ||
               abs(currentCenter.longitude - centerCoordinate.longitude) > 0.0001 {
                let span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005) // Tighter zoom for favorites
                let region = MKCoordinateRegion(center: centerCoordinate, span: span)
                mapView.setRegion(region, animated: true)
            }
        }
        
        // Update user location
        if let userLocation = userLocation {
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: userLocation, span: span)
            mapView.setRegion(region, animated: true)
        }
        
        // Update annotations
        updateAnnotations(mapView)
        
        // Update search result
        if let searchLocation = searchResultLocation {
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: searchLocation, span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func updateAnnotations(_ mapView: MKMapView) {
        // Remove existing annotations except user location
        let annotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(annotations)
        
        // Add report annotations
        for report in reports {
            let annotation = ReportAnnotation(report: report)
            mapView.addAnnotation(annotation)
            
            // Add circle overlay for report radius (0.5 miles)
            let circle = MKCircle(center: report.location, radius: 804.5)
            mapView.addOverlay(circle)
        }
        
        // Add favorite annotations
        for favorite in favorites {
            let annotation = FavoriteAnnotation(favorite: favorite)
            mapView.addAnnotation(annotation)
        }
        
        // Add search result annotation
        if let searchLocation = searchResultLocation {
            let annotation = SearchResultAnnotation(coordinate: searchLocation)
            mapView.addAnnotation(annotation)
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            parent.onLongPress(coordinate)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            if let reportAnnotation = annotation as? ReportAnnotation {
                let identifier = "Report"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                annotationView?.markerTintColor = UIColor(named: "categorySafety")
                annotationView?.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
                
                return annotationView
            }
            
            if let favoriteAnnotation = annotation as? FavoriteAnnotation {
                let identifier = "Favorite"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                annotationView?.markerTintColor = UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0) // Lighter, less saturated pink
                annotationView?.glyphImage = UIImage(systemName: "heart.fill")
                
                // Make favorites more visible at all zoom levels
                annotationView?.displayPriority = .required
                annotationView?.zPriority = .max
                
                return annotationView
            }
            
            if annotation is SearchResultAnnotation {
                let identifier = "SearchResult"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }
                
                annotationView?.markerTintColor = .systemBlue
                annotationView?.glyphImage = UIImage(systemName: "magnifyingglass")
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation else { return }
            
            if let reportAnnotation = annotation as? ReportAnnotation {
                parent.onReportTap(reportAnnotation.report)
            } else if let favoriteAnnotation = annotation as? FavoriteAnnotation {
                parent.onFavoriteTap(favoriteAnnotation.favorite)
            }
            
            mapView.deselectAnnotation(annotation, animated: true)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor(named: "categorySafetyFill")?.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor(named: "categorySafetyStroke")
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Annotation Classes
class ReportAnnotation: NSObject, MKAnnotation {
    let report: Report
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(report: Report) {
        self.report = report
        self.coordinate = report.location
        self.title = report.category.displayName
        let timeAgoString = report.timeAgo()
        self.subtitle = timeAgoString
        super.init()
    }
}

class FavoriteAnnotation: NSObject, MKAnnotation {
    let favorite: FavoritePlace
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(favorite: FavoritePlace) {
        self.favorite = favorite
        self.coordinate = favorite.location
        self.title = favorite.name
        self.subtitle = favorite.description.isEmpty ? nil : favorite.description
        super.init()
    }
}

class SearchResultAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        self.title = "Search Result"
        super.init()
    }
}
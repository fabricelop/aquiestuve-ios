import SwiftUI
import MapKit
import UIKit

/// MKMapView offers annotation clustering, unlike the current simple SwiftUI pin layout.
/// Changing the map's viewport NEVER triggers a network query.
struct ClusteredPlacesMap: UIViewRepresentable {
    var places: [PlaceCandidate]
    var center: GeoPoint
    var initialRadius: Double
    var zoomStep: Int = 0
    var recenterStep: Int = 0
    var onSelect: (PlaceCandidate) -> Void
    var onCluster: ([PlaceCandidate]) -> Void
    var onViewport: (GeoPoint, Double) -> Void = { _,_ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.isRotateEnabled = false
        map.setRegion(MKCoordinateRegion(center: center.coordinate,
            latitudinalMeters: max(250, initialRadius * 2.3),
            longitudinalMeters: max(250, initialRadius * 2.3)), animated: false)
        context.coordinator.lastRadius = initialRadius
        context.coordinator.lastCenter = center
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.updateAnnotations(in: map, with: places)
        if zoomStep != coordinator.zoomStep {
            let steps = zoomStep - coordinator.zoomStep
            coordinator.zoomStep = zoomStep
            let factor = pow(0.72, Double(steps))
            var region = map.region
            region.span.latitudeDelta = min(150, max(0.00015, region.span.latitudeDelta * factor))
            region.span.longitudeDelta = min(150, max(0.00015, region.span.longitudeDelta * factor))
            map.setRegion(region, animated: true)
        }
        if recenterStep != coordinator.recenterStep {
            coordinator.recenterStep = recenterStep
            map.setRegion(MKCoordinateRegion(center: center.coordinate,
                latitudinalMeters: max(250, initialRadius * 2.3),
                longitudinalMeters: max(250, initialRadius * 2.3)), animated: true)
        } else if coordinator.lastRadius != initialRadius ||
                    (coordinator.lastCenter?.distance(to: center) ?? 0) > 2000 {
            coordinator.lastRadius = initialRadius
            coordinator.lastCenter = center
            map.setRegion(MKCoordinateRegion(center: center.coordinate,
                latitudinalMeters: max(250, initialRadius * 2.3),
                longitudinalMeters: max(250, initialRadius * 2.3)), animated: true)
        }
    }

    final class PlacePin: NSObject, MKAnnotation {
        let item: PlaceCandidate
        let coordinate: CLLocationCoordinate2D
        var title: String? { item.name }
        init(_ item: PlaceCandidate) { self.item = item; coordinate = item.position.coordinate }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClusteredPlacesMap
        var zoomStep = 0
        var recenterStep = 0
        var lastRadius: Double = 0
        var lastCenter: GeoPoint?
        init(_ parent: ClusteredPlacesMap) { self.parent = parent }

        func updateAnnotations(in map: MKMapView, with places: [PlaceCandidate]) {
            let old = map.annotations.compactMap { $0 as? PlacePin }
            let newIDs = Set(places.map(\.id))
            map.removeAnnotations(old.filter { !newIDs.contains($0.item.id) })
            let oldIDs = Set(old.map { $0.item.id })
            map.addAnnotations(places.filter { !oldIDs.contains($0.id) }.map(PlacePin.init))
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let cluster = annotation as? MKClusterAnnotation {
                let reuseID = "cluster"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: reuseID)
                view.annotation = cluster
                view.markerTintColor = .systemIndigo
                view.glyphText = "\(cluster.memberAnnotations.count)"
                view.displayPriority = .required
                return view
            }
            guard let pin = annotation as? PlacePin else { return nil }
            let reuseID = "place"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: pin, reuseIdentifier: reuseID)
            view.annotation = pin
            view.clusteringIdentifier = "ae-nearby-places"
            view.titleVisibility = .adaptive
            view.subtitleVisibility = .hidden
            view.displayPriority = .defaultLow
            view.canShowCallout = false
            let color: UIColor
            switch pin.item.categoryGroup {
            case .food: color = .systemOrange
            case .cafes: color = .brown
            case .shopping: color = .systemBlue
            case .health: color = .systemRed
            case .leisure: color = .systemPurple
            case .culture: color = .systemPink
            case .outdoors: color = .systemGreen
            case .sports: color = .systemMint
            case .transport: color = .systemTeal
            case .education: color = .systemIndigo
            case .lodging: color = .systemCyan
            case .services: color = .darkGray
            case .privatePlaces: color = .systemYellow
            case .others, .all: color = .systemGray
            }
            view.markerTintColor = color
            view.glyphImage = UIImage(systemName: pin.item.displaySymbol)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            defer { if let annotation = view.annotation { mapView.deselectAnnotation(annotation, animated: false) } }
            if let pin = view.annotation as? PlacePin {
                parent.onSelect(pin.item)
            } else if let cluster = view.annotation as? MKClusterAnnotation {
                let options = cluster.memberAnnotations.compactMap { ($0 as? PlacePin)?.item }
                if options.isEmpty { return }
                // Expose all members; user can zoom or choose from the list.
                parent.onCluster(options.sorted { $0.distance < $1.distance })
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            let center = GeoPoint(region.center)
            let radius = min(5000.0, max(75.0, region.span.latitudeDelta * 111000 / 2))
            parent.onViewport(center, radius)
        }
    }
}

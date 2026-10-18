import MapKit
import SwiftUI

struct RouteMap: View {
    var route: [GeoPoint]
    var planned: [GeoPoint] = []
    var teammates: [TeammateLive] = []
    var showsUser: Bool = false
    var userCoordinate: CLLocationCoordinate2D? = nil
    var cornerRadius: CGFloat = 0

    @State private var position: MapCameraPosition = .automatic
    @State private var framedUser = false

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            if showsUser {
                UserAnnotation()
            }
            if planned.count >= 2 {
                MapPolyline(coordinates: planned.map(\.coordinate))
                    .stroke(Color.omniIce, lineWidth: 4)
            }
            if route.count >= 2 {
                MapPolyline(coordinates: route.map(\.coordinate))
                    .stroke(Color.omniCobalt, lineWidth: 4)
            }
            ForEach(teammates) { mate in
                Annotation(mate.name, coordinate: mate.coordinate) {
                    VStack(spacing: 2) {
                        Text(mate.name)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.omniInk)
                        Circle()
                            .fill(Color.omniCobalt)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
            }
        }
        .mapStyle(.standard)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            frameCamera()
            if userCoordinate != nil {
                framedUser = true
            }
        }
        .onChange(of: route.count) { _, _ in frameCamera() }
        .onChange(of: planned) { _, _ in frameCamera() }
        .onChange(of: userCoordinate?.latitude) { _, _ in frameUserOnce() }
        .onChange(of: userCoordinate?.longitude) { _, _ in frameUserOnce() }
    }

    /// The first user fix is part of the frame. Later fixes do not move the camera.
    private func frameUserOnce() {
        guard showsUser, userCoordinate != nil, !framedUser else { return }
        framedUser = true
        frameCamera()
    }

    private func frameCamera() {
        var coords = route.map(\.coordinate) + planned.map(\.coordinate) + teammates.map(\.coordinate)
        let hasLine = !route.isEmpty || !planned.isEmpty || !teammates.isEmpty
        if showsUser, let userCoordinate, hasLine {
            coords.append(userCoordinate)
        }
        if showsUser, !hasLine {
            position = .userLocation(fallback: .automatic)
            return
        }
        guard let region = GeoFit.region(coords) else {
            if showsUser {
                position = .userLocation(fallback: .automatic)
            }
            return
        }
        position = .region(region)
    }
}

enum GeoFit {
    static func region(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.008, (maxLat - minLat) * 1.6),
            longitudeDelta: max(0.008, (maxLon - minLon) * 1.6)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

final class LocationPermission: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }
}

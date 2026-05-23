import SwiftUI
import MapKit

struct MapComponent: View {
    private let annotations: [MapAnnotationModel]
    private let preferredHeight: CGFloat?
    @State private var coordinateRegion: MKCoordinateRegion

    init(component: JasonComponent, height: CGFloat? = nil) {
        self.annotations = Self.annotations(from: component.pins)
        self.preferredHeight = height
        _coordinateRegion = State(initialValue: Self.coordinateRegion(for: component.region, annotations: annotations))
    }

    var body: some View {
        Map(coordinateRegion: $coordinateRegion, annotationItems: annotations) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                VStack(spacing: 4) {
                    if annotation.isSelected, annotation.hasCalloutText {
                        VStack(spacing: 2) {
                            if let title = annotation.title, !title.isEmpty {
                                Text(title)
                                    .font(.caption.weight(.semibold))
                            }
                            if let subtitle = annotation.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.92))
                                .shadow(radius: 2)
                        )
                    }

                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(annotation.accessibilityLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: preferredHeight ?? 200)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("jasonette-map")
    }
}

extension MapComponent {
    struct MapAnnotationModel: Identifiable, Equatable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let subtitle: String?
        let isSelected: Bool

        static func == (lhs: MapAnnotationModel, rhs: MapAnnotationModel) -> Bool {
            lhs.id == rhs.id &&
            lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle &&
            lhs.isSelected == rhs.isSelected
        }

        var hasCalloutText: Bool {
            [title, subtitle].contains { value in
                guard let value else { return false }
                return !value.isEmpty
            }
        }

        var accessibilityLabel: String {
            let label = [title, subtitle]
                .compactMap { value in
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }
                .joined(separator: ", ")
            return label.isEmpty ? "Map pin" : label
        }
    }

    static func annotations(from pins: [JasonMapPin]?) -> [MapAnnotationModel] {
        (pins ?? []).enumerated().compactMap { index, pin in
            guard let coordinate = coordinate(from: pin.coord) else { return nil }
            return MapAnnotationModel(
                id: "pin-\(index)-\(coordinate.latitude)-\(coordinate.longitude)",
                coordinate: coordinate,
                title: pin.title,
                subtitle: pin.description,
                isSelected: pin.style?.isSelectedAnnotation == true
            )
        }
    }

    static func coordinateRegion(
        for region: JasonMapRegion?,
        annotations: [MapAnnotationModel] = []
    ) -> MKCoordinateRegion {
        if let center = coordinate(from: region?.coord) {
            return MKCoordinateRegion(
                center: center,
                latitudinalMeters: meters(from: region?.height) ?? meters(from: region?.width) ?? 1_000,
                longitudinalMeters: meters(from: region?.width) ?? meters(from: region?.height) ?? 1_000
            )
        }

        if let firstAnnotation = annotations.first {
            return MKCoordinateRegion(
                center: firstAnnotation.coordinate,
                latitudinalMeters: 1_000,
                longitudinalMeters: 1_000
            )
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            latitudinalMeters: 1_000_000,
            longitudinalMeters: 1_000_000
        )
    }

    static func coordinate(from coord: String?) -> CLLocationCoordinate2D? {
        guard let coord else { return nil }
        let parts = coord
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let latitude = Double(parts[0]),
              let longitude = Double(parts[1]),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude)
        else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func meters(from value: AnyCodable?) -> CLLocationDistance? {
        guard let meters = value?.cgFloat.map(CLLocationDistance.init), meters > 0 else { return nil }
        return meters
    }
}

extension JasonStyle {
    var isSelectedAnnotation: Bool {
        guard let value = selected?.unwrapped else { return false }
        if let bool = value as? Bool { return bool }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            default: return false
            }
        }
        if let int = value as? Int { return int != 0 }
        if let double = value as? Double { return double != 0 }
        return false
    }
}

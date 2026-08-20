import CoreLocation
import MapKit

struct NeighborhoodSearchCandidate: Identifiable, Hashable {
    let title: String
    let subtitle: String
    var id: String { "\(title)|\(subtitle)" }
}

struct ResolvedNeighborhood: Hashable {
    let title: String
    let address: String
    let coordinate: ShareCoordinate
}

/// Apple 지도 검색과 역지오코딩만 담당한다. 검색 결과의 좌표는 확인 지도에만 쓰고,
/// GPS로 확인한 경우에만 `verifiedCoordinate`로 프로필에 저장한다.
@MainActor
final class NeighborhoodSearchService: NSObject, ObservableObject {
    @Published private(set) var candidates: [NeighborhoodSearchCandidate] = []
    @Published private(set) var isResolving = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.8),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        guard !trimmed.isEmpty else {
            candidates = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func resolve(_ candidate: NeighborhoodSearchCandidate) async -> ResolvedNeighborhood? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [candidate.title, candidate.subtitle].filter { !$0.isEmpty }.joined(separator: " ")
        request.region = completer.region
        do {
            guard let item = try await MKLocalSearch(request: request).start().mapItems.first,
                  let rounded = ShareCoordinate.rounded(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                  ) else {
                errorMessage = "선택한 주소의 위치를 확인하지 못했어요. 다른 검색어를 입력해 주세요."
                return nil
            }
            let normalized = Self.normalizedAddress(item.placemark, fallback: candidate.subtitle)
            return ResolvedNeighborhood(
                title: Self.neighborhoodName(item.placemark, fallback: candidate.title),
                address: normalized,
                coordinate: rounded
            )
        } catch {
            errorMessage = "주소를 확인하지 못했어요. 네트워크 상태를 확인하고 다시 시도해 주세요."
            return nil
        }
    }

    func reverseGeocode(_ coordinate: ShareCoordinate) async -> ResolvedNeighborhood? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard let placemark = try await CLGeocoder().reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "ko_KR")
            ).first else {
                errorMessage = "현재 위치의 동네 이름을 찾지 못했어요. 주소 검색을 이용해 주세요."
                return nil
            }
            return ResolvedNeighborhood(
                title: Self.neighborhoodName(placemark, fallback: "현재 동네"),
                address: Self.normalizedAddress(placemark, fallback: "현재 위치 주변"),
                coordinate: coordinate
            )
        } catch {
            errorMessage = "현재 위치의 주소를 찾지 못했어요. 주소 검색은 그대로 이용할 수 있어요."
            return nil
        }
    }

    private static func neighborhoodName(_ placemark: CLPlacemark, fallback: String) -> String {
        placemark.subLocality
            ?? placemark.locality
            ?? placemark.name
            ?? fallback
    }

    private static func normalizedAddress(_ placemark: CLPlacemark, fallback: String) -> String {
        var parts: [String] = []
        for value in [placemark.administrativeArea, placemark.locality, placemark.subLocality] {
            guard let value, !value.isEmpty, !parts.contains(value) else { continue }
            parts.append(value.replacingOccurrences(of: "특별시", with: ""))
        }
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? fallback.replacingOccurrences(of: "대한민국", with: "").trimmingCharacters(in: .whitespacesAndNewlines) : joined
    }
}

extension NeighborhoodSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let values = Array(completer.results.prefix(20)).map {
            NeighborhoodSearchCandidate(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor in
            self.candidates = values
            self.errorMessage = nil
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.candidates = []
            self.errorMessage = "주소 검색에 실패했어요. 네트워크 상태를 확인해 주세요."
        }
    }
}

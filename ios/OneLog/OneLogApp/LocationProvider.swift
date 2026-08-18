import CoreLocation
import Foundation

/// F25 동네 위치. **2026-08-18 사용자 확정**으로 GPS를 쓴다.
///
/// 경계:
/// - 사용할 때만(`WhenInUse`) 권한을 받고, 필요한 순간에 1회만 좌표를 읽는다. 추적하지 않는다.
/// - 서버에 올리는 값은 약 100m 격자로 반올림한 좌표뿐이다(`ShareCoordinate.rounded`).
/// - 권한을 거부해도 동네 이름만으로 나눔 기능은 그대로 쓴다. 도보 시간만 표시하지 않는다.
@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var coordinate: ShareCoordinate?
    @Published private(set) var isRequesting = false
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<ShareCoordinate?, Never>?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    var isDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    /// 권한을 요청하고 좌표를 1회 읽는다. 거부·실패면 nil을 준다.
    @discardableResult
    func requestOnce() async -> ShareCoordinate? {
        guard !isRequesting else { return coordinate }
        guard !isDenied else {
            errorMessage = "위치 권한이 꺼져 있어요. 설정에서 켜면 도보 시간을 보여드릴게요."
            return nil
        }

        isRequesting = true
        errorMessage = nil
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<ShareCoordinate?, Never>) in
            self.continuation = continuation
            manager.requestLocation()
        }
        isRequesting = false
        if let result { coordinate = result }
        return result
    }

    private func finish(_ value: ShareCoordinate?) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let rounded = locations.last.flatMap {
            ShareCoordinate.rounded(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        Task { @MainActor in self.finish(rounded) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "위치를 확인하지 못했어요. 동네 이름만으로도 나눔은 그대로 쓸 수 있어요."
            self.finish(nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if self.isDenied {
                self.errorMessage = "위치 권한이 꺼져 있어요. 동네 이름만으로도 나눔은 그대로 쓸 수 있어요."
                self.finish(nil)
            }
        }
    }
}

import CoreLocation
import Observation

/// Roughly where the phone is, for one purpose: working out when the sun rises
/// and sets so the board's reference colours land at the right time of day.
///
/// Asked for once, at kilometre accuracy, and kept in `UserDefaults` — a city is
/// close enough for a sunrise and a coordinate that precise is not worth holding.
/// It is never written to a `SkyEntry`. Photos still carry no location, and the
/// board is still a single axis: what time it was.
///
/// Refusing is a normal answer. The board falls back to a default coordinate and
/// keeps working; the colours are then right for somewhere else, which is what
/// the app did for everyone before this existed.
@Observable
@MainActor
final class Place: NSObject {

    /// Seoul, because that is where this app was written and a fallback has to be
    /// somewhere. Anywhere temperate would do.
    static let fallback = (latitude: 37.5665, longitude: 126.9780)

    private(set) var latitude: Double
    private(set) var longitude: Double

    /// True once a real fix has been stored, so the UI can say the colours are
    /// aimed at nowhere in particular yet.
    private(set) var isKnown: Bool

    /// True while a real fix might still arrive, and nothing is stored to stand
    /// in for it.
    ///
    /// The forecast waits on this. Asking at the fallback coordinate and asking
    /// again a second later at the real one is two calls where one was needed,
    /// and the first is for a city the user is not in — which on a working
    /// account is a wasted request against a finite budget and a forecast for
    /// Seoul on a phone in Pohang.
    ///
    /// It settles either way. A refusal settles it as surely as a fix does, and
    /// then the fallback is the honest answer rather than a placeholder being
    /// waited on.
    private(set) var isAwaitingFix = false

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard

    override init() {
        let saved = defaults.object(forKey: "skydex.latitude") as? Double
        latitude = saved ?? Place.fallback.latitude
        longitude = defaults.object(forKey: "skydex.longitude") as? Double
            ?? Place.fallback.longitude
        isKnown = saved != nil
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Call when the board appears. Asks the first time and then only takes a
    /// fresh reading, which matters for someone who travels a time zone.
    func refresh() {
        switch manager.authorizationStatus {
        case .notDetermined:
            isAwaitingFix = !isKnown
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isAwaitingFix = !isKnown
            manager.requestLocation()
        default:
            isAwaitingFix = false
        }
    }

}

/// The callbacks arrive on the queue the manager was created on, which is the
/// main one — `Place` is `@MainActor`, so it could only have been built there.
/// `@preconcurrency` states that rather than routing every fix through a hop
/// that would not change when or where it runs.
extension Place: @preconcurrency CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways
        else {
            // Refused, or not allowed to be asked. There is no fix coming and
            // whatever is waiting on one should stop waiting.
            isAwaitingFix = false
            return
        }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isAwaitingFix = false
        guard let coordinate = locations.last?.coordinate else { return }
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        isKnown = true
        defaults.set(latitude, forKey: "skydex.latitude")
        defaults.set(longitude, forKey: "skydex.longitude")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Nothing to do and nothing to say. The last known coordinate, or the
        // fallback, is still a usable answer for a sunrise — but it is now the
        // final one, so anything holding out for better can go ahead.
        isAwaitingFix = false
    }
}

import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("latitude") private var latitude = SolarClock.deviceDefault.latitude
    @AppStorage("longitude") private var longitude = SolarClock.deviceDefault.longitude
    @AppStorage("clearSkyAlerts") private var clearSkyAlerts = false

    /// One store for the whole app: both tabs sit on the same wash, and the
    /// forecast is fetched once rather than once per screen.
    @State private var forecast = ForecastStore()

    private var clock: SolarClock { SolarClock(latitude: latitude, longitude: longitude) }

    var body: some View {
        TabView {
            DialView()
                .tabItem { Label("하늘", systemImage: "sun.horizon") }
            SwatchBookView()
                .tabItem { Label("팔레트", systemImage: "square.grid.2x2") }
        }
        .environment(forecast)
        // Keyed on the coordinate so moving the sliders refetches, and on the
        // toggle so turning alerts on schedules without a relaunch.
        .task(id: "\(latitude),\(longitude),\(clearSkyAlerts)") {
            await forecast.refresh(latitude: latitude, longitude: longitude)
            await ClearSkyNotifier.reschedule(for: forecast.days, enabled: clearSkyAlerts)
        }
    }
}

extension View {
    /// The weather wash, plus the one thing it costs: bars are told to stay
    /// clear so the gradient runs edge to edge instead of stopping under a
    /// frosted strip at each end.
    func skyBackdrop(_ forecast: ForecastStore, clock: SolarClock) -> some View {
        background {
            SkyBackdrop(
                tone: forecast.today?.tone,
                isNight: clock.position(of: .now).phase == .night
            )
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview {
    RootView().modelContainer(for: SkyEntry.self, inMemory: true)
}

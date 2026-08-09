import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            DialView()
                .tabItem { Label("하늘", systemImage: "sun.horizon") }
            SwatchBookView()
                .tabItem { Label("팔레트", systemImage: "square.grid.2x2") }
        }
    }
}

#Preview {
    RootView().modelContainer(for: SkyEntry.self, inMemory: true)
}

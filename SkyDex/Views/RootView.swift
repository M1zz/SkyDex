import SwiftData
import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            BoardView()
                .tabItem { Label("하늘", systemImage: "circle.grid.3x3.fill") }
            ArchiveView()
                .tabItem { Label("기록", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: SkyEntry.self, inMemory: true)
}

import SwiftData
import SwiftUI

/// Which of the two screens is showing.
///
/// Held above the tab view rather than inside it, because both screens carry a
/// button that moves to the other one, and a tab cannot reach its own tab bar's
/// selection from inside itself.
enum Screen {
    case board
    case archive
}

struct RootView: View {
    @State private var screen: Screen = .board

    var body: some View {
        TabView(selection: $screen) {
            BoardView(screen: $screen)
                .tag(Screen.board)
                .tabItem { Label("하늘", systemImage: "circle.grid.3x3.fill") }
            ArchiveView(screen: $screen)
                .tag(Screen.archive)
                .tabItem { Label("기록", systemImage: "list.bullet") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: SkyEntry.self, inMemory: true)
}

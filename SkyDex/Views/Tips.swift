import SwiftUI
import TipKit

/// How the arc is read, told once and then never again.
///
/// This used to be a paragraph printed under the dial, which meant every user
/// paid for it forever so that the first-day user could read it once. A tip
/// arrives at the moment it is useful, and leaves for good the first time a sky
/// is captured.
struct CaptureTip: Tip {
    /// Flipped as soon as anything has been collected, which retires the tip
    /// even if it was never dismissed by hand.
    @Parameter static var hasCaptured: Bool = false

    var title: Text { Text("해가 떠 있는 동안") }
    var message: Text? { Text("찍은 시각과 밝기 자리에 색이 남습니다") }
    var image: Image? { Image(systemName: "camera.fill") }

    var rules: [Rule] {
        #Rule(Self.$hasCaptured) { $0 == false }
    }
}

/// Only worth raising once the dial is actually being used, since the times are
/// wrong in a way nobody notices until they have looked at the arc a few times.
struct HorizonTip: Tip {
    @Parameter static var hasCaptured: Bool = false

    var title: Text { Text("일출·일몰이 안 맞나요") }
    var message: Text? { Text("여기서 위치를 맞출 수 있습니다") }
    var image: Image? { Image(systemName: "sun.horizon") }

    var rules: [Rule] {
        #Rule(Self.$hasCaptured) { $0 == true }
    }
}

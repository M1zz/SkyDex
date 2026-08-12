import SwiftUI
import TipKit

/// Today's one sentence, as a tip on the shutter.
///
/// It hangs off the camera button rather than sitting on the board, because the
/// board has no words on it and adding a permanent line of text to it would undo
/// that. A tip is not permanent: it appears at most once a day, it points at the
/// thing it is about, and it has an X on it.
///
/// The content is carried on the instance rather than built from rules, because
/// what it says changes every day — TipKit identifies it by type, so a new
/// sentence tomorrow is still the same tip as far as the frequency limit is
/// concerned. That is what keeps it from becoming a daily notification in
/// disguise.
struct TodaysSkyTip: Tip {
    let insight: SkyInsight

    var title: Text { Text(insight.headline) }
    var message: Text? { Text(insight.detail) }
    var image: Image? { Image(systemName: insight.symbol) }
}

extension View {
    /// `popoverTip` takes a concrete tip rather than an optional one on the
    /// versions this app supports, so whether there is anything to say has to be
    /// decided here instead of by handing it nil.
    @ViewBuilder
    func popoverTip(ifPresent tip: TodaysSkyTip?) -> some View {
        if let tip {
            popoverTip(tip)
        } else {
            self
        }
    }
}

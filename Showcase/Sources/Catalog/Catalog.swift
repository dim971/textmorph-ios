import SwiftUI

/// The demos, in upstream's order.
///
/// Card for card with torph's own examples page, and in its sequence, so the
/// two can be read side by side. Upstream hand-orders them, opening each group
/// with the plainest use of what it covers: text, then numbers, then the cards
/// that need a morph to be interrupted, constrained or driven by a gesture.
///
/// The values, the intervals and the eases are upstream's exactly. The
/// interface around each morph is rewritten for this platform: upstream's
/// spring-hung bubbles, its separating-axis collision and its elastic squish
/// are not reproduced, because none of them is about TextMorph, and
/// reimplementing them would put four thousand lines of physics in a catalogue
/// whose job is to show one library. Where a card differs, its own file says so.
///
/// The last two are ours. Upstream shows neither the first render, which never
/// animates, nor a value emptying out, and both are worth a screen.
enum Catalog {
    @MainActor static var demos: [Demo] {
        [
            InstallDemo.entry,
            BubbleSliderDemo.entry,
            RangeShoveDemo.entry,
            SpinDialDemo.entry,
            NumoraFieldDemo.entry,
            StreamingDemo.entry,
            CopyDemo.entry,
            HexColourDemo.entry,
            WalletDemo.entry,
            DeltaDemo.entry,
            EarnedDemo.entry,
            FiltersDemo.entry,
            VersionsDemo.entry,
            HoldToConfirmDemo.entry,
            UnitsDemo.entry,
            CurrencySwapDemo.entry,
            ActionDemo.entry,
            DimensionsDemo.entry,
            ResultsSummaryDemo.entry,
            RewriteDemo.entry,
            TickerDemo.entry,
            ChartDemo.entry,
            DownloadDemo.entry,
            ReorderListDemo.entry,
            PullToCountDemo.entry,
            RatingSliderDemo.entry,
            SplitBarDemo.entry,
            ResizeDemo.entry,
            SquishyNumberDemo.entry,
            SqueezeToAbbreviateDemo.entry,
            SloshGaugeDemo.entry,
            AmountDemo.entry,
            TrailingTagDemo.entry,

            HelloDemo.entry,
            ReflowDemo.entry
        ]
    }
}

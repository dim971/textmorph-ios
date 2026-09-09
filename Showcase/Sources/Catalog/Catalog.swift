import SwiftUI

/// The demos, in the order they are worth reading.
///
/// Hand-ordered, the way upstream orders its own examples: each group opens
/// with the plainest use of what it covers. Text first, then numbers, then the
/// things that need a morph to be interrupted or constrained.
enum Catalog {
    @MainActor static var demos: [Demo] {
        [
            HelloDemo.entry,
            RewriteDemo.entry,
            StreamingDemo.entry,
            FiltersDemo.entry,
            HexColourDemo.entry,
            VersionsDemo.entry,
            WalletDemo.entry,
            DeltaDemo.entry,
            UnitsDemo.entry,
            CurrencySwapDemo.entry,
            SqueezeToAbbreviateDemo.entry,
            TickerDemo.entry,
            NumberFieldDemo.entry,
            SpinDialDemo.entry,
            ReflowDemo.entry
        ]
    }
}

import SwiftUI
import TextMorph

@main
struct TextMorphShowcaseApp: App {
    @State private var settings = ShowcaseSettings()
    @State private var tab = Launch.tab

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                CatalogScreen(openDemo: Launch.demo)
                    .tabItem { Label("Catalog", systemImage: "square.grid.2x2") }
                    .tag(Launch.Tab.catalog)
                PlaygroundScreen()
                    .tabItem { Label("Playground", systemImage: "slider.horizontal.3") }
                    .tag(Launch.Tab.playground)
                AboutScreen()
                    .tabItem { Label("About", systemImage: "info.circle") }
                    .tag(Launch.Tab.about)
            }
            .environment(settings)
        }
    }
}

/// What to show on launch, from the environment.
///
/// This exists so the screenshots in the README and in `docs/` can be taken by
/// a script rather than by hand: a picture of a morph goes stale the moment a
/// demo changes, and one that has to be recaptured by hand goes stale and stays
/// stale. `Tools/gen-screenshots.sh` drives it.
enum Launch {
    enum Tab: String {
        case catalog
        case playground
        case about
    }

    static var tab: Tab {
        Tab(rawValue: value("SHOWCASE_TAB") ?? "") ?? .catalog
    }

    /// A demo to open straight away, by its identifier.
    static var demo: String? {
        value("SHOWCASE_DEMO")
    }

    private static func value(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]
        return value?.isEmpty == false ? value : nil
    }
}

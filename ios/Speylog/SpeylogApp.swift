import SwiftUI

@main
struct SpeylogApp: App {
    /// Nettappen starter i lyst tema. Skallet bytter når siden melder et mørkt.
    @State private var dark = false

    var body: some Scene {
        WindowGroup {
            // Nettappen fyller hele skjermen, også under statuslinjen; den gir selv plass til de trygge sonene.
            WebShell(dark: $dark)
                .ignoresSafeArea()
                .preferredColorScheme(dark ? .dark : .light)
        }
    }
}

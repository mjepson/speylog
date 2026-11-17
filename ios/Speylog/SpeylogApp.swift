import SwiftUI

@main
struct SpeylogApp: App {
    var body: some Scene {
        WindowGroup {
            // Nettappen fyller hele skjermen, også under statuslinjen; den gir selv plass til de trygge sonene.
            // Lyst eller mørkt settes av WebShell etter nettappens tema.
            WebShell()
                .ignoresSafeArea()
        }
    }
}

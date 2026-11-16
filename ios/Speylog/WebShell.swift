import SwiftUI
import WebKit

/// Adressen til nettappen. Skallet er bare en ramme: alt innhold og all logikk ligger i nettappen,
/// så endringer der når telefonen uten ny appversjon.
enum Shell {
    static let production = URL(string: "https://app.speylog.com")!

    static var url: URL {
        #if DEBUG && targetEnvironment(simulator)
        // I simulatoren kan skallet pekes mot en lokal server:
        //   xcrun simctl spawn booted defaults write no.jepson.speylog url http://localhost:8080
        if let s = UserDefaults.standard.string(forKey: "url"), let u = URL(string: s) { return u }
        #endif
        return production
    }
}

struct WebShell: UIViewRepresentable {
    /// Settes etter nettappens tema, så statuslinjen og tastaturet følger det (se SpeylogApp).
    @Binding var dark: Bool

    func makeCoordinator() -> Coordinator {
        let dark = $dark
        return Coordinator { dark.wrappedValue = $0 }
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // husker innlogging og valg mellom oppstarter
        // Service worker (bildecache og oppstart uten nett) virker bare i en WKWebView som er bundet til
        // appens egne domener, se WKAppBoundDomains i Info.plist. Gjelder ikke mot lokal testserver.
        config.limitsNavigationsToAppBoundDomains = Shell.url.host == Shell.production.host

        // Merker siden som «i iOS-skallet» før den tegnes. Nettappen bruker merket til å gi plass til
        // statuslinjen og til å la være å be om «legg til på hjemskjerm».
        let mark = WKUserScript(source: "document.documentElement.classList.add('native-ios')",
                                injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(mark)

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.scrollView.contentInsetAdjustmentBehavior = .never // siden håndterer trygge soner selv
        web.isOpaque = false
        web.backgroundColor = Coordinator.background
        web.scrollView.backgroundColor = Coordinator.background
        #if DEBUG
        web.isInspectable = true // Safari på Mac-en kan inspisere siden
        #endif

        context.coordinator.followTheme(of: web)
        context.coordinator.load(in: web)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// Bakgrunnen i nettappens lyse tema, som er standard. Vises til siden har meldt sin egen farge.
        static let background = UIColor(red: 0.965, green: 0.976, blue: 0.957, alpha: 1) // #f6f9f4

        private var themeObservation: NSKeyValueObservation?
        private let setDark: (Bool) -> Void

        init(setDark: @escaping (Bool) -> Void) {
            self.setDark = setDark
        }

        func load(in web: WKWebView) {
            web.load(URLRequest(url: Shell.url))
        }

        /// Speylog har eget temavalg (lyst og mørkt) uavhengig av telefonens, og skriver temaets
        /// bakgrunnsfarge til <meta name="theme-color">. Skallet følger den, så klokken, tastaturet og
        /// bakgrunnen bak siden passer til temaet.
        func followTheme(of web: WKWebView) {
            themeObservation = web.observe(\.themeColor, options: [.new]) { [weak self] web, _ in
                DispatchQueue.main.async {
                    guard let self, let color = web.themeColor else { return }
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                    guard color.getRed(&r, green: &g, blue: &b, alpha: nil) else { return }
                    web.backgroundColor = color
                    web.scrollView.backgroundColor = color
                    self.setDark((0.299 * r + 0.587 * g + 0.114 * b) < 0.5)
                }
            }
        }

        // Lenker ut av appen (Sildre, Yr) åpnes i Safari.
        func webView(_ web: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url, url.host != Shell.url.host {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // Lenker som vil åpne nytt vindu (target="_blank", window.open) åpnes også i Safari.
        func webView(_ web: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { UIApplication.shared.open(url) }
            return nil
        }

        // Uten nett og uten lagret kopi: vis en enkel side med «Prøv igjen» i stedet for en tom skjerm.
        func webView(_ web: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            let english = Locale.preferredLanguages.first?.hasPrefix("en") == true
            let html = """
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <style>
              body{font:16px -apple-system,system-ui;display:flex;flex-direction:column;align-items:center;justify-content:center;
                   height:100vh;margin:0;gap:14px;text-align:center;padding:24px;box-sizing:border-box;background:#f6f9f4;color:#16271d}
              a{font-weight:600;color:#1a8a52;text-decoration:none;padding:10px 18px;border-radius:999px;background:#e2f3e8}
              p{margin:0;color:#5a7a64}
            </style>
            <p>\(english ? "Could not reach Speylog." : "Fikk ikke kontakt med Speylog.")</p>
            <a href="\(Shell.url.absoluteString)">\(english ? "Try again" : "Prøv igjen")</a>
            """
            web.loadHTMLString(html, baseURL: Shell.url)
        }

        // iOS kan stoppe nettinnholdet når appen har ligget lenge i bakgrunnen. Last siden på nytt.
        func webViewWebContentProcessDidTerminate(_ web: WKWebView) {
            web.reload()
        }
    }
}

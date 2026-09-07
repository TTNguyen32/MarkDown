import SwiftUI
import WebKit

/// Renders Markdown as an interactive markmap. `markmap.html` + `vendor/*.js`
/// are bundled resources; `./Scripts/fetch-vendor.sh` populates `vendor/`.
struct MindmapWebView: UIViewRepresentable {
    let markdown: String

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView()
        web.isOpaque = false
        web.scrollView.bouncesZoom = true
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard let htmlURL = Bundle.main.url(forResource: "markmap", withExtension: "html"),
              let template = try? String(contentsOf: htmlURL, encoding: .utf8) else {
            web.loadHTMLString("<p style='font-family:-apple-system;padding:2rem'>markmap.html missing — run Scripts/fetch-vendor.sh</p>", baseURL: nil)
            return
        }
        // markmap reads the markdown from a <script type="text/template"> block.
        let escaped = markdown.replacingOccurrences(of: "</script>", with: "<\\/script>")
        let html = template.replacingOccurrences(of: "%%MARKDOWN%%", with: escaped)
        web.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
    }
}

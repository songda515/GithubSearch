import ComposableArchitecture
import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

/// 저장소 `url` 을 표시하는 웹뷰 화면. iOS 에서는 `WKWebView`, 그 외(테스트 호스트)는 URL 텍스트.
/// (docs/specs/webview/spec.md)
public struct WebView: View {
    let store: StoreOf<WebViewFeature>

    public init(store: StoreOf<WebViewFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .navigationTitle(store.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    @ViewBuilder
    private var content: some View {
        #if canImport(WebKit) && os(iOS)
        WebContentView(url: store.url)
            .ignoresSafeArea(edges: .bottom)
        #else
        Text(store.url.absoluteString)
        #endif
    }
}

#if canImport(WebKit) && os(iOS)
/// `WKWebView` wrapper. Loads once on creation — `WebViewFeature.State` is immutable.
private struct WebContentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#endif

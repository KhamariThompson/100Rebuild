import SwiftUI
import WebKit

/// A view that displays terms and privacy policy information from web URLs
struct TermsAndPrivacyView: View {
    enum ViewMode {
        case terms
        case privacy
    }
    
    let mode: ViewMode
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    
    // URLs for terms and privacy content
    private let termsURL = URL(string: "https://100days.site/terms")!
    private let privacyURL = URL(string: "https://100days.site/privacy")!
    
    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.theme.text)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    Text(mode == .terms ? "Terms of Service" : "Privacy Policy")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.theme.text)
                    
                    Spacer()
                    
                    // Balance the spacing with an empty frame
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Web content
                WebView(url: mode == .terms ? termsURL : privacyURL, isLoading: $isLoading)
                    .overlay(
                        Group {
                            if isLoading {
                                ZStack {
                                    Color.theme.background
                                    ProgressView()
                                        .scaleEffect(1.5)
                                }
                            }
                        }
                    )
            }
        }
        .navigationBarHidden(true)
    }
}

// WebView to display web content
struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            
            // Apply custom styling to the web content for better appearance
            let cssString = """
            body {
                font-family: -apple-system, system-ui, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto;
                padding: 0 20px;
                line-height: 1.5;
                color: #2c3e50;
            }
            h1, h2, h3 {
                font-weight: 600;
            }
            """
            
            let jsString = """
            var style = document.createElement('style');
            style.innerHTML = '\(cssString)';
            document.head.appendChild(style);
            """
            
            webView.evaluateJavaScript(jsString, completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

struct TermsAndPrivacyView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TermsAndPrivacyView(mode: .terms)
                .preferredColorScheme(.light)
                .previewDisplayName("Terms - Light Mode")
            
            TermsAndPrivacyView(mode: .privacy)
                .preferredColorScheme(.dark)
                .previewDisplayName("Privacy - Dark Mode")
        }
    }
} 
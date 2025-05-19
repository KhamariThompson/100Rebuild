import SwiftUI
import MessageUI

struct EmailComposer: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    let recipient: String
    let subject: String
    let body: String
    let completionHandler: ((MFMailComposeResult, Error?) -> Void)?
    
    init(recipient: String, subject: String, body: String, completionHandler: ((MFMailComposeResult, Error?) -> Void)? = nil) {
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.completionHandler = completionHandler
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailComposer
        
        init(_ parent: EmailComposer) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let completionHandler = parent.completionHandler {
                completionHandler(result, error)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    static func canSendEmail() -> Bool {
        MFMailComposeViewController.canSendMail()
    }
}

// A button modifier that opens email composer or falls back to URL scheme
struct EmailButtonModifier: ViewModifier {
    let emailAddress: String
    let subject: String
    let body: String
    
    @State private var showingMailView = false
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if EmailComposer.canSendEmail() {
                    showingMailView = true
                } else {
                    // Fallback to URL scheme
                    let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "mailto:\(emailAddress)?subject=\(encodedSubject)&body=\(encodedBody)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .sheet(isPresented: $showingMailView) {
                EmailComposer(recipient: emailAddress, subject: subject, body: body) { _, _ in }
            }
    }
}

extension View {
    func emailButton(to emailAddress: String, subject: String = "", body: String = "") -> some View {
        self.modifier(EmailButtonModifier(emailAddress: emailAddress, subject: subject, body: body))
    }
} 
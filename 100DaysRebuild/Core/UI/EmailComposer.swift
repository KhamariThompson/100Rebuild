import SwiftUI
import MessageUI

struct EmailComposer: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    let recipient: String
    let subject: String
    let body: String
    
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
                EmailComposer(recipient: emailAddress, subject: subject, body: body)
            }
    }
}

extension View {
    func emailButton(to emailAddress: String, subject: String = "", body: String = "") -> some View {
        self.modifier(EmailButtonModifier(emailAddress: emailAddress, subject: subject, body: body))
    }
} 
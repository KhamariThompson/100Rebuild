import SwiftUI

/// A view that displays terms and privacy policy information
struct TermsAndPrivacyView: View {
    enum ViewMode {
        case terms
        case privacy
    }
    
    let mode: ViewMode
    @Environment(\.dismiss) private var dismiss
    
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
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if mode == .terms {
                            termsContent
                        } else {
                            privacyContent
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Terms of Service")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .padding(.bottom, 8)
            
            Text("Last Updated: June 1, 2024")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)
                .padding(.bottom, 16)
            
            Group {
                termsSection(
                    title: "1. Acceptance of Terms",
                    content: "By accessing or using 100Days, you agree to be bound by these Terms of Service and all applicable laws and regulations. If you do not agree with any of these terms, you are prohibited from using this app."
                )
                
                termsSection(
                    title: "2. Use License",
                    content: "Permission is granted to use 100Days for personal, non-commercial purposes. This license does not include the right to resell or commercially use this app or its contents; use any data mining, robots, or similar data gathering tools; download any portion of the app; or use the app in any manner that may damage or impair 100Days."
                )
                
                termsSection(
                    title: "3. User Accounts",
                    content: "To use certain features of 100Days, you may need to create an account. You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account."
                )
                
                termsSection(
                    title: "4. Content",
                    content: "All content provided on 100Days is for informational purposes only. 100Days makes no representations as to the accuracy or completeness of any information on this app."
                )
                
                termsSection(
                    title: "5. Modifications",
                    content: "100Days may revise these terms of service at any time without notice. By using this app, you agree to be bound by the current version of these terms of service."
                )
                
                termsSection(
                    title: "6. Limitations",
                    content: "In no event shall 100Days or its suppliers be liable for any damages arising out of the use or inability to use the materials on 100Days, even if 100Days or a 100Days authorized representative has been notified orally or in writing of the possibility of such damage."
                )
                
                termsSection(
                    title: "7. Contact",
                    content: "If you have any questions about these Terms, please contact us at support@100days.app"
                )
            }
        }
    }
    
    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Privacy Policy")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.theme.text)
                .padding(.bottom, 8)
            
            Text("Last Updated: June 1, 2024")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.theme.subtext)
                .padding(.bottom, 16)
            
            Group {
                termsSection(
                    title: "1. Information We Collect",
                    content: "100Days collects information that you provide directly to us, such as your name, email address, and information about your challenges and progress. We also collect certain information automatically, including your device type, operating system, and app usage data."
                )
                
                termsSection(
                    title: "2. How We Use Your Information",
                    content: "We use the information we collect to provide, maintain, and improve our services; to communicate with you; to personalize your experience; and to protect against fraud and unauthorized activity."
                )
                
                termsSection(
                    title: "3. Information Sharing",
                    content: "We do not share your personal information with third parties except as described in this privacy policy. We may share information with service providers that perform services on our behalf, and if required by law."
                )
                
                termsSection(
                    title: "4. Data Security",
                    content: "We take reasonable measures to help protect your personal information from loss, theft, misuse, and unauthorized access, alteration, and destruction."
                )
                
                termsSection(
                    title: "5. Your Choices",
                    content: "You can access, update, or delete your account information at any time through the app settings. You can also choose to opt out of certain communications."
                )
                
                termsSection(
                    title: "6. Children's Privacy",
                    content: "100Days is not directed to children under the age of 13, and we do not knowingly collect personal information from children under 13."
                )
                
                termsSection(
                    title: "7. Changes to This Policy",
                    content: "We may update this privacy policy from time to time. We will notify you of any changes by posting the new privacy policy on this page and updating the 'Last Updated' date."
                )
                
                termsSection(
                    title: "8. Contact Us",
                    content: "If you have any questions about this privacy policy, please contact us at privacy@100days.app"
                )
            }
        }
    }
    
    private func termsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.theme.text)
            
            Text(content)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.theme.subtext)
                .fixedSize(horizontal: false, vertical: true)
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
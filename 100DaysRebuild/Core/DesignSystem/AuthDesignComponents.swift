import SwiftUI

/// Collection of reusable components specifically for the authentication flow
public enum AuthComponents {
    
    /// Standard text field for authentication forms
    public struct AuthTextField: View {
        let title: String
        let placeholder: String
        @Binding var text: String
        var errorMessage: String?
        var keyboardType: UIKeyboardType
        var textContentType: UITextContentType?
        var submitLabel: SubmitLabel
        var onSubmit: () -> Void
        var onTextChange: ((String) -> Void)?
        var isFocused: FocusState<Bool?>.Binding
        var identifier: Any?
        
        public init(
            title: String,
            placeholder: String,
            text: Binding<String>,
            errorMessage: String? = nil,
            keyboardType: UIKeyboardType = .default,
            textContentType: UITextContentType? = nil,
            submitLabel: SubmitLabel = .next,
            isFocused: FocusState<Bool?>.Binding,
            identifier: Any? = nil,
            onSubmit: @escaping () -> Void = {},
            onTextChange: ((String) -> Void)? = nil
        ) {
            self.title = title
            self.placeholder = placeholder
            self._text = text
            self.errorMessage = errorMessage
            self.keyboardType = keyboardType
            self.textContentType = textContentType
            self.submitLabel = submitLabel
            self.isFocused = isFocused
            self.identifier = identifier
            self.onSubmit = onSubmit
            self.onTextChange = onTextChange
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Field label
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                
                // Text field
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(textContentType == .emailAddress ? .never : .words)
                    .padding()
                    .frame(height: CalAIDesignTokens.buttonHeight)
                    .background(Color.theme.surface)
                    .cornerRadius(CalAIDesignTokens.buttonRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .stroke(errorMessage == nil ? Color.theme.border.opacity(0.3) : Color.red, lineWidth: 1)
                    )
                    .focused(isFocused, equals: true)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                    .onChange(of: text) { oldValue, newValue in
                        if let onTextChange = onTextChange {
                            onTextChange(newValue)
                        }
                    }
                
                // Error message if present
                if let error = errorMessage, !text.isEmpty {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    /// Secure field for passwords in authentication forms
    public struct AuthSecureField: View {
        let title: String
        let placeholder: String
        @Binding var text: String
        var errorMessage: String?
        var textContentType: UITextContentType?
        var submitLabel: SubmitLabel
        var onSubmit: () -> Void
        var onTextChange: ((String) -> Void)?
        var isFocused: FocusState<Bool?>.Binding
        var identifier: Any?
        @State private var showPassword: Bool = false
        
        public init(
            title: String,
            placeholder: String,
            text: Binding<String>,
            errorMessage: String? = nil,
            textContentType: UITextContentType? = nil,
            submitLabel: SubmitLabel = .next,
            isFocused: FocusState<Bool?>.Binding,
            identifier: Any? = nil,
            onSubmit: @escaping () -> Void = {},
            onTextChange: ((String) -> Void)? = nil
        ) {
            self.title = title
            self.placeholder = placeholder
            self._text = text
            self.errorMessage = errorMessage
            self.textContentType = textContentType
            self.submitLabel = submitLabel
            self.isFocused = isFocused
            self.identifier = identifier
            self.onSubmit = onSubmit
            self.onTextChange = onTextChange
        }
        
        public var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Field label
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.text)
                
                // Password field with toggle
                ZStack(alignment: .trailing) {
                    if showPassword {
                        HStack {
                            TextField(placeholder, text: $text)
                                .textContentType(textContentType)
                                .autocorrectionDisabled()
                                .submitLabel(submitLabel)
                                .onSubmit(onSubmit)
                                
                            Spacer()
                        }
                    } else {
                        HStack {
                            SecureField(placeholder, text: $text)
                                .textContentType(textContentType)
                                .autocorrectionDisabled()
                                .submitLabel(submitLabel)
                                .onSubmit(onSubmit)
                                
                            Spacer()
                        }
                    }
                    
                    // Show/hide password button
                    Button(action: {
                        showPassword.toggle()
                    }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.theme.subtext)
                            .padding(.trailing, 12)
                    }
                }
                .padding()
                .frame(height: CalAIDesignTokens.buttonHeight)
                .background(Color.theme.surface)
                .cornerRadius(CalAIDesignTokens.buttonRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                        .stroke(errorMessage == nil ? Color.theme.border.opacity(0.3) : Color.red, lineWidth: 1)
                )
                .focused(isFocused, equals: true)
                .onChange(of: text) { oldValue, newValue in
                    if let onTextChange = onTextChange {
                        onTextChange(newValue)
                    }
                }
                
                // Error message if present
                if let error = errorMessage, !text.isEmpty {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    /// Primary button for authentication actions
    public struct AuthPrimaryButton: View {
        let title: String
        let action: () -> Void
        let isEnabled: Bool
        let isLoading: Bool
        
        public init(
            title: String,
            isEnabled: Bool = true,
            isLoading: Bool = false,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.isEnabled = isEnabled
            self.isLoading = isLoading
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: CalAIDesignTokens.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                        .fill(isEnabled ? Color.theme.accent : Color.gray.opacity(0.3))
                        .shadow(color: isEnabled ? Color.theme.accent.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 1)
                )
            }
            .buttonStyle(AppScaleButtonStyle(scale: 0.98))
            .disabled(!isEnabled || isLoading)
        }
    }
    
    /// Secondary button for authentication actions
    public struct AuthSecondaryButton: View {
        let title: String
        let action: () -> Void
        let isEnabled: Bool
        
        public init(
            title: String,
            isEnabled: Bool = true,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.isEnabled = isEnabled
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.theme.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: CalAIDesignTokens.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                            .fill(Color.theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: CalAIDesignTokens.buttonRadius)
                                    .stroke(Color.theme.border.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.theme.shadow.opacity(0.06), radius: 3, x: 0, y: 1)
                    )
            }
            .buttonStyle(AppScaleButtonStyle(scale: 0.98))
            .disabled(!isEnabled)
        }
    }
    
    /// Link button for tertiary actions like "Forgot Password"
    public struct AuthLinkButton: View {
        let title: String
        let action: () -> Void
        
        public init(title: String, action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.accent)
                    .padding(.vertical, 4)
            }
        }
    }
    
    /// Divider with "Or" text in the middle
    public struct AuthDivider: View {
        let text: String
        
        public init(text: String = "Or continue with") {
            self.text = text
        }
        
        public var body: some View {
            HStack {
                Rectangle()
                    .fill(Color.theme.border.opacity(0.5))
                    .frame(height: 1)
                
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.theme.subtext)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .fill(Color.theme.border.opacity(0.5))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
        }
    }
    
    /// Auth page container with consistent styling
    public struct AuthContainer<Content: View>: View {
        let content: Content
        
        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        public var body: some View {
            ZStack {
                // Apply background color to entire screen with higher priority
                Color.theme.background
                    .edgesIgnoringSafeArea(.all)
                    .zIndex(-1) // Ensure background is below all other content
                
                ScrollView {
                    VStack(spacing: CalAIDesignTokens.screenPadding) {
                        content
                    }
                    .padding(.horizontal, CalAIDesignTokens.screenPadding)
                    .padding(.top, 60)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onAppear {
                // Apply fixes when container appears
                AppFixes.shared.applyAllFixes()
            }
        }
    }
}

// MARK: - Preview
struct AuthDesignComponents_Previews: PreviewProvider {
    @FocusState static var focus: Bool?
    
    static var previews: some View {
        ScrollView {
            VStack(spacing: 30) {
                AuthComponents.AuthTextField(
                    title: "Email",
                    placeholder: "Your email address",
                    text: .constant("user@example.com"),
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    isFocused: $focus
                )
                
                AuthComponents.AuthSecureField(
                    title: "Password",
                    placeholder: "Your password",
                    text: .constant("password123"),
                    errorMessage: "Password must be at least 6 characters",
                    textContentType: .password,
                    isFocused: $focus
                )
                
                AuthComponents.AuthPrimaryButton(
                    title: "Sign In",
                    action: {}
                )
                
                AuthComponents.AuthPrimaryButton(
                    title: "Processing...",
                    isLoading: true,
                    action: {}
                )
                
                AuthComponents.AuthSecondaryButton(
                    title: "Create Account",
                    action: {}
                )
                
                AuthComponents.AuthLinkButton(
                    title: "Forgot Password?",
                    action: {}
                )
                
                AuthComponents.AuthDivider()
            }
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
} 
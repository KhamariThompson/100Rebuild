import SwiftUI
import UIKit

// Extension to disable the SystemInputAssistantView that causes constraint conflicts
extension UITextField {
    // Disable the input assistant view that appears above the keyboard
    func disableInputAssistant() {
        // Clear the actions and button groups in the assistant bar
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
    }
}

// UIKit representable that wraps UITextField to access native functionality
struct SafeTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var returnKeyType: UIReturnKeyType = .default
    var isSecure: Bool = false
    var contentType: UITextContentType?
    var autocorrection: UITextAutocorrectionType = .default
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onCommit: () -> Void = {}
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.returnKeyType = returnKeyType
        textField.isSecureTextEntry = isSecure
        if let contentType = contentType {
            textField.textContentType = contentType
        }
        textField.autocorrectionType = autocorrection
        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        // Disable the input assistant to avoid constraint conflicts
        textField.disableInputAssistant()
        
        // Use a different approach for text setting to avoid loops
        if textField.text != text {
            textField.text = text
        }
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        
        // Update properties that might change
        uiView.keyboardType = keyboardType
        uiView.returnKeyType = returnKeyType
        uiView.isSecureTextEntry = isSecure
        if let contentType = contentType {
            uiView.textContentType = contentType
        }
        uiView.autocorrectionType = autocorrection
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SafeTextField
        
        init(_ parent: SafeTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onEditingChanged(true)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onEditingChanged(false)
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit()
            textField.resignFirstResponder()
            return true
        }
    }
}

// SwiftUI View extension to easily use SafeTextField
extension View {
    func safeTextField(
        text: Binding<String>,
        placeholder: String,
        keyboardType: UIKeyboardType = .default,
        returnKeyType: UIReturnKeyType = .default,
        isSecure: Bool = false,
        contentType: UITextContentType? = nil,
        autocorrection: UITextAutocorrectionType = .default,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = {}
    ) -> some View {
        SafeTextField(
            text: text,
            placeholder: placeholder,
            keyboardType: keyboardType,
            returnKeyType: returnKeyType,
            isSecure: isSecure,
            contentType: contentType,
            autocorrection: autocorrection,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
        .frame(height: 50) // Set a fixed height to avoid constraint issues
    }
} 
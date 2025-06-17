import Foundation
import SwiftUI
import Combine

/// Central manager for loading states across the app
class LoadingStateManager: ObservableObject {
    /// Shared instance for global access
    static let shared = LoadingStateManager()
    
    /// Published properties for observation
    @Published var isLoading = false
    @Published var loadingMessage: String = ""
    @Published var loadingProgress: Double? = nil
    @Published var isShowingError = false
    @Published var errorMessage: String = ""
    
    /// Active loading operations
    private var activeOperations: [String: UUID] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Setup any initial configuration
        setupErrorTimeout()
    }
    
    /// Start loading state with optional message and ID
    func startLoading(message: String = "Loading...", operationId: String = UUID().uuidString) {
        DispatchQueue.main.async {
            // Generate unique ID for this loading operation
            let uuid = UUID()
            self.activeOperations[operationId] = uuid
            
            // Update loading state
            self.loadingMessage = message
            self.isLoading = true
            self.loadingProgress = nil
            
            // Safety timeout to prevent infinite loading states
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                guard let self = self else { return }
                
                // Only timeout if this is still the active operation
                if self.activeOperations[operationId] == uuid {
                    self.endLoading(operationId: operationId)
                    
                    // Log warning about long operation
                    print("WARNING: Loading operation \(operationId) timed out after 20 seconds")
                }
            }
        }
    }
    
    /// Update loading progress (0.0 to 1.0)
    func updateProgress(_ progress: Double, operationId: String) {
        DispatchQueue.main.async {
            // Only update if this operation is still active
            guard self.activeOperations[operationId] != nil else { return }
            
            self.loadingProgress = min(max(progress, 0.0), 1.0)
        }
    }
    
    /// End loading state for a specific operation
    func endLoading(operationId: String) {
        DispatchQueue.main.async {
            // Remove this operation
            self.activeOperations.removeValue(forKey: operationId)
            
            // Only turn off loading if no more operations are active
            if self.activeOperations.isEmpty {
                self.isLoading = false
                self.loadingProgress = nil
                self.loadingMessage = ""
            }
        }
    }
    
    /// Show error message
    func showError(_ message: String, autoDismiss: Bool = true) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isShowingError = true
            
            // Auto-dismiss after delay if requested
            if autoDismiss {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self = self else { return }
                    if self.errorMessage == message {
                        self.isShowingError = false
                    }
                }
            }
        }
    }
    
    /// Dismiss current error message
    func dismissError() {
        DispatchQueue.main.async {
            self.isShowingError = false
        }
    }
    
    /// Reset all loading states
    func reset() {
        DispatchQueue.main.async {
            self.activeOperations.removeAll()
            self.isLoading = false
            self.loadingProgress = nil
            self.loadingMessage = ""
            self.isShowingError = false
            self.errorMessage = ""
        }
    }
    
    /// Setup timeout for error messages
    private func setupErrorTimeout() {
        // Watch for changes to error state
        $isShowingError
            .debounce(for: .seconds(5), scheduler: RunLoop.main)
            .filter { $0 }
            .sink { [weak self] _ in
                self?.dismissError()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Custom ActivityIndicator

/// Custom activity indicator to avoid using SwiftUI.ProgressView
private struct ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: .medium)
        view.startAnimating()
        view.color = UIColor(Color.theme.accent)
        return view
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {}
}

// MARK: - Loading View Modifier

/// View modifier to show loading state
struct LoadingOverlay: ViewModifier {
    @EnvironmentObject private var loadingManager: LoadingStateManager
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        ZStack {
            // Main content
            content
                .disabled(loadingManager.isLoading)
                .blur(radius: loadingManager.isLoading ? 3 : 0)
            
            // Loading overlay
            if loadingManager.isLoading {
                Rectangle()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if let progress = loadingManager.loadingProgress {
                        // Use custom CircularProgress instead of ProgressView
                        ProgressComponents.CircularProgress(
                            progress: progress,
                            size: 60,
                            lineWidth: 8,
                            backgroundColor: Color.theme.border.opacity(0.3),
                            foregroundColor: Color.theme.accent,
                            showLabel: true
                        )
                        .frame(width: 200)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white)
                    } else {
                        // Use custom ActivityIndicator instead of ProgressView
                        ActivityIndicator()
                            .scaleEffect(1.5)
                            .frame(width: 30, height: 30)
                    }
                    
                    Text(loadingManager.loadingMessage)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.theme.accent.opacity(0.85))
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Error toast
            if loadingManager.isShowingError {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                        
                        Text(loadingManager.errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                        
                        Button(action: {
                            loadingManager.dismissError()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.theme.error)
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: loadingManager.isShowingError)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: loadingManager.isLoading)
    }
}

// MARK: - View Extension

extension View {
    /// Apply loading overlay to a view
    func withLoading() -> some View {
        self.modifier(LoadingOverlay())
            .environmentObject(LoadingStateManager.shared)
    }
    
    /// Apply task with loading state
    func taskWithLoading(message: String = "Loading...", operationId: String = UUID().uuidString, _ action: @escaping () async throws -> Void) -> some View {
        self.task {
            do {
                LoadingStateManager.shared.startLoading(message: message, operationId: operationId)
                try await action()
                LoadingStateManager.shared.endLoading(operationId: operationId)
            } catch {
                LoadingStateManager.shared.endLoading(operationId: operationId)
                LoadingStateManager.shared.showError(error.localizedDescription)
                print("Task with loading error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Function to safely run UI updates on the main thread

/// Run a closure on the main thread
func onMainThread(_ action: @escaping () -> Void) {
    if Thread.isMainThread {
        action()
    } else {
        DispatchQueue.main.async {
            action()
        }
    }
} 
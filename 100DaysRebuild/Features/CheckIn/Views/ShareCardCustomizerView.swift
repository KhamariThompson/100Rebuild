import SwiftUI

/// A view that allows users to customize their milestone share card
struct ShareCardCustomizerView: View {
    @ObservedObject var viewModel: CheckInViewModel
    @Binding var isPresented: Bool
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var selectedTab = 0
    @State private var showPreviewFullScreen = false
    
    // Background color options
    private let backgroundOptions: [(String, MilestoneShareCardGenerator.BackgroundStyle)] = [
        ("Classic", .gradient([.theme.accent, .theme.accent.opacity(0.7)])),
        ("Vibrant", .gradient([.theme.accent, .purple])),
        ("Minimal", .solid(.theme.surface)),
        ("Dark", .gradient([.black, .gray.opacity(0.7)])),
        ("Warm", .gradient([.orange, .red.opacity(0.7)]))
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Preview of the share card
                VStack {
                    if let preview = previewImage {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .padding(.horizontal)
                            .onTapGesture {
                                showPreviewFullScreen = true
                            }
                    } else {
                        ProgressView()
                            .frame(height: 300)
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .padding(.top)
                
                // Customization options
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Layout style selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Layout Style")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            Picker("Layout Style", selection: $selectedTab) {
                                Text("Modern").tag(0)
                                Text("Classic").tag(1)
                                Text("Minimal").tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onChange(of: selectedTab) { oldValue, newValue in
                                switch newValue {
                                case 0:
                                    viewModel.setCardLayout(.modern)
                                case 1:
                                    viewModel.setCardLayout(.classic)
                                case 2:
                                    viewModel.setCardLayout(.minimal)
                                default:
                                    viewModel.setCardLayout(.modern)
                                }
                                updatePreview()
                            }
                        }
                        .padding(.horizontal)
                        
                        // Background style selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Background Style")
                                .font(.headline)
                                .foregroundColor(.theme.text)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(backgroundOptions.indices, id: \.self) { index in
                                        BackgroundStyleButton(
                                            title: backgroundOptions[index].0,
                                            style: backgroundOptions[index].1,
                                            isSelected: getIsBackgroundSelected(backgroundOptions[index].1)
                                        ) {
                                            viewModel.setCardBackground(backgroundOptions[index].1)
                                            updatePreview()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.theme.surface)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: -3)
                )
                
                // Share button
                Button(action: {
                    shareCurrentDesign()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Your Milestone")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.theme.accent)
                            .shadow(color: Color.theme.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Customize Share Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = shareImage {
                    Utilities_ShareSheet(items: [image])
                }
            }
            .fullScreenCover(isPresented: $showPreviewFullScreen) {
                if let preview = previewImage {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        
                        VStack {
                            Image(uiImage: preview)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding()
                            
                            HStack(spacing: 40) {
                                Button(action: {
                                    showPreviewFullScreen = false
                                }) {
                                    Text("Back")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 24)
                                        .background(
                                            Capsule()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                }
                                
                                Button(action: {
                                    shareImage = preview
                                    showingShareSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(
                                        Capsule()
                                            .fill(Color.white)
                                    )
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                    .statusBar(hidden: true)
                }
            }
            .onAppear {
                initializeView()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializeView() {
        // Set initial layout selection based on viewModel
        switch viewModel.selectedCardLayout {
        case .modern:
            selectedTab = 0
        case .classic:
            selectedTab = 1
        case .minimal:
            selectedTab = 2
        }
        
        // Generate initial preview
        updatePreview()
    }
    
    private func updatePreview() {
        // Generate a new preview
        previewImage = viewModel.createShareCard()
    }
    
    private func shareCurrentDesign() {
        // Generate the share image
        if let image = viewModel.createShareCard() {
            shareImage = image
            showingShareSheet = true
        }
    }
    
    private func getIsBackgroundSelected(_ style: MilestoneShareCardGenerator.BackgroundStyle) -> Bool {
        switch (style, viewModel.selectedBackground) {
        case (.solid(let color1), .solid(let color2)):
            return color1 == color2
        case (.gradient(let colors1), .gradient(let colors2)):
            // Basic comparison - just check first color
            return colors1.first == colors2.first
        case (.pattern(let name1), .pattern(let name2)):
            return name1 == name2
        default:
            return false
        }
    }
}

/// Component for selecting a background style
struct BackgroundStyleButton: View {
    let title: String
    let style: MilestoneShareCardGenerator.BackgroundStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(
                        getBackgroundPreview()
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.theme.accent : Color.clear, lineWidth: 3)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.theme.text)
            }
            .padding(.vertical, 4)
            .frame(width: 70)
        }
    }
    
    private func getBackgroundPreview() -> AnyShapeStyle {
        switch style {
        case .solid(let color):
            return color.asAnyShapeStyle()
        case .gradient(let colors):
            return LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).asAnyShapeStyle()
        case .pattern(_):
            // For pattern, just show a placeholder gradient
            return LinearGradient(
                gradient: Gradient(colors: [Color.gray, Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).asAnyShapeStyle()
        }
    }
}

// Extension to convert ShapeStyle to AnyShapeStyle
extension ShapeStyle {
    func asAnyShapeStyle() -> AnyShapeStyle {
        return AnyShapeStyle(self)
    }
}

// MARK: - Previews

struct ShareCardCustomizerView_Previews: PreviewProvider {
    static var previews: some View {
        ShareCardCustomizerView(
            viewModel: CheckInViewModel(),
            isPresented: .constant(true)
        )
    }
} 
import SwiftUI
import UIKit

// MARK: - SwiftUI Wrapper
struct UIKitHeaderView: UIViewRepresentable {
    var title: String
    var subtitle: String? = nil
    var showBackButton: Bool = true
    var onBackTapped: (() -> Void)? = nil
    
    func makeUIView(context: Context) -> UIHeaderView {
        let view = UIHeaderView()
        view.delegate = context.coordinator
        view.titleLabel.font = UIFont.systemFont(ofSize: AppTypography.FontSize.title1, weight: .semibold)
        view.titleLabel.textColor = UIColor(Color.theme.text)
        
        if let subtitle = subtitle {
            view.subtitleLabel.text = subtitle
            view.subtitleLabel.font = UIFont.systemFont(ofSize: AppTypography.FontSize.subhead, weight: .regular)
            view.subtitleLabel.textColor = UIColor(Color.theme.subtext)
            view.subtitleLabel.isHidden = false
        } else {
            view.subtitleLabel.isHidden = true
        }
        
        view.setTitle(title)
        view.showBackButton = showBackButton
        
        return view
    }
    
    func updateUIView(_ uiView: UIHeaderView, context: Context) {
        uiView.setTitle(title)
        
        if let subtitle = subtitle {
            uiView.subtitleLabel.text = subtitle
            uiView.subtitleLabel.isHidden = false
        } else {
            uiView.subtitleLabel.isHidden = true
        }
        
        uiView.showBackButton = showBackButton
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIHeaderViewDelegate {
        var parent: UIKitHeaderView
        
        init(_ parent: UIKitHeaderView) {
            self.parent = parent
        }
        
        func didTapBackButton() {
            parent.onBackTapped?()
        }
    }
}

// MARK: - UIKit Header View
protocol UIHeaderViewDelegate: AnyObject {
    func didTapBackButton()
}

class UIHeaderView: UIView {
    weak var delegate: UIHeaderViewDelegate?
    
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let backButton = UIButton(type: .system)
    
    var showBackButton: Bool = true {
        didSet {
            backButton.isHidden = !showBackButton
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor(Color.theme.background)
        
        // Configure back button
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = UIColor(Color.theme.accent)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        // Configure title label
        titleLabel.textAlignment = .left
        titleLabel.numberOfLines = 1
        
        // Configure subtitle label
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 1
        subtitleLabel.isHidden = true
        
        // Add subviews
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        
        // Set up constraints
        backButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Back button
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Subtitle label
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    func setTitle(_ title: String) {
        titleLabel.text = title
    }
    
    @objc private func backButtonTapped() {
        delegate?.didTapBackButton()
    }
} 
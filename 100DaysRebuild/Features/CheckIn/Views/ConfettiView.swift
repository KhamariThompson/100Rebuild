import SwiftUI
import UIKit

/// A confetti animation view for celebrations
struct ConfettiView: UIViewRepresentable {
    var intensity: CGFloat = 1.0
    var duration: TimeInterval = 3.0
    @Environment(\.colorScheme) var colorScheme
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        // Create and configure the emitter once view is loaded
        DispatchQueue.main.async {
            setupEmitter(in: view)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update emitter if needed
    }
    
    private func setupEmitter(in view: UIView) {
        // First clear any existing emitters
        view.layer.sublayers?.forEach { layer in
            if layer is CAEmitterLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // Create emitter layer
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: view.bounds.width / 2, y: -10)
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
        emitter.renderMode = .oldestLast
        
        // Determine the appropriate colors based on the color scheme
        let colors = confettiColors()
        var cells: [CAEmitterCell] = []
        
        for color in colors {
            // Shape 1: Stars
            let cell = CAEmitterCell()
            cell.birthRate = Float(5.0 * intensity)
            cell.lifetime = 5.0
            cell.lifetimeRange = 2.0
            cell.velocity = 180
            cell.velocityRange = 80
            cell.emissionRange = .pi * 2
            cell.spin = 3.5
            cell.spinRange = 2
            cell.scale = 0.25
            cell.scaleRange = 0.1
            cell.scaleSpeed = -0.03
            cell.color = color.cgColor
            cell.alphaSpeed = -0.2
            
            // Use custom star shape for better visibility
            if let starImage = createConfettiImage(shape: .star, color: color) {
                cell.contents = starImage.cgImage
            } else {
                cell.contents = UIImage(systemName: "star.fill")?.cgImage
            }
            
            cells.append(cell)
            
            // Shape 2: Circles
            let cell2 = CAEmitterCell()
            cell2.birthRate = Float(5.0 * intensity)
            cell2.lifetime = 5.0
            cell2.lifetimeRange = 2.0
            cell2.velocity = 150
            cell2.velocityRange = 80
            cell2.emissionRange = .pi * 2
            cell2.scale = 0.15
            cell2.scaleRange = 0.1
            cell2.scaleSpeed = -0.015
            cell2.color = color.cgColor
            cell2.alphaSpeed = -0.2
            
            // Use custom circle shape for better visibility
            if let circleImage = createConfettiImage(shape: .circle, color: color) {
                cell2.contents = circleImage.cgImage
            } else {
                cell2.contents = UIImage(systemName: "circle.fill")?.cgImage
            }
            
            cells.append(cell2)
            
            // Shape 3: Rectangles
            let cell3 = CAEmitterCell()
            cell3.birthRate = Float(5.0 * intensity)
            cell3.lifetime = 5.0
            cell3.lifetimeRange = 2.0
            cell3.velocity = 165
            cell3.velocityRange = 70
            cell3.emissionRange = .pi * 2
            cell3.scale = 0.1
            cell3.scaleRange = 0.05
            cell3.scaleSpeed = -0.02
            cell3.color = color.cgColor
            cell3.alphaSpeed = -0.2
            
            // Use custom rectangle shape for better visibility
            if let rectImage = createConfettiImage(shape: .rectangle, color: color) {
                cell3.contents = rectImage.cgImage
            } else {
                cell3.contents = UIImage(systemName: "square.fill")?.cgImage
            }
            
            cells.append(cell3)
        }
        
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        
        // Auto-cleanup after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            // Gradually stop emitting new particles
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            cells.forEach { cell in
                cell.birthRate = 0
            }
            
            CATransaction.commit()
            
            // Remove the emitter after all particles are gone
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                emitter.removeFromSuperlayer()
            }
        }
    }
    
    // Get appropriate colors based on color scheme
    private func confettiColors() -> [UIColor] {
        // Use brighter colors for dark mode, more muted for light mode
        if colorScheme == .dark {
            return [
                .systemRed,
                .systemBlue,
                .systemGreen,
                .systemYellow,
                .systemPurple,
                .systemOrange,
                .systemPink,
                .systemTeal,
                .white,        // Add white for better visibility in dark mode
                .systemIndigo
            ]
        } else {
            return [
                .systemRed,
                .systemBlue,
                .systemGreen,
                .systemYellow,
                .systemPurple,
                .systemOrange,
                .systemPink,
                .systemTeal,
                .systemIndigo
            ]
        }
    }
    
    // Different shapes for confetti
    enum ConfettiShape {
        case circle, star, rectangle
    }
    
    // Create custom shapes for better visibility
    private func createConfettiImage(shape: ConfettiShape, color: UIColor) -> UIImage? {
        let size = CGSize(width: 32, height: 32)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(color.cgColor)
        
        switch shape {
        case .circle:
            context.fillEllipse(in: CGRect(origin: .zero, size: size))
        case .star:
            drawStar(in: context, center: CGPoint(x: size.width/2, y: size.height/2), radius: size.width/2)
        case .rectangle:
            let rect = CGRect(x: 8, y: 8, width: 16, height: 16)
            context.fill(rect)
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    // Draw a star shape
    private func drawStar(in context: CGContext, center: CGPoint, radius: CGFloat) {
        let numberOfPoints = 5
        let angleIncrement = .pi * 2 / CGFloat(numberOfPoints * 2)
        
        var points = [CGPoint]()
        
        for i in 0..<(numberOfPoints * 2) {
            let angle = CGFloat(i) * angleIncrement - .pi / 2
            let pointRadius = i % 2 == 0 ? radius : radius * 0.4
            let x = center.x + pointRadius * cos(angle)
            let y = center.y + pointRadius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        
        if let firstPoint = points.first {
            context.move(to: firstPoint)
            for point in points.dropFirst() {
                context.addLine(to: point)
            }
            context.closePath()
            context.fillPath()
        }
    }
} 
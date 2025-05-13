import SwiftUI
import UIKit

/// A confetti animation view for celebrations
struct ConfettiView: UIViewRepresentable {
    var intensity: CGFloat = 1.0
    var duration: TimeInterval = 10.0
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        // Create emitter layer
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: view.frame.size.width / 2, y: -10)
        emitter.emitterSize = CGSize(width: view.frame.size.width, height: 1)
        emitter.renderMode = .additive
        
        // Create cells with different colors
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple, .systemOrange]
        var cells: [CAEmitterCell] = []
        
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = Float(4.0 * intensity)
            cell.lifetime = Float(duration)
            cell.velocity = 150
            cell.velocityRange = 50
            cell.emissionRange = .pi * 2
            cell.spin = 5
            cell.spinRange = 10
            cell.scale = 0.2
            cell.scaleRange = 0.1
            cell.color = color.cgColor
            cell.alphaSpeed = -0.1
            cell.contents = UIImage(systemName: "star.fill")?.cgImage
            cells.append(cell)
            
            // Add a second type for variety
            let cell2 = CAEmitterCell()
            cell2.birthRate = Float(4.0 * intensity)
            cell2.lifetime = Float(duration)
            cell2.velocity = 130
            cell2.velocityRange = 60
            cell2.emissionRange = .pi * 2
            cell2.scale = 0.15
            cell2.scaleRange = 0.1
            cell2.color = color.cgColor
            cell2.alphaSpeed = -0.15
            cell2.contents = UIImage(systemName: "circle.fill")?.cgImage
            cells.append(cell2)
        }
        
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Nothing to update
    }
} 
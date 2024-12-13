//
//  SmoothTextView.swift
//  Squirrel
//
//  Created by Mike on 2024/12/13.
//

import Cocoa

class AnimateNSTextView: NSTextView {
    
    private var animationKey: String = "positionAnimation"
    
    private var oldFrame: NSRect = .zero
    
    override var frame: NSRect {
        
        didSet {
          print("AnimateNSTextView.bounds:\(self.bounds)")
            if oldFrame == .zero{
                oldFrame = frame
            }
            
            // 仅当位置改变时触发动画
            if frame.origin != oldFrame.origin {
                // 确保在动画之前更新layer的position
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.layer?.position = CGPoint(x: frame.origin.x, y: frame.origin.y)
                CATransaction.commit()
                
                // 创建一个动画，将视图从当前位置平滑移动到新位置
                let animation = CABasicAnimation(keyPath: "position")
                animation.fromValue = self.layer?.presentation()?.position ?? NSValue(point: CGPoint(x: oldFrame.origin.x, y: oldFrame.origin.y))
                animation.toValue = NSValue(point: CGPoint(x: frame.origin.x, y: frame.origin.y))
                animation.duration = 1 // 动画持续时间
                animation.timingFunction = CAMediaTimingFunction(name: .default) // 动画缓动函数
                
                // 如果当前有动画在运行，从当前动画位置开始新的动画
                if let currentAnimation = self.layer?.animation(forKey: animationKey) {
                    animation.fromValue = self.layer?.presentation()?.position
                }
                
//                // 移除当前动画，并添加新动画
                self.layer?.removeAnimation(forKey: animationKey)
                self.layer?.add(animation, forKey: animationKey)
            }
            self.oldFrame = frame
        }
    }
}



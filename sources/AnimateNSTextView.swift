//
//  SmoothTextView.swift
//  Squirrel
//
//  Created by Mike on 2024/12/13.
//

import Cocoa
///当前选择用NSTextField而非NSTextView是因为NSTextField有个性质是能在其文本被设定后自动更新其intrinsicContentSize，而NSTextView原生不支持，
///如果后续有换NSTextView，再解决这个不能自动更新本征尺寸的问题
class AnimateNSTextView: NSTextField {
  
  private var animationKey: String = "positionAnimation"
  private var oldFrame: NSRect = .null
  
  override var frame: NSRect {
    didSet {
      print("AnimateNSTextView.bounds:\(self.bounds)")
      if oldFrame == .null{
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


//class AnimateNSTextView1111: NSTextField {
//  
//  private var animationKey: String = "positionAnimation"
//  private var oldFrame: NSRect = .null
//    
//  override var frame: NSRect {
//      
//      didSet {
//        print("AnimateNSTextView.bounds:\(self.bounds)")
//          if oldFrame == .null{
//              oldFrame = frame
//          }
//          
//          // 仅当位置改变时触发动画
//          if frame.origin != oldFrame.origin {
//              // 确保在动画之前更新layer的position
//              CATransaction.begin()
//              CATransaction.setDisableActions(true)
//              self.layer?.position = CGPoint(x: frame.origin.x, y: frame.origin.y)
//              CATransaction.commit()
//              
//              // 创建一个动画，将视图从当前位置平滑移动到新位置
//              let animation = CABasicAnimation(keyPath: "position")
//              animation.fromValue = self.layer?.presentation()?.position ?? NSValue(point: CGPoint(x: oldFrame.origin.x, y: oldFrame.origin.y))
//              animation.toValue = NSValue(point: CGPoint(x: frame.origin.x, y: frame.origin.y))
//              animation.duration = 1 // 动画持续时间
//              animation.timingFunction = CAMediaTimingFunction(name: .default) // 动画缓动函数
//              
//              // 如果当前有动画在运行，从当前动画位置开始新的动画
//              if let currentAnimation = self.layer?.animation(forKey: animationKey) {
//                  animation.fromValue = self.layer?.presentation()?.position
//              }
//              
////                // 移除当前动画，并添加新动画
//              self.layer?.removeAnimation(forKey: animationKey)
//              self.layer?.add(animation, forKey: animationKey)
//          }
//          self.oldFrame = frame
//      }
//  }
//  
//  override func removeFromSuperview() {
//          // 开始动画
//          NSAnimationContext.beginGrouping()
//          NSAnimationContext.current.duration = 1.0 // 动画持续时间为1秒
//          NSAnimationContext.current.completionHandler = {
//              super.removeFromSuperview() // 动画完成后，调用父类的removeFromSuperview
//          }
//          
//          // 执行淡出动画
//          self.animator().alphaValue = 0.0
//          
//          // 结束动画组
//          NSAnimationContext.endGrouping()
//      }
//  private var placeholderWidth: CGFloat? = 0
//  /// Field editor inset; experimental value
//  private let rightMargin: CGFloat = 5
//
//  private var lastSize: NSSize?
//  private var isEditing = false
//  override var intrinsicContentSize: NSSize {
//      var minSize: NSSize {
//          var size = super.intrinsicContentSize
//          size.width = self.placeholderWidth ?? 0
//          return size
//      }
//
//      // Use cached value when not editing
//      guard isEditing,
//          let fieldEditor = self.window?.fieldEditor(false, for: self) as? NSTextView
//          else { return self.lastSize ?? minSize }
//
//      // Make room for the placeholder when the text field is empty
//      guard !fieldEditor.string.isEmpty else {
//          self.lastSize = minSize
//          return minSize
//      }
//
//      // Use the field editor's computed width when possible
//      guard let container = fieldEditor.textContainer,
//          let newWidth = container.layoutManager?.usedRect(for: container).width
//          else { return self.lastSize ?? minSize }
//
//      var newSize = super.intrinsicContentSize
//      newSize.width = newWidth + rightMargin
//
//      self.lastSize = newSize
//
//      return newSize
//  }
  
//}



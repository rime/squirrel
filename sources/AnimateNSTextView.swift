//
//  SmoothTextView.swift
//  Squirrel
//
//  Created by Mike on 2024/12/13.
//

import Cocoa
/// 当前选择用NSTextField而非NSTextView是因为NSTextField有个性质是能在其文本被设定后自动更新其intrinsicContentSize，而NSTextView原生不支持，
/// 如果后续有换NSTextView，再解决这个不能自动更新本征尺寸的问题
class AnimateNSTextView: NSTextField {
  
  private var animationKey: String = "positionAnimation"
  var animationOn = true
  private var animationType:CAMediaTimingFunctionName = .easeOut //这个类型不能乱设，要通过Str间接设置
  var animationDuration: Double = 0.2
  
  //转换传入的字符串为CAMediaTimingFunctionName格式
  var animationTypeStr: String = "easeOut" {
    didSet {
      let timingFunctionMap: [String: CAMediaTimingFunctionName] = [
        "default": .default,
        "linear": .linear,
        "easeIn": .easeIn,
        "easeOut": .easeOut,
        "easeInEaseOut": .easeInEaseOut,
      ]
      // 根据theme.frameType的值来设置动画的timingFunction
      if let timingFunctionName = timingFunctionMap[animationTypeStr] {
        animationType = timingFunctionName
      } else {
        print("AnimateNSTextView类传入的动画类型错误")
      }
    }
  }
  
  override var frame: NSRect {
    didSet {
      // 仅当位置改变时触发动画
      if animationOn{
        // 确保在动画之前更新layer的position
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.layer?.position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        CATransaction.commit()
        
        // 创建一个动画，将视图从当前位置平滑移动到新位置
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = self.layer?.presentation()?.position ?? NSValue(point: CGPoint(x: oldValue.origin.x, y: oldValue.origin.y))
        animation.toValue = NSValue(point: CGPoint(x: frame.origin.x, y: frame.origin.y))
        animation.duration = animationDuration // 动画持续时间
        animation.timingFunction = CAMediaTimingFunction(name: animationType) // 动画缓动函数
        
        // 如果当前有动画在运行，从当前动画位置开始新的动画
        if ((self.layer?.animation(forKey: animationKey)) != nil) {
          animation.fromValue = self.layer?.presentation()?.position
        }
        
        // 移除当前动画，并添加新动画
        self.layer?.removeAnimation(forKey: animationKey)
        self.layer?.add(animation, forKey: animationKey)
      }
    }
  }
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
}



//import Cocoa
//
//class AnimateNSTextView: NSTextField {
//  private var oldFrame: NSRect = .null
//  private var animationKey: String = "positionAnimation"
//  var animationOn = true
//  private var animationType: CATransitionType = .fade
//  var animationDuration: Double = 0.2
//  
//  // 转换传入的字符串为CATransition类型
//  var animationTypeStr: String = "easeOut" {
//    didSet {
//      let transitionTypeMap: [String: CATransitionType] = [
//        "fade": .fade,
//        "moveIn": .moveIn,
//        "push": .push,
//        "reveal": .reveal
//      ]
//      
//      if let transitionType = transitionTypeMap[animationTypeStr] {
//        animationType = transitionType
//      } else {
//        print("AnimateNSTextView类传入的动画类型错误")
//      }
//    }
//  }
//  
//  override var frame: NSRect {
//    willSet {
//      if animationOn {
//        // 创建一个transition动画，将视图从当前位置平滑移动到新位置
//        let transition = CATransition()
//        transition.type = .moveIn
//        transition.duration = animationDuration
//        transition.timingFunction = CAMediaTimingFunction(name: .easeOut) // 可以根据需要调整
//        
//        // 确保在动画之前更新layer的position
//        CATransaction.begin()
//        CATransaction.setDisableActions(true)
//        self.layer?.position = CGPoint(x: newValue.origin.x, y: newValue.origin.y)
//        CATransaction.commit()
//        
//        // 添加动画到layer
//        self.layer?.add(transition, forKey: animationKey)
//      }
//    }
//    
//    
//  }
//}

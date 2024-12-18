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
  var animationInterruptType = "smooth"
  private var oldTextLayer = CATextLayer()
  
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
  
  var isTurning = 0 // 0:不翻页 1：往下翻页 -1 往上翻页
  var page = 0 {
    didSet{
      if page == oldValue{
        isTurning = 0
      }else if page > oldValue{
        isTurning = 1
      }else {
        isTurning = -1
      }
    }
  }
  
  override var frame: NSRect {
    didSet {
      if isTurning == 0{
        animateInPage(oldValue, frame)
      }
    }
  }
  
  override var attributedStringValue: NSAttributedString {
    willSet {
      
      // 复制 CATextLayer 特有的属性
      oldTextLayer.frame = self.frame
      if let attributedString = self.attributedStringValue as CFAttributedString? {
        oldTextLayer.string = attributedString
        print("拷贝富文本成功")
      }else{
        print("拷贝富文本失败")
      }
      
      if isTurning == 1{
        animateCrossPage()
      }else if isTurning == -1{
        animateCrossPage()
      }
    }
  }
  
  

  
  //翻页动画
  func animateCrossPage(){
    print("准备执行翻页动画")
    oldTextLayer.isHidden = false
    // 文本已经改变，现在可以执行动画了
    if let newTextLayer = self.layer{
      print("开始翻页动画")
      oldTextLayer.frame = newTextLayer.frame
      // 确保oldTextLayer在正确的层级
//      self.layer?.addSublayer(oldTextLayer)
      // 将CATextLayer添加到视图层级中，作为NSTextField的兄弟layer
      if let textFieldSuperview = self.superview {
          textFieldSuperview.layer?.addSublayer(oldTextLayer)
      }
      
      print("oldTextLayer.position.y",oldTextLayer.position.y)
      print("newTextLayer.position.y",newTextLayer.position.y)
      
      // 旧layer（复制layer）退出动画
      let oldLayerAnimation = CABasicAnimation(keyPath: "position.y")
      oldLayerAnimation.fromValue = self.frame.midY
      oldLayerAnimation.toValue = self.frame.midY + self.frame.height*CGFloat(isTurning) // 向上移动20个单位
      oldLayerAnimation.duration = 0.2
      oldLayerAnimation.fillMode = .forwards
      oldLayerAnimation.isRemovedOnCompletion = true
      oldTextLayer.add(oldLayerAnimation, forKey: nil)
      
      
      // 新layer（自有layer）入场动画
      let layerAnimation = CABasicAnimation(keyPath: "position.y")
      layerAnimation.fromValue = self.frame.origin.y - self.frame.height*CGFloat(isTurning)
      layerAnimation.toValue = self.frame.origin.y // 向上移动20个单位
      layerAnimation.duration = 0.2
//      layerAnimation.fillMode = .forwards
      layerAnimation.isRemovedOnCompletion = true
      newTextLayer.add(layerAnimation, forKey: nil)
      
      
      
      // 动画完成后，移除oldTextLayer
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
        self.oldTextLayer.isHidden = true
      }
    }
  }
  
  //不翻页位移动画
  func animateInPage(_ oldFrame:NSRect, _ newFrame:NSRect){
    // 仅当位置改变时触发动画
    if animationOn{
      if oldFrame == NSRect(x: 0, y: 0, width: 0, height: 0){//跳过第一次动画防止飞入效果
        return
      }
//        // 确保在动画之前更新layer的position
//        CATransaction.begin()
//        CATransaction.setDisableActions(true)
//        self.layer?.position = CGPoint(x: frame.origin.x, y: frame.origin.y)
//        CATransaction.commit()
      
      // 创建一个动画，将视图从当前位置平滑移动到新位置
      let animation = CABasicAnimation(keyPath: "position")
      if animationInterruptType == "smooth"{
        animation.fromValue = self.layer?.presentation()?.position ?? NSValue(point: CGPoint(x: oldFrame.origin.x, y: oldFrame.origin.y))
      }else if animationInterruptType == "interrupt"{
        animation.fromValue = NSValue(point: CGPoint(x: oldFrame.origin.x, y: oldFrame.origin.y))
      }
      animation.toValue = NSValue(point: CGPoint(x: newFrame.origin.x, y: newFrame.origin.y))
      animation.duration = animationDuration // 动画持续时间
      animation.timingFunction = CAMediaTimingFunction(name: animationType) // 动画缓动函数
      
//        // 如果当前有动画在运行，从当前动画位置开始新的动画
//        if animationInterruptType == "smooth"{
//          print("animationInterruptType",animationInterruptType)
//          if ((self.layer?.animation(forKey: animationKey)) != nil) {
//            animation.fromValue = self.layer?.presentation()?.position
//          }
//        }
      
      // 移除当前动画，并添加新动画
      self.layer?.removeAnimation(forKey: animationKey)
      self.layer?.add(animation, forKey: animationKey)
    }
  }
}


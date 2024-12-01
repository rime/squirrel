//
//  TextView.swift
//  Demo
//
//  Created by mi on 2024/11/3.
//

import Cocoa
import InputMethodKit

extension NSTextView {
  func currentCursorRect() -> NSRect? {
    guard let selectedRange = self.selectedRanges.first as? NSRange else {
      return nil
    }

    var rect = NSRect.zero
    self.layoutManager?.enumerateEnclosingRects(
      forGlyphRange: selectedRange,
      withinSelectedGlyphRange: selectedRange,
      in: self.textContainer!,
      using: { glyphRect, _ in
        rect = glyphRect
      }
    )

    return self.window?.convertToScreen(self.convert(rect, to: nil))
  }
}

class Client: NSObject, IMKTextInput {
  weak var textView: NSTextView?
  init(textView: NSTextView?) {
    self.textView = textView
  }

  func bundleIdentifier() -> String! {
    Bundle.main.bundleIdentifier
  }

  func attributes(forCharacterIndex index: Int, lineHeightRectangle lineRect: UnsafeMutablePointer<NSRect>!) -> [AnyHashable : Any]! {
    if let rect = textView?.currentCursorRect() {
      lineRect.pointee = rect
    }
    return nil
  }
  var replacementRange: NSRange?
  func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {
    guard let textView else {
      return
    }
    if let length = (string as? NSAttributedString)?.length, length == 0 {
      if let replacementRange = self.replacementRange, replacementRange.length == 1 {
        textView.insertText("", replacementRange: replacementRange)
      }
      self.replacementRange = nil
      return
    }

    guard let firstRange = textView.selectedRanges.first?.rangeValue else {
      return
    }
    if self.replacementRange == nil {
      self.replacementRange = firstRange
    }
    guard let replacementRange = self.replacementRange else {
      return
    }

    textView.setMarkedText(string as Any, selectedRange: selectionRange, replacementRange: replacementRange)
    if let string = string as? String {
      self.replacementRange?.length = string.count
    } else if let string = string as? NSAttributedString {
      self.replacementRange?.length = string.length
    }
  }

  func insertText(_ string: Any!, replacementRange: NSRange) {
    guard let string = string as? String, let textView = textView, let replacementRange = self.replacementRange else {
      return
    }
    textView.insertText(string, replacementRange: replacementRange)
  }
}

class TextView: NSTextView {
  lazy var client = Client(textView: self)
  lazy var inputController = (NSClassFromString("SquirrelInputController") as! IMKInputController.Type).init(server: nil, delegate: nil, client: client)!

  override func keyDown(with event: NSEvent) {
    if inputController.handle(event, client: client) {
      return
    }
    super.keyDown(with: event)
  }
}

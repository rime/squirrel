//
//  Unused.swift
//  Jyutping
//
//  Created by mi on 2024/11/3.
//

import Cocoa
import InputMethodKit

extension Client {
	func validAttributesForMarkedText() -> [Any]! {
		fatalError()
	}

	func selectedRange() -> NSRange {
		fatalError()
	}

	func markedRange() -> NSRange {
		fatalError()
	}

	func attributedSubstring(from range: NSRange) -> NSAttributedString! {
		fatalError()
	}

	func length() -> Int {
		fatalError()
	}

	func characterIndex(for point: NSPoint, tracking mappingMode: IMKLocationToOffsetMappingMode, inMarkedRange: UnsafeMutablePointer<ObjCBool>!) -> Int {
		fatalError()
	}

	func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {
		fatalError()
	}

	func selectMode(_ modeIdentifier: String!) {
		fatalError()
	}

	func supportsUnicode() -> Bool {
		fatalError()
	}

	func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool {
		fatalError()
	}

	func string(from range: NSRange, actualRange: NSRangePointer!) -> String! {
		fatalError()
	}

	func firstRect(forCharacterRange aRange: NSRange, actualRange: NSRangePointer!) -> NSRect {
		fatalError()
	}

  func windowLevel() -> CGWindowLevel {
    fatalError()
  }

  func uniqueClientIdentifierString() -> String! {
    fatalError()
  }
}

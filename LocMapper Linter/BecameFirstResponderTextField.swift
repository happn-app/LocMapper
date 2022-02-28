/*
 * BecameFirstResponderTextField.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 12/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import AppKit



@objc
protocol BecameFirstResponderTextFieldDelegate : NSTextFieldDelegate {
	
	@objc optional func didBecomeFirstResponder(_ textField: NSTextField)
	
}

/* Would be great to have an extender for that… */
class BecameFirstResponderTextField : NSTextField {
	
	override func becomeFirstResponder() -> Bool {
		let r = super.becomeFirstResponder()
		if r {(delegate as? BecameFirstResponderTextFieldDelegate)?.didBecomeFirstResponder?(self)}
		return r
	}
	
}

/*
 * NoEditOnEnterTableView.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 13/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import AppKit



/* An extender would be great here to replace this class! */
class NoEditOnEnterTableView : NSTableView {
	
	override func keyDown(with event: NSEvent) {
		guard event.safeCharactersIgnoringModifiers??.first?.unicodeScalars.first != UnicodeScalar(NSCarriageReturnCharacter) else {
			nextResponder?.keyDown(with: event)
			return
		}
		super.keyDown(with: event)
	}
	
}


extension NSEvent {
	
	var safeCharactersIgnoringModifiers: String?? {
		guard type == .keyUp || type == .keyDown else {return nil}
		return .some(charactersIgnoringModifiers)
	}
	
}

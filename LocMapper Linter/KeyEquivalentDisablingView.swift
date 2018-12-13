/*
 * KeyEquivalentDisablingView.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 12/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import AppKit



/* An extender would be great here to replace this class!
 * Note: An interesting thread with another solution to the same problem:
 *       https://forums.developer.apple.com/thread/78806 */
class KeyEquivalentDisablingView : NSView {
	
	var disableKeyEquivalent = false
	
	override func performKeyEquivalent(with event: NSEvent) -> Bool {
		return (disableKeyEquivalent ? false : super.performKeyEquivalent(with: event))
	}
	
}

/*
 * UINavigationUtilities.swift
 * LocMapper App
 *
 * Created by François Lamboley on 2016-07-11.
 * Copyright © 2016 happn. All rights reserved.
 */

import AppKit



private extension NSNib.Name {
	
	static let loadingWindow = "LoadingWindow"
	
}

class UINavigationUtilities {
	
	@MainActor
	static func createLoadingWindow() -> NSWindow {
		var objects: NSArray?
		Bundle.main.loadNibNamed(.loadingWindow, owner: nil, topLevelObjects: &objects)
		let window = (objects ?? []).compactMap{ $0 as? NSWindow }.first!
		for v in window.contentView!.subviews.first!.subviews {
			if let p = v as? NSProgressIndicator {
				p.startAnimation(nil)
			}
		}
		return window
	}
	
}

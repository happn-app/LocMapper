/*
 * UINavigationUtilities.swift
 * Localizer App
 *
 * Created by François Lamboley on 7/11/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import AppKit



private extension NSNib.Name {
	
	static let loadingWindow = NSNib.Name(rawValue: "LoadingWindow")
	
}

class UINavigationUtilities {
	
	static func createLoadingWindow() -> NSWindow {
		var objects: NSArray?
		Bundle.main.loadNibNamed(.loadingWindow, owner: nil, topLevelObjects: &objects)
		let window = (objects ?? []).flatMap{ $0 as? NSWindow }.first!
		for v in window.contentView!.subviews.first!.subviews {
			if let p = v as? NSProgressIndicator {
				p.startAnimation(nil)
			}
		}
		return window
	}
	
}

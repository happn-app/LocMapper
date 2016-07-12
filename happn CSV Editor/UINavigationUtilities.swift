/*
 * UINavigationUtilities.swift
 * Localizer
 *
 * Created by François Lamboley on 7/11/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import AppKit



class UINavigationUtilities {
	
	static func createLoadingWindow() -> NSWindow {
		var objects: NSArray = []
		Bundle.main.loadNibNamed("LoadingWindow", owner: nil, topLevelObjects: &objects)
		let window = (objects.filter {$0 is NSWindow} as! [NSWindow]).first!
		for v in window.contentView!.subviews.first!.subviews {
			if let p = v as? NSProgressIndicator {
				p.startAnimation(nil)
			}
		}
		return window
	}
	
}

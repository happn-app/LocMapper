/*
 * happnLocCSVDocOptionsSplitViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class happnLocCSVDocOptionsSplitViewController : NSSplitViewController {
	
	@IBOutlet var splitItemOptions: NSSplitViewItem!
	@IBOutlet var splitItemContent: NSSplitViewItem!
	
	override var representedObject: AnyObject? {
		didSet {
			splitItemContent.viewController.representedObject = representedObject
		}
	}
	
}

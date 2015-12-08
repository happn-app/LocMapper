/*
 * happnLocCSVDocContentSplitViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class happnLocCSVDocContentSplitViewController : NSSplitViewController {
	
	@IBOutlet var splitItemTableView: NSSplitViewItem!
	
	override var representedObject: AnyObject? {
		didSet {
			splitItemTableView.viewController.representedObject = representedObject
		}
	}
	
}

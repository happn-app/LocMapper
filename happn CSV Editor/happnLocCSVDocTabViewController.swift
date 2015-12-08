/*
 * happnLocCSVDocTabViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class happnLocCSVDocTabViewController : NSTabViewController {
	
	@IBOutlet var tabViewItemDocContent: NSTabViewItem!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
	}
	
	override var representedObject: AnyObject? {
		didSet {
			tabViewItemDocContent.viewController?.representedObject = representedObject
			if representedObject == nil {self.selectedTabViewItemIndex = 0}
			else                        {self.selectedTabViewItemIndex = 1}
		}
	}
	
}

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
	
	override var representedObject: Any? {
		didSet {
			optionsSplitViewController.representedObject = representedObject
			if representedObject == nil {self.selectedTabViewItemIndex = 0}
			else                        {self.selectedTabViewItemIndex = 1}
		}
	}
	
	/** Changes after view did load are ignored. */
	var handlerNotifyDocumentModification: (() -> Void)? {
		didSet {
			optionsSplitViewController.handlerNotifyDocumentModification = handlerNotifyDocumentModification
		}
	}
	
	@IBAction func showFilters(_ sender: AnyObject!) {
		optionsSplitViewController.showFilters(sender)
	}
	
	@IBAction func showEntryDetails(_ sender: AnyObject!) {
		optionsSplitViewController.showEntryDetails(sender)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
	}
	
	private var optionsSplitViewController: happnLocCSVDocOptionsSplitViewController! {
		return tabViewItemDocContent.viewController as? happnLocCSVDocOptionsSplitViewController
	}
	
}

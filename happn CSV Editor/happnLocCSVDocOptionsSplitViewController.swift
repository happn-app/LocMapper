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
			optionsViewController.representedObject = representedObject
			contentViewController.representedObject = representedObject
		}
	}
	
	var handlerNotifyDocumentModification: (() -> Void)? {
		didSet {
			optionsViewController.handlerNotifyDocumentModification = handlerNotifyDocumentModification
			contentViewController.handlerNotifyDocumentModification = handlerNotifyDocumentModification
		}
	}
	
	@IBAction func showFilters(_ sender: AnyObject!) {
		let dividerIndex = 0
		self.splitView.setPosition(150, ofDividerAt: dividerIndex)
	}
	
	@IBAction func showEntryDetails(_ sender: AnyObject!) {
		contentViewController.showEntryDetails(sender)
	}
	
	private var optionsViewController: happnLocCSVDocOptionsViewController! {
		return splitItemOptions.viewController as? happnLocCSVDocOptionsViewController
	}
	
	private var contentViewController: happnLocCSVDocContentSplitViewController! {
		return splitItemContent.viewController as? happnLocCSVDocContentSplitViewController
	}
	
}

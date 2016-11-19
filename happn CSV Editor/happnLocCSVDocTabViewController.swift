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
	
	var uiState: [String: Any] {
		return [:]
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
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
	
	func noteContentHasChanged() {
		optionsSplitViewController.noteContentHasChanged()
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func showFilters(_ sender: AnyObject!) {
		optionsSplitViewController.showFilters(sender)
	}
	
	@IBAction func showEntryDetails(_ sender: AnyObject!) {
		optionsSplitViewController.showEntryDetails(sender)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var optionsSplitViewController: happnLocCSVDocFiltersSplitViewController! {
		return tabViewItemDocContent.viewController as? happnLocCSVDocFiltersSplitViewController
	}
	
}

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
	@IBOutlet var splitItemLocEntry: NSSplitViewItem!
	
	override var representedObject: Any? {
		didSet {
			tableViewController.representedObject = representedObject
		}
	}
	
	var handlerNotifyDocumentModification: (() -> Void)? {
		didSet {
			tableViewController.handlerNotifyDocumentModification = handlerNotifyDocumentModification
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		/* We assume the table view controller will not change later. */
		tableViewController.handlerSetEntryViewSelection = { [weak self] keyVal in
			if let keyVal = keyVal {self?.locEntryViewController.representedObject = LocEntryViewController.LocEntry(lineKey: keyVal.0, lineValue: keyVal.1)}
			else                   {self?.locEntryViewController.representedObject = nil}
		}
	}
	
	@IBAction func showEntryDetails(_ sender: AnyObject!) {
		let dividerIndex = 0
		self.splitView.setPosition(self.view.bounds.size.height - 150, ofDividerAt: dividerIndex)
	}
	
	private var tableViewController: happnLocCSVDocTableViewController! {
		return splitItemTableView.viewController as? happnLocCSVDocTableViewController
	}
	
	private var locEntryViewController: LocEntryViewController! {
		return splitItemLocEntry.viewController as? LocEntryViewController
	}
	
}

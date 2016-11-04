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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		/* We assume the children view controllers will not change later. */
		tableViewController.handlerSetEntryViewSelection = { [weak self] keyVal in
			if let keyVal = keyVal {self?.locEntryViewController.representedObject = LocEntryViewController.LocEntry(lineKey: keyVal.0, lineValue: keyVal.1)}
			else                   {self?.locEntryViewController.representedObject = nil}
		}
		locEntryViewController.handlerSearchMappingKey = { [weak self] str in
			guard let locFile = self?.representedObject as? happnCSVLocFile else {return []}
			return locFile.entryKeys(matchingFilters: [.string(str), .env("RefLoc"), .stateHardCodedValues])
		}
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
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
	
	func noteContentHasChanged() {
		tableViewController.noteContentHasChanged()
	}
	
	func noteFiltersHaveChanged() {
		tableViewController.noteFiltersHaveChanged()
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func showEntryDetails(_ sender: AnyObject!) {
		let dividerIndex = 0
		self.splitView.setPosition(self.view.bounds.size.height - 150, ofDividerAt: dividerIndex)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var tableViewController: happnLocCSVDocTableViewController! {
		return splitItemTableView.viewController as? happnLocCSVDocTableViewController
	}
	
	private var locEntryViewController: LocEntryViewController! {
		return splitItemLocEntry.viewController as? LocEntryViewController
	}
	
}

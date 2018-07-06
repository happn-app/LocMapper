/*
 * LocFileDocFiltersSplitViewController.swift
 * LocMapper App
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa

import LocMapper



class LocFileDocFiltersSplitViewController : NSSplitViewController {
	
	@IBOutlet var splitItemFilters: NSSplitViewItem!
	@IBOutlet var splitItemContent: NSSplitViewItem!
	
	var uiState: [String: Any] {
		return (["DocFiltersSplitViewController Split Left Width": splitView.subviews.first?.frame.width ?? -1] as [String: Any])
			.merging(filtersViewController.uiState, uniquingKeysWith: { old, _ in old })
			.merging(contentViewController.uiState, uniquingKeysWith: { old, _ in old })
	}
	
	func restoreUIState(with uiState: [String: Any]) {
		if let width = uiState["DocFiltersSplitViewController Split Left Width"] as? CGFloat, width > 0 {
			splitView.setPosition(width, ofDividerAt: 0)
		}
		filtersViewController.restoreUIState(with: uiState)
		contentViewController.restoreUIState(with: uiState)
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	override var representedObject: Any? {
		didSet {
			filtersViewController.representedObject = (representedObject as? LocFile)?.filtersMetadataValueForKey("filters")
			contentViewController.representedObject = representedObject
		}
	}
	
	var handlerNotifyDocumentModification: (() -> Void)? {
		didSet {
			filtersViewController.handlerNotifyFiltersModification = { [weak self] in
				guard let strongSelf = self else {return}
				guard let filters = strongSelf.filtersViewController.representedObject as? [LocFile.Filter] else {return}
				
				_ = try? (strongSelf.representedObject as? LocFile)?.setMetadataValue(filters, forKey: "filters")
				strongSelf.contentViewController.noteFiltersHaveChanged()
				strongSelf.handlerNotifyDocumentModification?()
			}
			contentViewController.handlerNotifyDocumentModification = handlerNotifyDocumentModification
		}
	}
	
	func noteContentHasChanged() {
		contentViewController.noteContentHasChanged()
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func showFilters(_ sender: AnyObject!) {
		let dividerIndex = 0
		splitView.setPosition(150, ofDividerAt: dividerIndex)
	}
	
	@IBAction func showEntryDetails(_ sender: AnyObject!) {
		contentViewController.showEntryDetails(sender)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var filtersViewController: LocFileDocFiltersViewController! {
		return splitItemFilters.viewController as? LocFileDocFiltersViewController
	}
	
	private var contentViewController: LocFileDocContentSplitViewController! {
		return splitItemContent.viewController as? LocFileDocContentSplitViewController
	}
	
}

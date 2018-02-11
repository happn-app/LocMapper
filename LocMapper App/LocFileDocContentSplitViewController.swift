/*
 * LocFileDocContentSplitViewController.swift
 * LocMapper App
 *
 * Created by François Lamboley on 12/8/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa

import LocMapper



class LocFileDocContentSplitViewController : NSSplitViewController {
	
	@IBOutlet var splitItemTableView: NSSplitViewItem!
	@IBOutlet var splitItemLocEntry: NSSplitViewItem!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		/* We assume the children view controllers will not change later. */
		tableViewController.handlerCanChangeSelection = { [weak self] handlerDoitNow in
			guard let strongSelf = self else {return false}
			guard !strongSelf.askingForSelectionChange else {return false}
			
			guard !strongSelf.locEntryViewController.dirty else {
				if let window = strongSelf.view.window {
					if AppSettings.shared.showAlertForSelectionChangeDiscardMappingEdition {
						strongSelf.askingForSelectionChange = true
						let alert = NSAlert()
						alert.messageText = "Unsaved Changes"
						alert.informativeText = "Your changes will be lost if you change the selected entry."
						alert.addButton(withTitle: "Cancel")
						alert.addButton(withTitle: "Change Anyway")
						alert.showsSuppressionButton = true
						alert.beginSheetModal(for: window) { response in
							switch response {
							case .alertFirstButtonReturn:
								(/*nop (cancel)*/)
								
							case .alertSecondButtonReturn:
								strongSelf.locEntryViewController.discardEditing()
								
								handlerDoitNow()
								
								/* Let's check if the user asked not to be bothered by this
								 * alert anymore. */
								if (alert.suppressionButton?.state ?? .off) == .on {
									AppSettings.shared.showAlertForSelectionChangeDiscardMappingEdition = false
								}
								
							default:
								NSLog("%@", "Unknown button response \(response)")
							}
							strongSelf.askingForSelectionChange = false
						}
					} else {
						strongSelf.locEntryViewController.discardEditing()
						return true
					}
				}
				return false
			}
			return true
		}
		tableViewController.handlerSetEntryViewSelection = { [weak self] keyVal in
			if let keyVal = keyVal {self?.locEntryViewController.representedObject = LocEntryViewController.LocEntry(lineKey: keyVal.0, lineValue: keyVal.1)}
			else                   {self?.locEntryViewController.representedObject = nil}
		}
		locEntryViewController.handlerSearchMappingKey = { [weak self] str in
			guard let locFile = self?.representedObject as? LocFile else {return []}
			return locFile.entryKeys(matchingFilters: [.string(str), .env("RefLoc"), .stateHardCodedValues, .uiPresentable])
		}
		locEntryViewController.handlerLineKeyToString = { [weak self] linekey in
			guard let locFile = self?.representedObject as? LocFile else {return "<Internal Error>"}
			if let firstLanguage = locFile.languages.first {return locFile.editorDisplayedValueForKey(linekey, withLanguage: firstLanguage).replacingOccurrences(of: "\n", with: "\\n") + " (" + Utils.lineKeyToStr(linekey) + ")"}
			else                                           {return Utils.lineKeyToStr(linekey)}
		}
		locEntryViewController.handlerNotifyLineValueModification = { [weak self] in
			guard let strongSelf = self else {return}
			guard let locFile = strongSelf.representedObject as? LocFile else {return}
			guard let locEntry = strongSelf.locEntryViewController.representedObject as? LocEntryViewController.LocEntry else {return}
			_ = locFile.setValue(locEntry.lineValue, forKey: locEntry.lineKey)
			strongSelf.tableViewController.noteSelectedLineHasChanged()
			strongSelf.handlerNotifyDocumentModification?()
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
	
	private var askingForSelectionChange = false
	
	private var tableViewController: LocFileDocTableViewController! {
		return splitItemTableView.viewController as? LocFileDocTableViewController
	}
	
	private var locEntryViewController: LocEntryViewController! {
		return splitItemLocEntry.viewController as? LocEntryViewController
	}
	
}

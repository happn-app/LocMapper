/*
 * LocEntryViewController.swift
 * happn CSV Editor
 *
 * Created by François Lamboley on 12/2/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class LocEntryViewController: NSTabViewController {
	
	class LocEntry {
		let lineKey: happnCSVLocFile.LineKey
		let lineValue: happnCSVLocFile.LineValue
		
		init(lineKey k: happnCSVLocFile.LineKey, lineValue v: happnCSVLocFile.LineValue) {
			lineKey = k
			lineValue = v
		}
	}
	
	var dirty: Bool {
		return locEntryMappingViewController.dirty || locEntryAdvancedMappingViewController.dirty
	}
	
	@IBOutlet var tabViewItemContext: NSTabViewItem!
	@IBOutlet var tabViewItemMapping: NSTabViewItem!
	@IBOutlet var tabViewItemAdvancedMapping: NSTabViewItem!
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	override var representedObject: Any? {
		didSet {
			locEntryContextViewController.representedObject = representedObject
			locEntryMappingViewController.representedObject = representedObject
			locEntryAdvancedMappingViewController.representedObject = representedObject
		}
	}
	
	var handlerSearchMappingKey: ((_ inputString: String) -> [happnCSVLocFile.LineKey])? {
		didSet {
			locEntryMappingViewController.handlerSearchMappingKey = handlerSearchMappingKey
		}
	}
	
	var handlerSetEntryMapping: ((_ newMapping: happnCSVLocFile.happnCSVLocKeyMapping?, _ forEntry: LocEntry) -> Void)? {
		didSet {
			locEntryMappingViewController.handlerSetEntryMapping = handlerSetEntryMapping
			locEntryAdvancedMappingViewController.handlerSetEntryMapping = handlerSetEntryMapping
		}
	}
	
	/* **************************
	   MARK: - NSTabView Delegate
	   ************************** */
	
	override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
		guard !dirty else {
			if let window = view.window {
				if AppSettings.shared.showAlertForTabChangeDiscardMappingEdition {
					let alert = NSAlert()
					alert.messageText = "Unsaved Changes"
					alert.informativeText = "Your changes will be lost if you change the selected tab."
					alert.addButton(withTitle: "Cancel")
					alert.addButton(withTitle: "Change Anyway")
					alert.showsSuppressionButton = true
					alert.beginSheetModal(for: window) { response in
						switch response {
						case NSAlertFirstButtonReturn:
							(/*nop (cancel)*/)
							
						case NSAlertSecondButtonReturn:
							self.locEntryMappingViewController.discardEditing()
							self.locEntryAdvancedMappingViewController.discardEditing()
							
							tabView.selectTabViewItem(tabViewItem)
							
							/* Let's check if the user asked not to be bothered by this
							 * alert anymore. */
							if (alert.suppressionButton?.state ?? NSOffState) == NSOnState {
								AppSettings.shared.showAlertForTabChangeDiscardMappingEdition = false
							}
							
						default:
							NSLog("%@", "Unknown button response \(response)")
						}
					}
				} else {
					self.locEntryMappingViewController.discardEditing()
					self.locEntryAdvancedMappingViewController.discardEditing()
					return super.tabView(tabView, shouldSelect: tabViewItem)
				}
			}
			return false
		}
		return super.tabView(tabView, shouldSelect: tabViewItem)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var locEntryContextViewController: LocEntryContextViewController! {
		return tabViewItemContext.viewController as? LocEntryContextViewController
	}
	
	private var locEntryMappingViewController: LocEntryMappingViewController! {
		return tabViewItemMapping.viewController as? LocEntryMappingViewController
	}
	
	private var locEntryAdvancedMappingViewController: LocEntryAdvancedMappingViewController! {
		return tabViewItemAdvancedMapping.viewController as? LocEntryAdvancedMappingViewController
	}
	
}

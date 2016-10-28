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
	
	var handlerSetEntryMapping: ((_ newMapping: happnCSVLocFile.happnCSVLocKeyMapping?, _ forEntry: LocEntry) -> Void)? {
		didSet {
			locEntryMappingViewController.handlerSetEntryMapping = handlerSetEntryMapping
			locEntryAdvancedMappingViewController.handlerSetEntryMapping = handlerSetEntryMapping
		}
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

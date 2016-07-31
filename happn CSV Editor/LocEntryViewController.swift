/*
 * LocEntryViewController.swift
 * happn CSV Editor
 *
 * Created by François Lamboley on 12/2/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



class LocEntryViewController: NSTabViewController {
	
	@IBOutlet var tabViewItemContext: NSTabViewItem!
	@IBOutlet var tabViewItemMapping: NSTabViewItem!
	@IBOutlet var tabViewItemAdvancedMapping: NSTabViewItem!
	
	class LocEntry {
		let lineKey: happnCSVLocFile.LineKey
		let lineValue: happnCSVLocFile.LineValue
		
		init(lineKey k: happnCSVLocFile.LineKey, lineValue v: happnCSVLocFile.LineValue) {
			lineKey = k
			lineValue = v
		}
	}
	
	override var representedObject: AnyObject? {
		didSet {
			locEntryContextViewController.representedObject = representedObject
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	private var locEntryContextViewController: LocEntryContextViewController! {
		return tabViewItemContext.viewController as? LocEntryContextViewController
	}
	
}

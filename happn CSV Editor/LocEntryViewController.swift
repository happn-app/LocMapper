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
	
	override var representedObject: AnyObject? {
		didSet {
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
}

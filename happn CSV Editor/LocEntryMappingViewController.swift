/*
 * LocEntryMappingViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 8/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa



class LocEntryMappingViewController: NSViewController {
	
	var handlerSetEntryMapping: ((_ newMapping: happnCSVLocFile.happnCSVLocKeyMapping?, _ forEntry: LocEntryViewController.LocEntry) -> Void)?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do view setup here.
	}
	
}

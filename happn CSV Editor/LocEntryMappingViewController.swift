/*
 * LocEntryMappingViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 8/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa



class LocEntryMappingViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate {
	
	@IBOutlet var comboBox: NSComboBox!
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	var handlerSearchMappingKey: ((_ inputString: String) -> [happnCSVLocFile.LineKey])?
	var handlerSetEntryMapping: ((_ newMapping: happnCSVLocFile.happnCSVLocKeyMapping?, _ forEntry: LocEntryViewController.LocEntry) -> Void)?
	
	/* ****************************************
	   MARK: - Combo Box Data Source & Delegate
	   **************************************** */
	
	override func controlTextDidChange(_ obj: Notification) {
		/* Do NOT call super... */
	}
	
	func numberOfItems(in comboBox: NSComboBox) -> Int {
		return possibleLineKeys.count
	}
	
	func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
		return (arc4random() % 2 == 0 ? "a" : "b")
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var possibleLineKeys = Array<happnCSVLocFile.LineKey>()
	
	private var representedMapping: happnCSVLocFile.happnCSVLocKeyMapping? {
		return representedObject as? happnCSVLocFile.happnCSVLocKeyMapping
	}
	
	private func updateAutoCompletion() {
		possibleLineKeys = handlerSearchMappingKey?(comboBox.stringValue) ?? []
		comboBox.reloadData()
	}
	
}

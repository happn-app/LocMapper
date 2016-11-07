/*
 * LocEntryMappingViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 8/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa



class LocEntryMappingViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextDelegate {
	
	private(set) var dirty = false
	
	@IBOutlet var comboBox: NSComboBox!
	@IBOutlet var textViewMappingOptions: NSTextView!
	@IBOutlet var buttonCancelEdition: NSButton!
	@IBOutlet var buttonValidateMapping: NSButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		comboBox.formatter = LineKeyFormatter()
		
		/* The sets the font for all of the text storage and other. Do NOT remove. */
		textViewMappingOptions.font = textViewMappingOptions.font
		textViewMappingOptions.string = ""
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	var handlerSearchMappingKey: ((_ inputString: String) -> [happnCSVLocFile.LineKey])?
	var handlerSetEntryMapping: ((_ newMapping: happnCSVLocFile.happnCSVLocKeyMapping?, _ forEntry: LocEntryViewController.LocEntry) -> Void)?
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	override func discardEditing() {
		super.discardEditing()
		
		/* TODO */
		
		dirty = false
	}
	
	@IBAction func comboBoxAction(_ sender: AnyObject) {
		dirty = true
		
		let idx = comboBox.indexOfSelectedItem
		guard idx >= 0 else {return}
		
		comboBox.cell?.representedObject = possibleLineKeys[idx]
	}
	
	@IBAction func validateAndApplyMapping(_ sender: AnyObject) {
	}
	
	/* ****************************************
	   MARK: - Combo Box Data Source & Delegate
	   **************************************** */
	
	override func controlTextDidChange(_ obj: Notification) {
		/* Do NOT call super... */
		comboBox.cell?.representedObject = nil
		updateAutoCompletion()
		dirty = true
	}
	
	func numberOfItems(in comboBox: NSComboBox) -> Int {
		return possibleLineKeys.count
	}
	
	func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
		return possibleLineKeys[index]
	}
	
	/* ***********************
	   MARK: - NSText Delegate
	   *********************** */
	
	func textDidChange(_ notification: Notification) {
		dirty = true
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
	
	private class LineKeyFormatter : Formatter {
		
		override func string(for obj: Any?) -> String? {
			guard let linekey = obj as? happnCSVLocFile.LineKey else {return "\(obj ?? "")"}
			return Utils.lineKeyToStr(linekey)
		}
		
		override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
			obj?.pointee = string as AnyObject?
			return true
		}
		
	}
	
}

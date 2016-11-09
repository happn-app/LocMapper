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
	@IBOutlet var textViewMappingTransform: NSTextView!
	@IBOutlet var buttonCancelEdition: NSButton!
	@IBOutlet var buttonValidateMapping: NSButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		comboBox.formatter = LineKeyFormatter()
		
		/* The sets the font for all of the text storage and other. Do NOT remove. */
		textViewMappingTransform.font = textViewMappingTransform.font
		textViewMappingTransform.string = ""

		/* Apparently not read from xib... */
		textViewMappingTransform.isAutomaticSpellingCorrectionEnabled = false
		textViewMappingTransform.isAutomaticQuoteSubstitutionEnabled = false
		textViewMappingTransform.isAutomaticDashSubstitutionEnabled = false
		textViewMappingTransform.isAutomaticTextReplacementEnabled = false
		textViewMappingTransform.isContinuousSpellCheckingEnabled = false
		textViewMappingTransform.isAutomaticLinkDetectionEnabled = false
		textViewMappingTransform.smartInsertDeleteEnabled = false
		textViewMappingTransform.isGrammarCheckingEnabled = false
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
		guard let lineKey = comboBox.cell?.representedObject as? happnCSVLocFile.LineKey else {
			/* This should not be possible */
			NSBeep()
			return
		}
		
		do {
			let errorDomain = "Transforms Conversion"
			
			let transformString: String
			if let str = textViewMappingTransform.string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !str.isEmpty {transformString = str}
			else                                                                                                                    {transformString = "[]"}
			
			/* Retrieving transforms from the text view */
			guard let transformData = transformString.data(using: .utf8) else {
				throw NSError(domain: errorDomain, code: 1, userInfo: nil)
			}
			
			/* Deserializing the text using JSON format */
			let jsonObject = try JSONSerialization.jsonObject(with: transformData, options: [])
			let serializedTransforms: [[String: AnyObject]]
			if      let array  = jsonObject as? [[String: AnyObject]] {serializedTransforms = array}
			else if let simple = jsonObject as?  [String: AnyObject]  {serializedTransforms = [simple]}
			else {throw NSError(domain: errorDomain, code: 2, userInfo: nil)}
			
			/* Converting deserialized representations to actual transforms */
			let transforms = try serializedTransforms.map { serialization -> LocValueTransformer in
				let transform = LocValueTransformer.createComponentTransformFromSerialization(serialization)
				guard !(transform is LocValueTransformerInvalid) else {
					throw NSError(domain: errorDomain, code: 3, userInfo: nil)
				}
				return transform
			}
			
			/* Creating the actual mapping entry */
			let mapping = [CSVLocKeyMappingComponentValueTransforms(sourceKey: lineKey, subTransformsComponents: transforms)]
		} catch {
			guard let window = view.window else {NSBeep(); return}
			
			/* If JSONSerialization sent useful error messages... */
//			let alert = NSAlert(error: error)
//			alert.beginSheetModal(for: window, completionHandler: nil)
			
			let alert = NSAlert()
			alert.messageText = "Invalid Transforms"
			alert.informativeText = "Cannot parse given transforms. Please check your JSON and transform syntax."
			alert.addButton(withTitle: "OK")
			alert.beginSheetModal(for: window, completionHandler: nil)
		}
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

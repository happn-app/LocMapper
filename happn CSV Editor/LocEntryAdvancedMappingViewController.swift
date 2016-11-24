/*
 * LocEntryAdvancedMappingViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 8/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa



class LocEntryAdvancedMappingViewController: NSViewController {
	
	private(set) var dirty = false {
		didSet {
			guard dirty != oldValue else {return}
			updateEnabledStates()
		}
	}
	
	@IBOutlet var textViewMapping: NSTextView!
	@IBOutlet var buttonCancelEdition: NSButton!
	@IBOutlet var buttonValidateMapping: NSButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		/* The sets the font for all of the text storage and other. Do NOT remove. */
		textViewMapping.font = textViewMapping.font
		textViewMapping.string = ""
		
		/* Apparently not read from xib... */
		textViewMapping.isAutomaticSpellingCorrectionEnabled = false
		textViewMapping.isAutomaticQuoteSubstitutionEnabled = false
		textViewMapping.isAutomaticDashSubstitutionEnabled = false
		textViewMapping.isAutomaticTextReplacementEnabled = false
		textViewMapping.isContinuousSpellCheckingEnabled = false
		textViewMapping.isAutomaticLinkDetectionEnabled = false
		textViewMapping.smartInsertDeleteEnabled = false
		textViewMapping.isGrammarCheckingEnabled = false
		
		updateEnabledStates()
		updateTextUIValues()
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	override var representedObject: Any? {
		didSet {
			guard !internalRepresentedObjectChange else {return}
			
			dirty = false
			if isViewLoaded {
				updateEnabledStates()
				updateTextUIValues()
			}
		}
	}
	
	var handlerNotifyLineValueModification: (() -> Void)?
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	override func discardEditing() {
		super.discardEditing()
		
		view.window?.makeFirstResponder(nil)
		
		dirty = false
		updateTextUIValues()
	}
	
	@IBAction func cancelEdition(_ sender: AnyObject) {
		discardEditing()
	}
	
	@IBAction func validateAndApplyMapping(_ sender: AnyObject) {
		do {
			let errorDomain = "Mapping Conversion"
			
			view.window?.makeFirstResponder(nil)
			
			/* Creating the actual mapping entry */
			guard
				let mapping = happnCSVLocKeyMapping(stringRepresentation: textViewMapping.string?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""),
				mapping.isValid else
			{
				throw NSError(domain: errorDomain, code: 1, userInfo: nil)
			}
			representedMapping = .mapping(mapping)
			handlerNotifyLineValueModification?()
		} catch {
			guard let window = view.window else {NSBeep(); return}
			
			/* If JSONSerialization sent useful error messages... */
//			let alert = NSAlert(error: error)
//			alert.beginSheetModal(for: window, completionHandler: nil)
			
			let alert = NSAlert()
			alert.messageText = "Invalid Transforms"
			alert.informativeText = "Cannot parse given mapping. Please check your JSON and mapping syntax."
			alert.addButton(withTitle: "OK")
			alert.beginSheetModal(for: window, completionHandler: nil)
		}
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
	
	private var internalRepresentedObjectChange = false
	private var representedMapping: happnCSVLocFile.LineValue? {
		get {return representedObject as? happnCSVLocFile.LineValue}
		set {representedObject = newValue}
	}
	
	private func updateEnabledStates() {
		if representedMapping == nil {
			Utils.setTextView(textViewMapping, enabled: false)
			buttonValidateMapping.isEnabled = false
			buttonCancelEdition.isEnabled = false
		} else {
			Utils.setTextView(textViewMapping, enabled: true)
			buttonValidateMapping.isEnabled = dirty
			buttonCancelEdition.isEnabled = dirty
		}
	}
	
	private func updateTextUIValues() {
		switch representedMapping {
		case nil, .entries?:
			textViewMapping.string = ""
			
		case .mapping(let mapping)?:
			textViewMapping.string = mapping.stringRepresentation()
		}
	}
	
}

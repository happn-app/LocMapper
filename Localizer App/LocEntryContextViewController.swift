/*
 * LocEntryContextViewController.swift
 * Localizer App
 *
 * Created by François Lamboley on 7/31/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa

import Localizer



class LocEntryContextViewController: NSViewController {
	
	@IBOutlet var labelGeneralInfo: NSTextField!
	@IBOutlet var textViewContext: NSTextView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		updateLabelGeneralInfoForEmptySelection()
		textViewContext.string = ""
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	override var representedObject: Any? {
		didSet {
			if let representedObject = representedObject as? LocEntryViewController.LocEntry {
				updateLabelGeneralInfoWith(env: representedObject.lineKey.env, file: representedObject.lineKey.filename, key: representedObject.lineKey.locKey)
				textViewContext.string = representedObject.lineKey.userReadableComment
			} else {
				updateLabelGeneralInfoForEmptySelection()
				textViewContext.string = ""
			}
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func updateLabelGeneralInfoWith(env: String, file: String, key: String) {
		labelGeneralInfo.stringValue = Utils.lineKeyToStr(LocFile.LineKey(locKey: key, env: env, filename: file, index: 0, comment: "", userInfo: [:], userReadableGroupComment: "", userReadableComment: ""))
	}
	
	private func updateLabelGeneralInfoForEmptySelection() {
		labelGeneralInfo.stringValue = "--"
	}
	
}

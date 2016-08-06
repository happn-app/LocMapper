/*
 * LocEntryContextViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 7/31/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa



class LocEntryContextViewController: NSViewController {
	
	@IBOutlet var labelGeneralInfo: NSTextField!
	@IBOutlet var textViewContext: NSTextView!
	
	override var representedObject: AnyObject? {
		didSet {
			if let representedObject = representedObject as? LocEntryViewController.LocEntry {
				updateLabelGeneralInfoWith(env: representedObject.lineKey.env, file: representedObject.lineKey.filename, key: representedObject.lineKey.locKey)
				textViewContext.string = representedObject.lineKey.userReadableComment
			} else {
				updateLabelGeneralInfoWith(env: "--", file: "--", key: "--")
				textViewContext.string = ""
			}
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		originalGeneralInfoText = labelGeneralInfo.stringValue
		rangeKey = findRangeInString(originalGeneralInfoText, withRegularExpression: "\\*.*\\*")
		rangeFile = findRangeInString(originalGeneralInfoText, withRegularExpression: "\\$.*\\$")
		rangeEnv = findRangeInString(originalGeneralInfoText, withRegularExpression: "\\|.*\\|")
		
		updateLabelGeneralInfoWith(env: "--", file: "--", key: "--")
		textViewContext.string = ""
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var originalGeneralInfoText: String!
	private var rangeKey: Range<String.Index>!
	private var rangeFile: Range<String.Index>!
	private var rangeEnv: Range<String.Index>!
	
	private func findRangeInString(_ string: String, withRegularExpression exprStr: String) -> Range<String.Index> {
		let expr = try! NSRegularExpression(pattern: exprStr, options: [])
		let range = expr.rangeOfFirstMatch(in: string, options: [], range: NSRange(location: 0, length: string.characters.count))
		return Range(uncheckedBounds: (
			lower: string.index(string.startIndex, offsetBy: range.location),
			upper: string.index(string.startIndex, offsetBy: range.location + range.length)
		))
	}
	
	private func updateLabelGeneralInfoWith(env: String, file: String, key: String) {
		/* We assume in originalGeneralInfoText, the dynamic parts of the string
		 * appear in the following order: env, file and key. */
		guard var infoText = originalGeneralInfoText else {return}
		infoText.replaceSubrange(rangeKey, with: key)
		infoText.replaceSubrange(rangeFile, with: file)
		infoText.replaceSubrange(rangeEnv, with: env)
		labelGeneralInfo.stringValue = infoText
	}
	
}

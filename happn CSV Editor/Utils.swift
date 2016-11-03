/*
 * Utils.swift
 * Localizer
 *
 * Created by François Lamboley on 11/3/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation



class Utils {
	
	static let lineKeyStrTemplate = NSLocalizedString("key description", comment: "Template for converting a LineKey object to a string.")
	static let rangeKey: Range<String.Index>  = Utils.findRangeInString(Utils.lineKeyStrTemplate, withRegularExpression: "\\*.*\\*")
	static let rangeFile: Range<String.Index> = Utils.findRangeInString(Utils.lineKeyStrTemplate, withRegularExpression: "\\$.*\\$")
	static let rangeEnv: Range<String.Index>  = Utils.findRangeInString(Utils.lineKeyStrTemplate, withRegularExpression: "\\|.*\\|")
	
	static func lineKeyToStr(_ lineKey: happnCSVLocFile.LineKey) -> String {
		/* We assume in originalGeneralInfoText, the dynamic parts of the string
		 * appear in the following order: env, key and file. */
		var infoText = Utils.lineKeyStrTemplate
		infoText.replaceSubrange(rangeFile, with: lineKey.filename)
		infoText.replaceSubrange(rangeKey, with: lineKey.locKey)
		infoText.replaceSubrange(rangeEnv, with: lineKey.env)
		return infoText
	}
	
	static func findRangeInString(_ string: String, withRegularExpression exprStr: String) -> Range<String.Index> {
		let expr = try! NSRegularExpression(pattern: exprStr, options: [])
		let range = expr.rangeOfFirstMatch(in: string, options: [], range: NSRange(location: 0, length: string.characters.count))
		return Range(uncheckedBounds: (
			lower: string.index(string.startIndex, offsetBy: range.location),
			upper: string.index(string.startIndex, offsetBy: range.location + range.length)
		))
	}
	
}

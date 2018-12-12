/*
 * Utils.swift
 * LocMapper App
 *
 * Created by François Lamboley on 11/3/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa

import LocMapper
import XibLoc



class Utils {
	
	static let lineKeyStrTemplate = NSLocalizedString("key description", comment: "Template for converting a LineKey object to a string.")
	
	static func lineKeyToStr(_ lineKey: LocFile.LineKey) -> String {
		return lineKeyStrTemplate.applying(
			xibLocInfo: Str2StrXibLocInfo(replacements: ["|": lineKey.env, "*": lineKey.locKey, "$": lineKey.filename])
		)
	}
	
	static func setTextView(_ textView: NSTextView, enabled: Bool) {
		/* Straight from https://developer.apple.com/library/content/qa/qa1461/_index.html */
		textView.isSelectable = enabled
		textView.isEditable = enabled
		textView.textColor = (enabled ? .controlTextColor : .disabledControlTextColor)
	}
	
}

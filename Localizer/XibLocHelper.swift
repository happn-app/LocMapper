/*
 * XibLocHelper.swift
 * Localizer
 *
 * Created by François Lamboley on 12/7/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation


/* ***** TODO!!! ***** */


protocol ParsableXibStr {
	var _xibstr_length: Int {get}
	func _xibstr_hasPrefix(_ prefix: String) -> Bool
	
	func _xibstr_mutable() -> MutableParsableXibStr
}

protocol MutableParsableXibStr {
}

extension String: ParsableXibStr, MutableParsableXibStr {
	func _xibstr_hasPrefix(_ prefix: String) -> Bool {
		return self.hasPrefix(prefix)
	}
	
	var _xibstr_length: Int {
		return self.characters.count
	}
	
	func _xibstr_mutable() -> MutableParsableXibStr {
		return self
	}
}

extension NSAttributedString: ParsableXibStr {
	func _xibstr_hasPrefix(_ prefix: String) -> Bool {
		return self.string.hasPrefix(prefix)
	}
	
	var _xibstr_length: Int {
		return self.length
	}
	
	func _xibstr_mutable() -> MutableParsableXibStr {
		return self.mutableCopy() as! NSMutableAttributedString
	}
}

extension NSMutableAttributedString: MutableParsableXibStr {
}

protocol StringOrAttributedString {
}

extension String: StringOrAttributedString {
}

extension NSAttributedString: StringOrAttributedString {
}

class XibLocHelper {
	
	func stringByParsingXibComplexLocString(
		baseString: String, escapeToken escape: String,
		simpleReplacementSeparators srs: NSOrderedSet, values srsValues: [String],
		orderedReplacementSeparators ores: NSOrderedSet, interiorSeparators oris: NSOrderedSet, values orsValues: [Int],
		pluralGroupExteriorSeparators pges: NSOrderedSet, interiorSeparators pgis: NSOrderedSet, defaultPluralityDefinition dpd: String, values pgsValues: [Int])
		-> String
	{
		return baseString
	}
	
	func stringByParsingXibComplexLocString(
		baseString: NSAttributedString, escapeToken escape: String,
		simpleReplacementSeparators srs: NSOrderedSet, values srsValues: [StringOrAttributedString],
		orderedReplacementSeparators ores: NSOrderedSet, interiorSeparators oris: NSOrderedSet, values orsValues: [Int],
		pluralGroupExteriorSeparators pges: NSOrderedSet, interiorSeparators pgis: NSOrderedSet, defaultPluralityDefinition dpd: String, values pgsValues: [Int])
		-> NSAttributedString
	{
		return baseString
	}
	
}

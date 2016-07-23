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

extension AttributedString: ParsableXibStr {
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

extension AttributedString: StringOrAttributedString {
}

class XibLocHelper {
	
	func stringByParsingXibComplexLocString(
		baseString: String, escapeToken escape: String,
		simpleReplacementSeparators srs: OrderedSet, values srsValues: [String],
		orderedReplacementSeparators ores: OrderedSet, interiorSeparators oris: OrderedSet, values orsValues: [Int],
		pluralGroupExteriorSeparators pges: OrderedSet, interiorSeparators pgis: OrderedSet, defaultPluralityDefinition dpd: String, values pgsValues: [Int])
		-> String
	{
		return baseString
	}
	
	func stringByParsingXibComplexLocString(
		baseString: AttributedString, escapeToken escape: String,
		simpleReplacementSeparators srs: OrderedSet, values srsValues: [StringOrAttributedString],
		orderedReplacementSeparators ores: OrderedSet, interiorSeparators oris: OrderedSet, values orsValues: [Int],
		pluralGroupExteriorSeparators pges: OrderedSet, interiorSeparators pgis: OrderedSet, defaultPluralityDefinition dpd: String, values pgsValues: [Int])
		-> AttributedString
	{
		return baseString
	}
	
}

/*
 * Std2Xib.swift
 * LocMapper
 *
 * Created by François Lamboley on 03/04/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log



enum Std2XibError : Error {
	
	case invalidTag
	case unknownLanguage
	
}


struct Std2Xib {
	
	static func untaggedValue(from stdLocValues: [TaggedString], with language: String) throws -> String {
		let language = language.lowercased()
		
		/* Tags of first value determine how we'll merge the values. We do not try
		 * and fix invalid values with a different # of/unrelated tags. We'll only
		 * print a message in the logs if there are missing tags compared to first
		 * value. */
		guard let firstValue = stdLocValues.first else {return ""}
		guard firstValue.tags.count > 0 else {return firstValue.value}
		
		/* First let's get the transforms and sort them from the first value. */
		var plurals = [LocValueTransformerPluralVariantPick]()
		var genders = [LocValueTransformerGenderVariantPick]()
		var replacements = [LocValueTransformerRegionDelimitersReplacement]()
		
		var i = 0
		for tag in firstValue.tags {
			let t = try transformer(from: tag, index: &i)
			switch t {
			case let plural      as LocValueTransformerPluralVariantPick:           plurals.append(plural)
			case let gender      as LocValueTransformerGenderVariantPick:           genders.append(gender)
			case let replacement as LocValueTransformerRegionDelimitersReplacement: replacements.append(replacement)
			default: fatalError("Internal Logic Error")
			}
		}
		
		/* Next we'll apply all the replacements transforms (replacement part of
		 * the plurals and replacements). */
		var standardizedStdLocValuesNoReplacements = stdLocValues.map{ taggedString in
			TaggedString(value: taggedString.value, tags: taggedString.tags.map{
				switch $0 {
				case "p##<:>0": return "p0"
				case "p##<:>1": return "p1"
				case "p##<:>2": return "p2"
				case "p##<:>f": return "pf"
				case "p##<:>m": return "pm"
				case "p##<:>x": return "px"
				case "g`¦´m": return "gm"
				case "g`¦´f": return "gf"
				default: return $0
				}
			})
		}
		for replacement in replacements {
			standardizedStdLocValuesNoReplacements = applyReverseReplacement(
				in: standardizedStdLocValuesNoReplacements,
				replacedFormatPrefix: replacement.replacement,
				openDelim: replacement.openDelim, closeDelim: replacement.closeDelim
			)
		}
		for plural in plurals {
			standardizedStdLocValuesNoReplacements = applyReverseReplacement(
				in: standardizedStdLocValuesNoReplacements,
				replacedFormatPrefix: plural.numberReplacement,
				openDelim: plural.numberOpenDelim, closeDelim: plural.numberCloseDelim
			)
		}
		
		/* Finally, let's merge the strings in one. */
		return try applyReverseNonReplacements(from: standardizedStdLocValuesNoReplacements, with: language, plurals: plurals, genders: genders)
	}
	
	/* The returned transformer, when there is a replacement, will contain the
	 * **prefix** of the replacement only. */
	private static func transformer(from tag: String, index i: inout Int) throws -> LocValueTransformer {
		switch tag.first {
		case "p"?:
			i += 1
			guard let pluralUnicodeValue = tag.last.flatMap({ LocValueTransformerPluralVariantPick.UnicodePluralValue(string: String($0)) }) else {
				throw Std2XibError.invalidTag
			}
			switch tag.count {
			case 2: return LocValueTransformerPluralVariantPick(numberReplacement: "%\(i)$", numberOpenDelim: "#",                                                 numberCloseDelim: "#",                                                 pluralUnicodeValue: pluralUnicodeValue, pluralOpenDelim: "<",                                                 pluralMiddleDelim: ":",                                                 pluralCloseDelim: ">")
			case 7: return LocValueTransformerPluralVariantPick(numberReplacement: "%\(i)$", numberOpenDelim: String(tag[tag.index(tag.startIndex, offsetBy: 1)]), numberCloseDelim: String(tag[tag.index(tag.startIndex, offsetBy: 2)]), pluralUnicodeValue: pluralUnicodeValue, pluralOpenDelim: String(tag[tag.index(tag.startIndex, offsetBy: 3)]), pluralMiddleDelim: String(tag[tag.index(tag.startIndex, offsetBy: 4)]), pluralCloseDelim: String(tag[tag.index(tag.startIndex, offsetBy: 5)]))
			default: throw Std2XibError.invalidTag
			}
			
		case "g"?:
			guard let gender = tag.last.flatMap({ LocValueTransformerGenderVariantPick.Gender(string: String($0)) }) else {
				throw Std2XibError.invalidTag
			}
			switch tag.count {
			case 2: return LocValueTransformerGenderVariantPick(gender: gender, openDelim: "`",                                                 middleDelim: "¦",                                                 closeDelim: "´")
			case 5: return LocValueTransformerGenderVariantPick(gender: gender, openDelim: String(tag[tag.index(tag.startIndex, offsetBy: 1)]), middleDelim: String(tag[tag.index(tag.startIndex, offsetBy: 2)]), closeDelim: String(tag[tag.index(tag.startIndex, offsetBy: 3)]))
			default: throw Std2XibError.invalidTag
			}
			
		case "r"?:
			i += 1
			switch tag.count {
			case 1: return LocValueTransformerRegionDelimitersReplacement(replacement: "%\(i)$", openDelim: "|",                                                 closeDelim: "|")
			case 3: return LocValueTransformerRegionDelimitersReplacement(replacement: "%\(i)$", openDelim: String(tag[tag.index(tag.startIndex, offsetBy: 1)]), closeDelim: String(tag[tag.index(tag.startIndex, offsetBy: 2)]))
			default: throw Std2XibError.invalidTag
			}
			
		default:
			throw Std2XibError.invalidTag
		}
	}
	
	private static func applyReverseReplacement(in taggedStrings: [TaggedString], replacedFormatPrefix: String, openDelim: String, closeDelim: String) -> [TaggedString] {
		let allFormats = [
			"d": "n",
			"i": "n (i)",
			"o": "octal number var (o)",
			"u": "unsigned decimal var (u)",
			"X": "hexadecimal number var (X)",
			"x": "hexadecimal number var (x)",
			"f": "float var (f)",
			"F": "float var (F)",
			"e": "float var (e)",
			"E": "float var (E)",
			"g": "float var (g)",
			"G": "float var (G)",
			"a": "float var (a)",
			"A": "float var (A)",
			"c": "byte var",
			"s": "string var",
			"b": "string var (b)"
		]
		let toReplace = allFormats.map{ (replacedFormatPrefix.appending($0.key), $0.value) }
		return taggedStrings.map{ v in
			var str = v.value
			for (r, v) in toReplace {str = str.replacingOccurrences(of: r, with: openDelim + v + closeDelim)}
			return TaggedString(value: str, tags: v.tags)
		}
	}
	
	private static func applyReverseNonReplacements(from taggedStrings: [TaggedString], with language: String, plurals: [LocValueTransformerPluralVariantPick], genders: [LocValueTransformerGenderVariantPick]) throws -> String {
		assert(taggedStrings.count > 0)
		
		let openDelim: String
		let middleDelim: String
		let closeDelim: String
		let newPlurals: [LocValueTransformerPluralVariantPick]
		let newGenders: [LocValueTransformerGenderVariantPick]
		
		let tagsToMatch: [String]
		
		if let plural = plurals.first {
			openDelim = plural.pluralOpenDelim
			middleDelim = plural.pluralMiddleDelim
			closeDelim = plural.pluralCloseDelim
			
			newPlurals = Array(plurals.dropFirst())
			newGenders = genders
			
			/* The list of language is in LocValueTransformerPluralVariantPick */
			let pluralValues: [LocValueTransformerPluralVariantPick.UnicodePluralValue]
			if Set(["thai", "chinese", "japanese"]).contains(where: { language.range(of: $0) != nil }) {
				pluralValues = [.other]
			} else if Set(["english", "german", "spanish", "italian", "hungarian", "turkish", "greek", "french", "portuguese"]).contains(where: { language.range(of: $0) != nil }) {
				pluralValues = [.one, .other]
			} else if Set(["polish", "russian"]).contains(where: { language.range(of: $0) != nil }) {
				pluralValues = [.one, .few, .other]
			} else {
				throw Std2XibError.unknownLanguage
			}
			
			tagsToMatch = HappnXib2Std.tags(from: pluralValues.map{
				LocValueTransformerPluralVariantPick(numberReplacement: plural.numberReplacement, numberOpenDelim: plural.numberOpenDelim, numberCloseDelim: plural.numberCloseDelim, pluralUnicodeValue: $0, pluralOpenDelim: openDelim, pluralMiddleDelim: middleDelim, pluralCloseDelim: closeDelim)
			})
		} else if let gender = genders.first {
			openDelim = gender.openDelim
			middleDelim = gender.middleDelim
			closeDelim = gender.closeDelim
			
			newPlurals = plurals
			newGenders = Array(genders.dropFirst())
			
			tagsToMatch = HappnXib2Std.tags(from: [
				LocValueTransformerGenderVariantPick(gender: .male,   openDelim: openDelim, middleDelim: middleDelim, closeDelim: closeDelim),
				LocValueTransformerGenderVariantPick(gender: .female, openDelim: openDelim, middleDelim: middleDelim, closeDelim: closeDelim)
			])
		} else {
			if taggedStrings.count != 1 {
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got more than one tagged string but no plural or gender tags...", log: $0, type: .info) }}
				else                        {NSLog("Got more than one tagged string but no plural or gender tags...")}
			}
			return taggedStrings.first!.value
		}
		
		var values = [String]()
		for t in tagsToMatch {
			let matchingTaggedStrings = taggedStrings.filter{ $0.tags.contains(t) }
			values.append(try applyReverseNonReplacements(from: matchingTaggedStrings, with: language, plurals: newPlurals, genders: newGenders))
		}
		
		/* Before implementing http://www.xmailserver.org/diff2.pdf, let's do a
		 * stupid hack: if all the values are the same, we can simply return this
		 * value! */
		let refVal = values.first! /* Must contain at least one value since tagsToMatch always contains at least one value */
		guard values.contains(where: { $0 != refVal }) else {
			return refVal
		}
		
		var first = true
		var ret = openDelim
		for v in values {
			if !first {ret += middleDelim}
			ret += v
			first = false
		}
		ret += closeDelim
		return ret
	}
	
	private init() {/* The struct is only a containter for utility methods */}
	
}

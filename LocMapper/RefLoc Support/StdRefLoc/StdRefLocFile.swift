/*
 * StdRefLocFile.swift
 * LocMapper
 *
 * Created by François Lamboley on 7/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation
import os.log

import XibLoc



public class StdRefLocFile {
	
	struct TaggedString : Hashable, CustomDebugStringConvertible {
		
		let value: String
		let tags: [String]
		
		init(string: String) {
			let (v, t) = string.splitAppendedTags()
			self.init(value: v, tags: t ?? [])
		}
		
		init(value v: String, tags t: [String]) {
			value = v
			tags = t
			
			hashValue = value.hashValue &+ tags.reduce(0, { $0 &+ $1.hashValue })
		}
		
		let hashValue: Int
		
		static func ==(lhs: StdRefLocFile.TaggedString, rhs: StdRefLocFile.TaggedString) -> Bool {
			return lhs.value == rhs.value && lhs.tags == rhs.tags
		}
		
		var debugDescription: String {
			return "\"" + value + "\"<" + tags.joined(separator: ",") + ">"
		}
		
	}
	
	typealias Key = String
	typealias Value = [TaggedString]
	public typealias Language = String
	
	private(set) var languages: [Language]
	private(set) var entries: [Key: [Language: Value]]
	
	public convenience init(fromURL url: URL, languages: [Language], csvSeparator: String = ",") throws {
		var encoding = String.Encoding.utf8
		let filecontent = try String(contentsOf: url, usedEncoding: &encoding)
		try self.init(filecontent: filecontent, languages: languages, csvSeparator: csvSeparator)
	}
	
	init(filecontent: String, languages sourceLanguages: [Language], csvSeparator: String = ",") throws {
		let error = NSError(domain: "XibRefLocFile", code: 1, userInfo: nil)
		let parser = CSVParser(source: filecontent, startOffset: 0, separator: csvSeparator, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw error
		}
		
		var entriesBuilding = [Key: [Language: Value]]()
		for row in parsedRows {
			guard let keyStr = row["KEY"], !keyStr.isEmpty else {continue}
			let taggedKey = TaggedString(string: keyStr)
			if entriesBuilding[taggedKey.value] != nil {
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Found duplicated key %@ when parsing reference translation loc file. The latest one wins.", log: $0, type: .info, String(describing: keyStr)) }}
				else                        {NSLog("Found duplicated key %@ when parsing reference translation loc file. The latest one wins.", String(describing: keyStr))}
			}
			
			var values = [Language: Value]()
			for language in sourceLanguages {values[language, default: []].append(TaggedString(value: row[language] ?? "", tags: taggedKey.tags))}
			entriesBuilding[taggedKey.value] = values
		}
		languages = sourceLanguages
		entries = entriesBuilding
	}
	
	public init(xibRefLoc: XibRefLocFile) {
		languages = xibRefLoc.languages
		
		var entriesBuilding = [Key: [Language: Value]]()
		for (xibLocKey, xibLocValues) in xibRefLoc.entries {
			/* Let's detect || string replacements */
			let stdReplacementDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithToken: "|", value: "")
			let hasStdReplacement = xibLocValues.contains{
				let (_, v) = $0
				return v.applying(xibLocInfo: stdReplacementDetectionInfo) != v
			}
			/* Let's detect `¦´ gender */
			let stdGenderDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithLeftToken: "`", rightToken: "´", value: "")
			let hasStdGender = xibLocValues.contains{
				let (_, v) = $0
				return v.applying(xibLocInfo: stdGenderDetectionInfo) != v
			}
			/* Let's detect #<:> plural */
			let stdPluralDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithLeftToken: "<", rightToken: ">", value: "")
			let hasStdPlural = xibLocValues.contains{
				let (_, v) = $0
				return v.applying(xibLocInfo: stdPluralDetectionInfo) != v
			}
			
			var i = 0
			var transformersList = [[LocValueTransformer]](arrayLiteral: [])
			if hasStdPlural {
				i += 1
				transformersList = [
					LocValueTransformerPluralVariantPick(numberReplacement: "%\(i)$d", numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .zero,  pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
					LocValueTransformerPluralVariantPick(numberReplacement: "%\(i)$d", numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .one,   pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
					LocValueTransformerPluralVariantPick(numberReplacement: "%\(i)$d", numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .two,   pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
					LocValueTransformerPluralVariantPick(numberReplacement: "%\(i)$d", numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .few,   pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
					LocValueTransformerPluralVariantPick(numberReplacement: "%\(i)$d", numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .many,  pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
					LocValueTransformerPluralVariantPick(numberReplacement: "%\(i)$d", numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .other, pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">")
				].flatMap{ nt in transformersList.map{ ts in ts + [nt] } }
			}
			if hasStdGender {
				transformersList = [
					LocValueTransformerGenderVariantPick(gender: .male,   openDelim: "`", middleDelim: "¦", closeDelim: "´"),
					LocValueTransformerGenderVariantPick(gender: .female, openDelim: "`", middleDelim: "¦", closeDelim: "´")
				].flatMap{ nt in transformersList.map{ ts in ts + [nt] } }
			}
			if hasStdReplacement {
				i += 1
				transformersList = [
					LocValueTransformerRegionDelimitersReplacement(replacement: "%\(i)$s", openDelim: "|", closeDelim: "|")
				].flatMap{ nt in transformersList.map{ ts in ts + [nt] } }
			}
			var values = [Language: Value]()
			for transformers in transformersList {
				for (l, v) in xibLocValues {
					let newValue = (try? transformers.reduce(v, { try $1.apply(toValue: $0, withLanguage: l) })) ?? LocFile.internalLocMapperErrorToken
					values[l, default: []].append(TaggedString(value: newValue, tags: StdRefLocFile.tags(from: transformers)))
				}
			}
			entriesBuilding[xibLocKey] = values
		}
		print(entriesBuilding)
		entries = entriesBuilding
	}
	
	private class func tags(from transformers: [LocValueTransformer]) -> [String] {
		var res = [String]()
		for t in transformers {
			switch t {
			case let plural as LocValueTransformerPluralVariantPick:
				assert(![plural.numberOpenDelim, plural.numberCloseDelim, plural.pluralOpenDelim, plural.pluralMiddleDelim, plural.pluralCloseDelim].contains{ $0.count != 1 }, "Unsupported plural transformer: contains a delimiter whose count is not 1: \(t)")
				var tag = "p"
				let delimiters = plural.numberOpenDelim + plural.numberCloseDelim + plural.pluralOpenDelim + plural.pluralMiddleDelim + plural.pluralCloseDelim
				if delimiters != "##<:>" {tag += delimiters}
				switch plural.pluralUnicodeValue {
				case .zero:  tag += "0"
				case .one:   tag += "1"
				case .two:   tag += "2"
				case .few:   tag += "f"
				case .many:  tag += "m"
				case .other: tag += "x"
				}
				res.append(tag)
				
			case let gender as LocValueTransformerGenderVariantPick:
				assert(![gender.openDelim, gender.middleDelim, gender.closeDelim].contains{ $0.count != 1 }, "Unsupported gender transformer: contains a delimiter whose count is not 1: \(t)")
				var tag = "g"
				let delimiters = gender.openDelim + gender.middleDelim + gender.closeDelim
				if delimiters != "`¦´" {tag += delimiters}
				switch gender.gender {
				case .male:   tag += "m"
				case .female: tag += "f"
				}
				res.append(tag)
				
			case let replacement as LocValueTransformerRegionDelimitersReplacement:
				assert(![replacement.openDelim, replacement.closeDelim].contains{ $0.count != 1 }, "Unsupported replacement transformer: contains a delimiter whose count is not 1: \(t)")
				var tag = "r"
				let delimiters = replacement.openDelim + replacement.closeDelim
				if delimiters != "||" {tag += delimiters}
				res.append(tag)
				
			default:
				fatalError("Unsupported transformer \(t)")
			}
		}
		return res
	}
	
}

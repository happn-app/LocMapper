/*
 * Xib2Std.swift
 * LocMapper
 *
 * Created by François Lamboley on 03/04/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation

import XibLoc



struct Xib2Std {
	
	static func taggedValues(from xibLocValues: [XibRefLocFile.Language: XibRefLocFile.Value]) -> [StdRefLocFile.Language: StdRefLocFile.Value] {
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
		/* Let's detect {⟷} gender */
		let braceGenderDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithLeftToken: "{", rightToken: "}", value: "")
		let hasBraceGender = xibLocValues.contains{
			let (_, v) = $0
			return v.applying(xibLocInfo: braceGenderDetectionInfo) != v
		}
		/* Let's detect ##<:> plural */
		let stdPluralDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithLeftToken: "<", rightToken: ">", value: "")
		let hasStdPlural = xibLocValues.contains{
			let (_, v) = $0
			return v.applying(xibLocInfo: stdPluralDetectionInfo) != v
		}
		/* Let's detect ## string replacements */
		let sharpReplacementDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithLeftToken: "#", rightToken: "#", value: "")
		let hasSharpReplacement = !hasStdPlural && xibLocValues.contains{
			let (_, v) = $0
			return v.applying(xibLocInfo: sharpReplacementDetectionInfo) != v
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
		if hasBraceGender {
			transformersList = [
				LocValueTransformerGenderVariantPick(gender: .male,   openDelim: "{", middleDelim: "⟷", closeDelim: "}"),
				LocValueTransformerGenderVariantPick(gender: .female, openDelim: "{", middleDelim: "⟷", closeDelim: "}")
			].flatMap{ nt in transformersList.map{ ts in ts + [nt] } }
		}
		if hasStdReplacement {
			i += 1
			transformersList = [
				LocValueTransformerRegionDelimitersReplacement(replacement: "%\(i)$s", openDelim: "|", closeDelim: "|")
			].flatMap{ nt in transformersList.map{ ts in ts + [nt] } }
		}
		if hasSharpReplacement {
			i += 1
			transformersList = [
				LocValueTransformerRegionDelimitersReplacement(replacement: "%\(i)$d", openDelim: "#", closeDelim: "#")
			].flatMap{ nt in transformersList.map{ ts in ts + [nt] } }
		}
		var values = [StdRefLocFile.Language: StdRefLocFile.Value]()
		for transformers in transformersList {
			for (l, v) in xibLocValues {
				let unpercentedValue = v
					.replacingOccurrences(of: "%", with: "%%").replacingOccurrences(of: "%%@", with: "%s")
					.replacingOccurrences(of: "%%d", with: "%d").replacingOccurrences(of: "%%0.*f", with: "%0.*f")
					.replacingOccurrences(of: "%%1$s", with: "%1$s").replacingOccurrences(of: "%%2$s", with: "%2$s")
				let newValue = (try? transformers.reduce(unpercentedValue, { try $1.apply(toValue: $0, withLanguage: l) })) ?? LocFile.internalLocMapperErrorToken
				values[l, default: []].append(TaggedString(value: newValue, tags: Xib2Std.tags(from: transformers)))
			}
		}
		return values
	}
	
	static func tags(from transformers: [LocValueTransformer]) -> [String] {
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
	
	private init() {/* The struct is only a containter for utility methods */}
	
}

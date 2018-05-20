/*
 * HappnXib2Std.swift
 * LocMapper
 *
 * Created by François Lamboley on 03/04/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log

import XibLoc



/** **NOT** foolproof. Well actually, there are many cases that are not working.
See HappnXib2Lokalise. */
struct HappnXib2Std {
	
	/* Guarantees on return value:
	 *    - Each array will contains at least one element;
	 *    - Each elements inside an array will be kind of the same subclass of
	 *      LocValueTransformer. */
	static func computeTransformersGroups(from xibLocValues: [XibRefLocFile.Language: XibRefLocFile.Value], useLokalisePlaceholderFormat: Bool = false) -> [[LocValueTransformer]] {
		/* Let's detect $$ string replacements (checked to only happen with "$n$") */
		let hasDollarReplacement = xibLocValues.contains{
			let (_, v) = $0
			return v.range(of: "$n$") != nil
		}
		/* Let's detect %% string replacements (checked to only happen for build info) */
		let hasPercentReplacement = xibLocValues.contains{
			let (_, v) = $0
			return v.range(of: "%%build") != nil
		}
		/* Let's detect || string replacements */
		let stdReplacementDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithToken: "|", value: "")
		let hasStdReplacement = xibLocValues.contains{
			let (_, v) = $0
			return v.applying(xibLocInfo: stdReplacementDetectionInfo) != v
		}
		/* Let's detect ^^ string replacements (checked to only happen for specific cases we check here...) */
		let hasHatReplacement = xibLocValues.contains{
			let (_, v) = $0
			return v.range(of: "^workplace^") != nil || v.range(of: "^marketing version^") != nil
		}
		/* Let's detect 👓👓 string replacements */
		let eyesReplacementDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithToken: "👓", value: "")
		let hasEyesReplacement = xibLocValues.contains{
			let (_, v) = $0
			return v.applying(xibLocInfo: eyesReplacementDetectionInfo) != v
		}
		/* Let's detect `¦´ gender */
		let stdGenderDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithLeftToken: "`", rightToken: "´", value: "", escapeToken: "~")
		let hasStdGender = xibLocValues.contains{
			let (_, v) = $0
			return v.applying(xibLocInfo: stdGenderDetectionInfo) != v
		}
		/* Let's detect {₋} gender */
		let braceGenderDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithLeftToken: "{", rightToken: "}", value: "", escapeToken: "~")
		let hasBraceGender = xibLocValues.contains{
			let (_, v) = $0
			return v.range(of: "{LINK}") == nil && v.applying(xibLocInfo: braceGenderDetectionInfo) != v
		}
		/* Let's detect ##<:> plural */
		let stdPluralDetectionInfo = Str2StrXibLocInfo(simpleReplacementWithLeftToken: "<", rightToken: ">", value: "", escapeToken: "~")
		let hasStdPlural = xibLocValues.contains{
			let (_, v) = $0
			return v.applying(xibLocInfo: stdPluralDetectionInfo) != v
		}
		/* Let's detect ## string replacements */
		let sharpReplacementDetectionInfo = Str2StrXibLocInfo(replacements: ["#": ""])
		let hasSharpReplacement = !hasStdPlural && xibLocValues.contains{
			let (_, v) = $0
			return v.applying(xibLocInfo: sharpReplacementDetectionInfo) != v
		}
		
		var i = 0
		var results = [[LocValueTransformer]]()
		if hasStdPlural {
			i += 1
			let numberReplacement = simpleReplacementForStdConversion(from: xibLocValues, idx: i, formatSpecifier: "d", tokens: useLokalisePlaceholderFormat ? ("#", "#") : nil)
			results.append([
				LocValueTransformerPluralVariantPick(numberReplacement: numberReplacement, numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .zero,  pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
				LocValueTransformerPluralVariantPick(numberReplacement: numberReplacement, numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .one,   pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
				LocValueTransformerPluralVariantPick(numberReplacement: numberReplacement, numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .two,   pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
				LocValueTransformerPluralVariantPick(numberReplacement: numberReplacement, numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .few,   pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
				LocValueTransformerPluralVariantPick(numberReplacement: numberReplacement, numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .many,  pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">"),
				LocValueTransformerPluralVariantPick(numberReplacement: numberReplacement, numberOpenDelim: "#", numberCloseDelim: "#", pluralUnicodeValue: .other, pluralOpenDelim: "<", pluralMiddleDelim: ":", pluralCloseDelim: ">")
			])
		}
		if hasStdGender {
			results.append([
				LocValueTransformerGenderVariantPick(gender: .male,   openDelim: "`", middleDelim: "¦", closeDelim: "´"),
				LocValueTransformerGenderVariantPick(gender: .female, openDelim: "`", middleDelim: "¦", closeDelim: "´")
			])
		}
		if hasBraceGender {
			results.append([
				LocValueTransformerGenderVariantPick(gender: .male,   openDelim: "{", middleDelim: "₋", closeDelim: "}"),
				LocValueTransformerGenderVariantPick(gender: .female, openDelim: "{", middleDelim: "₋", closeDelim: "}")
			])
		}
		if hasDollarReplacement {
			i += 1
			let replacement = simpleReplacementForStdConversion(from: xibLocValues, idx: i, formatSpecifier: "s", tokens: useLokalisePlaceholderFormat ? ("$", "$") : nil)
			results.append([
				LocValueTransformerRegionDelimitersReplacement(replacement: replacement, openDelim: "$", closeDelim: "$")
			])
		}
		if hasPercentReplacement {
			i += 1
			let replacement = simpleReplacementForStdConversion(from: xibLocValues, idx: i, formatSpecifier: "s", tokens: useLokalisePlaceholderFormat ? ("%%", "%%") : nil)
			results.append([
				LocValueTransformerRegionDelimitersReplacement(replacement: replacement, openDelim: "%%", closeDelim: "%%")
			])
		}
		if hasStdReplacement {
			i += 1
			let replacement = simpleReplacementForStdConversion(from: xibLocValues, idx: i, formatSpecifier: "s", tokens: useLokalisePlaceholderFormat ? ("|", "|") : nil)
			results.append([
				LocValueTransformerRegionDelimitersReplacement(replacement: replacement, openDelim: "|", closeDelim: "|")
			])
		}
		if hasSharpReplacement {
			i += 1
			let replacement = simpleReplacementForStdConversion(from: xibLocValues, idx: i, formatSpecifier: "d", tokens: useLokalisePlaceholderFormat ? ("#", "#") : nil)
			results.append([
				LocValueTransformerRegionDelimitersReplacement(replacement: replacement, openDelim: "#", closeDelim: "#")
			])
		}
		if hasHatReplacement {
			i += 1
			let replacement = simpleReplacementForStdConversion(from: xibLocValues, idx: i, formatSpecifier: "s", tokens: useLokalisePlaceholderFormat ? ("^", "^") : nil)
			results.append([
				LocValueTransformerRegionDelimitersReplacement(replacement: replacement, openDelim: "^", closeDelim: "^")
			])
		}
		if hasEyesReplacement {
			i += 1
			let replacement = simpleReplacementForStdConversion(from: xibLocValues, idx: i, formatSpecifier: "s", tokens: useLokalisePlaceholderFormat ? ("👓", "👓") : nil)
			results.append([
				LocValueTransformerRegionDelimitersReplacement(replacement: replacement, openDelim: "👓", closeDelim: "👓")
			])
		}
		return results
	}
	
	static func convertTransformersGroupsToStdLocEntryActions(_ transformersGroups: [[LocValueTransformer]]) -> [[LocValueTransformer]] {
		var results = [[LocValueTransformer]](arrayLiteral: [])
		for transformersGroup in transformersGroups {
			results = transformersGroup.flatMap{ nt in results.map{ ts in ts + [nt] } }
		}
		return results
	}
	
	static func taggedValues(from xibLocValues: [XibRefLocFile.Language: XibRefLocFile.Value]) -> [StdRefLocFile.Language: StdRefLocFile.Value] {
		let preprocessedXibLocValues = xibLocValues.mapValues{ v -> (String, Bool) in
			let doublePercented = v.replacingOccurrences(of: "%", with: "%%")
			let unpercented = doublePercented
				.replacingOccurrences(of: "%%@", with: "%1$s").replacingOccurrences(of: "%%d", with: "%1$d")
				.replacingOccurrences(of: "%%1$s", with: "%1$s").replacingOccurrences(of: "%%2$s", with: "%2$s")
				.replacingOccurrences(of: "%%0.*f", with: "%1$0.*f")
			return (unpercented, doublePercented != unpercented)
		}
		
		let stdLocEntryActions = convertTransformersGroupsToStdLocEntryActions(computeTransformersGroups(from: preprocessedXibLocValues.mapValues{ $0.0 }))
		var values = [StdRefLocFile.Language: StdRefLocFile.Value]()
		for stdLocEntryAction in stdLocEntryActions {
			for (l, (unpercentedValue, addPrintfReplacementTag)) in preprocessedXibLocValues {
				if addPrintfReplacementTag && !stdLocEntryAction.isEmpty {
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got a printf-style replacement AND a std loc entry action (%{public}@)", log: $0, type: .info, stdLocEntryAction) }}
					else                        {NSLog("Got a printf-style replacement AND a std loc entry action (%@)", stdLocEntryAction)}
				}
				let newValue = (try? stdLocEntryAction.reduce(unpercentedValue, { try $1.apply(toValue: $0, withLanguage: l) })) ?? LocFile.internalLocMapperErrorToken
				values[l, default: []].append(TaggedString(value: newValue, tags: HappnXib2Std.tags(from: stdLocEntryAction) + (addPrintfReplacementTag ? ["printf"] : [])))
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
				
			case let order as LocValueTransformerOrderedReplacementVariantPick:
				assert(![order.openDelim, order.middleDelim, order.closeDelim].contains{ $0.count != 1 }, "Unsupported ordered replacement transformer: contains a delimiter whose count is not 1: \(t)")
				assert(order.index < 10, "Unsupported ordered replacement transformer: index is > 10 (== \(order.index))")
				res.append("o" + order.openDelim + order.middleDelim + order.closeDelim + String(order.index))
				
			case let replacement as LocValueTransformerRegionDelimitersReplacement:
				assert(![replacement.openDelim, replacement.closeDelim].contains{ $0.count != 1 && $0 != "%%" }, "Unsupported replacement transformer: contains a delimiter whose count is not 1: \(t)")
				var tag = "r"
				let delimiters = replacement.openDelim + replacement.closeDelim
				if delimiters != "||" {
					if delimiters == "%%%%" {tag += "%%"}
					else                    {tag += delimiters}
				}
				res.append(tag)
				
			default:
				fatalError("Unsupported transformer \(t)")
			}
		}
		return res
	}
	
	private init() {/* The struct is only a containter for utility methods */}
	
	private static func simpleReplacementForStdConversion(from xibLocValues: [XibRefLocFile.Language: XibRefLocFile.Value], idx: Int, formatSpecifier: String, tokens: (String, String)?) -> String {
		let printfReplacement = "%\(idx)$\(formatSpecifier)"
		guard let (leftToken, rightToken) = tokens else {return printfReplacement}
		
		/* When stripping whitespaces and newlines from r in the line below, we
		 * assume whitespaces and newlines are all represented on a single unicode
		 * scalar. */
		if let r = simpleReplacementContent(from: xibLocValues, leftToken: leftToken, rightToken: rightToken, escapeToken: "~") {
			let r = String(r
				.filter{ $0.unicodeScalars.count != 1 || !CharacterSet.whitespacesAndNewlines.contains($0.unicodeScalars.first!) }
				.map{ $0.unicodeScalars.count != 1 || !CharacterSet.alphanumerics.contains($0.unicodeScalars.first!) ? Character("_") : $0 }
			)
			return "[\(printfReplacement):\(r)]"
		} else {
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Cannot get name of replacement (tokens %{public}@ and %{public}@) with values %@", log: $0, type: .info, leftToken, rightToken, xibLocValues) }}
			else                        {NSLog("Cannot get name of replacement (tokens %@ and %@) with values %@", leftToken, rightToken, xibLocValues)}
			return printfReplacement
		}
	}
	
	private static func simpleReplacementContent(from xibLocValues: [XibRefLocFile.Language: XibRefLocFile.Value], leftToken: String, rightToken: String, escapeToken: String?) -> String? {
		var r: String?
		let numberReplacementNameRetriever = Str2StrXibLocInfo(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: escapeToken,
			simpleSourceTypeReplacements: [:], orderedReplacements: [:], pluralGroups: [], attributesModifications: [:],
			simpleReturnTypeReplacements: [OneWordTokens(leftToken: leftToken, rightToken: rightToken): { r = $0; return "" }],
			dictionaryReplacements: nil, identityReplacement: { $0 }
		)
		
		if let englishValue = xibLocValues.first(where: { $0.key.lowercased().range(of: "english") != nil })?.value {
			_ = englishValue.applying(xibLocInfo: numberReplacementNameRetriever)
			if let r = r {return r}
		}
		for (_, v) in xibLocValues {
			_ = v.applying(xibLocInfo: numberReplacementNameRetriever)
			if r != nil {return r}
		}
		return nil
	}
	
}


private extension XibLocResolvingInfo where SourceType == String, ReturnType == String {
	
	init(simpleReplacementWithLeftToken leftToken: String, rightToken: String, value: String, escapeToken: String?) {
		self.init(
			defaultPluralityDefinition: PluralityDefinition(), escapeToken: escapeToken,
			simpleSourceTypeReplacements: [OneWordTokens(leftToken: leftToken, rightToken: rightToken): { _ in value }],
			orderedReplacements: [:], pluralGroups: [], attributesModifications: [:], simpleReturnTypeReplacements: [:], dictionaryReplacements: nil,
			identityReplacement: { $0 }
		)
	}
	
}

/*
 * Xib2Lokalise.swift
 * LocMapper
 *
 * Created by François Lamboley on 03/04/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log

import XibLoc



struct Xib2Lokalise {
	
	typealias Language = String
	
	enum LokaliseValue {
		
		struct Plural {
			
			let zero: String?
			let one: String?
			let two: String?
			let few: String?
			let many: String?
			let other: String?
			
		}
		
		case value(String)
		case plural(Plural)
		
	}
	
	private static func nilIfEmptyValue(from v: String) -> String? {
		return (v == "---" ? nil : v)
	}
	
	static func lokaliseValues(from xibLocValues: [XibRefLocFile.Language: XibRefLocFile.Value]) throws -> [Language: [TaggedObject<LokaliseValue>]] {
		let preprocessedXibLocValues = xibLocValues.mapValues{ v -> (String, Bool) in
			let doublePercented = v.replacingOccurrences(of: "%", with: "%%")
			let unpercented = doublePercented
				.replacingOccurrences(of: "%%@", with: "[%1$s:unnamed_at]").replacingOccurrences(of: "%%d", with: "[%1$d:unnamed_d]")
				.replacingOccurrences(of: "%%1$s", with: "[%1$s:unnamed_s]").replacingOccurrences(of: "%%2$s", with: "[%2$s:unnamed_s]")
				.replacingOccurrences(of: "%%0.*f", with: "%1$0.*f")
			return (unpercented, doublePercented != unpercented)
		}
		
		let transformersGroups = Xib2Std.computeTransformersGroups(from: preprocessedXibLocValues.mapValues{ $0.0 }, useLokalisePlaceholderFormat: true)
		assert(!transformersGroups.contains{ ts in ts.contains{ t in type(of: t) != type(of: ts.first!) } })
		
		let pluralTransformers = transformersGroups.compactMap{ $0 as? [LocValueTransformerPluralVariantPick] }
		guard pluralTransformers.count <= 1 else {throw NSError(domain: "Xib2Lokalise", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got more than one plural in a translation; don't know how to handle to send to Lokalise"])}
		
		let pluralTransformerBase = pluralTransformers.first?.first
		
		let stdLocEntryActions = Xib2Std.convertTransformersGroupsToStdLocEntryActions(transformersGroups.filter{ !($0.first is LocValueTransformerPluralVariantPick) })
		var values = [Language: [TaggedObject<LokaliseValue>]]()
		for stdLocEntryAction in stdLocEntryActions {
			for (l, (unpercentedValue, addPrintfReplacementTag)) in preprocessedXibLocValues {
				if addPrintfReplacementTag && !stdLocEntryAction.isEmpty {
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got a printf-style replacement AND a std loc entry action (%{public}@)", log: $0, type: .info, stdLocEntryAction) }}
					else                        {NSLog("Got a printf-style replacement AND a std loc entry action (%@)", stdLocEntryAction)}
				}
				/* About .replacingOccurrences(of: "~", with: "~~"):
				 *    - All the Xib replacements have an escape token;
				 *    - We know only the plural actually uses this escape token;
				 *    - So we escape the escape when not applying the plural.
				 * The correct solution would be to merge the different transformers
				 * somehow (but this is not a trivial task, and I don't want to do
				 * it). */
				let newValue = try stdLocEntryAction.reduce(unpercentedValue, { try $1.apply(toValue: $0.replacingOccurrences(of: "~", with: "~~"), withLanguage: l) })
				let lokaliseValue: LokaliseValue
				if let pluralTransformerBase = pluralTransformerBase {
					/* We have a plural! Let's treat it. */
					lokaliseValue = .plural(LokaliseValue.Plural(
						zero:  nilIfEmptyValue(from: try LocValueTransformerPluralVariantPick(copying: pluralTransformerBase, pluralUnicodeValue: .zero).apply(toValue: newValue, withLanguage: l)),
						one:   nilIfEmptyValue(from: try LocValueTransformerPluralVariantPick(copying: pluralTransformerBase, pluralUnicodeValue: .one).apply(toValue: newValue, withLanguage: l)),
						two:   nilIfEmptyValue(from: try LocValueTransformerPluralVariantPick(copying: pluralTransformerBase, pluralUnicodeValue: .two).apply(toValue: newValue, withLanguage: l)),
						few:   nilIfEmptyValue(from: try LocValueTransformerPluralVariantPick(copying: pluralTransformerBase, pluralUnicodeValue: .few).apply(toValue: newValue, withLanguage: l)),
						many:  nilIfEmptyValue(from: try LocValueTransformerPluralVariantPick(copying: pluralTransformerBase, pluralUnicodeValue: .many).apply(toValue: newValue, withLanguage: l)),
						other: nilIfEmptyValue(from: try LocValueTransformerPluralVariantPick(copying: pluralTransformerBase, pluralUnicodeValue: .other).apply(toValue: newValue, withLanguage: l))
					))
				} else {
					lokaliseValue = .value(newValue)
				}
				values[l, default: []].append(TaggedObject<LokaliseValue>(value: lokaliseValue, tags: Xib2Std.tags(from: stdLocEntryAction) + (addPrintfReplacementTag ? ["printf"] : [])))
			}
		}
		return values
	}
	
	private init() {/* The struct is only a containter for utility methods */}
	
}

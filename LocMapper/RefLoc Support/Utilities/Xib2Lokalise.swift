/*
 * Xib2Lokalise.swift
 * LocMapper
 *
 * Created by François Lamboley on 03/04/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation

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
		let transformersGroups = Xib2Std.computeTransformersGroups(from: xibLocValues, useLokalisePlaceholderFormat: true)
		assert(!transformersGroups.contains{ ts in ts.contains{ t in type(of: t) != type(of: ts.first!) } })
		
		let pluralTransformers = transformersGroups.compactMap{ $0 as? [LocValueTransformerPluralVariantPick] }
		guard pluralTransformers.count <= 1 else {throw NSError(domain: "Xib2Lokalise", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got more than one plural in a translation; don't know how to handle to send to Lokalise"])}
		
		let pluralTransformerBase = pluralTransformers.first?.first
		
		let stdLocEntryActions = Xib2Std.convertTransformersGroupsToStdLocEntryActions(transformersGroups.filter{ !($0.first is LocValueTransformerPluralVariantPick) })
		var values = [Language: [TaggedObject<LokaliseValue>]]()
		for stdLocEntryAction in stdLocEntryActions {
			for (l, v) in xibLocValues {
				let unpercentedValue = v
					.replacingOccurrences(of: "%", with: "%%").replacingOccurrences(of: "%%@", with: "[%s:unnamed]")
					.replacingOccurrences(of: "%%d", with: "[%d:unnamed]").replacingOccurrences(of: "%%0.*f", with: "%0.*f")
					.replacingOccurrences(of: "%%1$s", with: "[%1$s:unnamed]").replacingOccurrences(of: "%%2$s", with: "[%2$s:unnamed]")
				let newValue = try stdLocEntryAction.reduce(unpercentedValue, { try $1.apply(toValue: $0, withLanguage: l) })
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
				/* TODO: Create Lokalise tags instead of std ref loc tags */
				values[l, default: []].append(TaggedObject<LokaliseValue>(value: lokaliseValue, tags: Xib2Std.tags(from: stdLocEntryAction)))
			}
		}
		return values
	}
	
	private init() {/* The struct is only a containter for utility methods */}
	
}

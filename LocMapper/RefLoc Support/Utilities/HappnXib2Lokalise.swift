/*
 * HappnXib2Lokalise.swift
 * LocMapper
 *
 * Created by François Lamboley on 2018-04-03.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
import os.log
#endif

import GlobalConfModule
import Logging
import XibLoc



/**
 __NOT__ foolproof.
 Well actually, there are many cases that are not working.
 The whole thing has been done and thought for the happn case.
 
 Here are some raw notes from when I did the Xib2Std conversion process:
 ```
 DONE MANUALLY
 ————————————————————————————————————————————————
 |::| (App | A7O-gV-3m4.normalTitle & App | Wlf-dI-ogc.text)
 
 
 NOT DONE
 ————————————————————————————————————————————————
 ⑃⑂⑃ (Localizable | n days)
 remove default plurality definition
 
 
 DONE
 ————————————————————————————————————————————————
 `¦´ should be other by default
 add tag “gender”
 + converted to spaces
 remove when all is [VOID]
 %@ %s no 1$
 remove all spaces in variable names
 new tag: locmapper
 new tag: variable (for %etc)
 ⎡croisés⟡croisées⎤
 #n#/$n$
 %%
 ^^
 👓 <- translate to %s
 {LINK}
 à gérer chelou “Localizable | n unread<:s> conversations”
 
 
 PROBLEMS
 ————————————————————————————————————————————————
 Hungarian, key “User Profiles | avm: number of songs exceeded”: no plural
 Hungarian, key “User Profiles | n common friends”: no plural
 Hungarian, key “User Profiles | n common interests”: no plural
 Hungarian, key “Notifications | reward invite non-premium”: no plural
 Polish, key “Home | crossed paths N times”: no plural
 Hungarian, key “Invite | 8Sj-sP-UWp.text”: no plural
 Hungarian, key “Notifications | reward new account non-premium”: no plural
 Russian, key “Photo Album | b6c-10-mWH.text”: no plural
 Hungarian, key “Pop-Ups | invite friends explanation non-premium line 2”: no plural
 Hungarian, key “Pop-Ups | follow twitter explanation non-premium line 2”: no plural
 ``` */
struct HappnXib2Lokalise {
	
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
		
		let transformersGroups = HappnXib2Std.computeTransformersGroups(from: preprocessedXibLocValues.mapValues{ $0.0 }, useLokalisePlaceholderFormat: true)
		assert(!transformersGroups.contains{ ts in ts.contains{ t in type(of: t) != type(of: ts.first!) } })
		
		let pluralTransformers = transformersGroups.compactMap{ $0 as? [LocValueTransformerPluralVariantPick] }
		guard pluralTransformers.count <= 1 else {throw NSError(domain: "HappnXib2Lokalise", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got more than one plural in a translation; don't know how to handle to send to Lokalise"])}
		
		let pluralTransformerBase = pluralTransformers.first?.first
		
		let stdLocEntryActions = HappnXib2Std.convertTransformersGroupsToStdLocEntryActions(transformersGroups.filter{ !($0.first is LocValueTransformerPluralVariantPick) })
		var values = [Language: [TaggedObject<LokaliseValue>]]()
		for stdLocEntryAction in stdLocEntryActions {
			for (l, (unpercentedValue, addPrintfReplacementTag)) in preprocessedXibLocValues {
				if addPrintfReplacementTag && (!stdLocEntryAction.filter({ !($0 is LocValueTransformerGenderVariantPick) }).isEmpty || pluralTransformerBase != nil) {
#if canImport(os)
					Conf.oslog.flatMap{ os_log("Got a printf-style replacement AND a non-gender std loc entry action (%{public}@)", log: $0, type: .info, stdLocEntryAction) }
#endif
					Conf.logger?.warning("Got a printf-style replacement AND a non-gender std loc entry action (\(stdLocEntryAction))")
				}
				/* About .replacingOccurrences(of: "~", with: "~~"):
				 *    - All the Xib replacements have an escape token;
				 *    - We know only the plural actually uses this escape token;
				 *    - So we escape the escape when not applying the plural.
				 * The correct solution would be to merge the different transformers somehow (but this is not a trivial task, and I don't want to do it). */
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
				values[l, default: []].append(TaggedObject<LokaliseValue>(value: lokaliseValue, tags: HappnXib2Std.tags(from: stdLocEntryAction) + (addPrintfReplacementTag ? ["printf"] : [])))
			}
		}
		return values
	}
	
	private init() {/* The struct is only a containter for utility methods */}
	
}

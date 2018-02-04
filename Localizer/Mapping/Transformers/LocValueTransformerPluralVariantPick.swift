/*
 * LocValueTransformerPluralVariantPick.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log

import XibLoc



class LocValueTransformerPluralVariantPick : LocValueTransformer {
	
	enum UnicodePluralValue : String {
		case zero = "zero"
		case one = "one"
		case two = "two"
		case few = "few"
		case many = "many"
		case other = "other"
		init?(string: String) {
			switch string.lowercased() {
			case "zero",  "z", "0": self = .zero
			case "one",   "o", "1": self = .one
			case "two",   "t", "2": self = .two
			case "few",   "f":      self = .few
			case "many",  "m":      self = .many
			case "other", "x":      self = .other
			default: return nil
			}
		}
	}
	
	override var isValid: Bool {
		return true
	}
	
	let unicodeValue: UnicodePluralValue
	let openDelim: String
	let middleDelim: String
	let closeDelim: String
	let escapeToken: String?
	
	init(serialization: [String: Any]) throws {
		guard let vs = serialization["value"] as? String, let v = UnicodePluralValue(string: vs) else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid plural value."])
		}
		
		if let d = serialization["open_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty open delimiter, which is invalid."])}
			openDelim = d
		} else {openDelim = "<"}
		
		if let d = serialization["middle_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty middle delimiter, which is invalid."])}
			middleDelim = d
		} else {middleDelim = ":"}
		
		if let d = serialization["close_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty close delimiter, which is invalid."])}
			closeDelim = d
		} else {closeDelim = ">"}
		
		unicodeValue = v
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = nil}
		
		/* Let's check the values retrieved from serialization are ok.
		 * TODO: Maybe check the open/close/middle delimiter constraints from XibLoc. */
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		var ret = [
			"value": unicodeValue.rawValue,
			"open_delimiter": openDelim,
			"middle_delimiter": middleDelim,
			"close_delimiter": closeDelim
		]
		if let e = escapeToken {ret["escape_token"] = e}
		return ret
	}
	
	/* https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
	 * https://www.unicode.org/reports/tr35/tr35-numbers.html#Operands
	 *
	 * English:               one:i=1&v=0
	 * German:                one:i=1&v=0
	 * Spanish:               one:n=1
	 * Italian:               one:i=1&v=0
	 * Hungarian:             one:n=1
	 * Portuguese (Portugal): one:i=1&v=0
	 * Turkish:               one:n=1
	 * Thai:                  N/A
	 * Chinese:               N/A
	 * Japanese:              N/A
	 * Greek:                 one:n=1
	 * French:                one:i=0,1
	 * Portuguese (Brazil):   one:i=0..1
	 * Polish:                one:i=1&v=0;              few:v=0&i%10=2..4&i%100!=12..14; many:v=0&((i!=1&i%10=0..1)|(i%10=5..9)|(i%100=12..14))
	 * Russian:               one:v=0&i%10=1&i%100!=11; few:v=0&i%10=2..4&i%100!=12..14; many:v=0&((i%10=0)|(i%10=5..9)|(i%100=11..14)) */
	override func apply(toValue value: String, withLanguage language: String) throws -> String {
		/* We only treat the integer cases. */
		let language = language.lowercased()
		
		let n: Int?
		let pluralityDefinition: PluralityDefinition
		if Set(["english", "german", "spanish", "italian", "hungarian", "turkish", "thai", "chinese", "japanese", "greek", "french", "portuguese"]).contains(where: { language.range(of: $0) != nil }) {
			/* Technically, for French and Brazilian Portuguese, the plurality
			 * definition is "(0:1)(*)", but as we use 1 and 2 for the values of n,
			 * we don't care about the difference in the 0 case for these two
			 * languages! */
			pluralityDefinition = PluralityDefinition(string: "(1)(*)")
			switch unicodeValue {
			case .one:   n = 1
			case .other: n = 2
			default:     n = nil
			}
		} else if language.range(of: "polish") != nil {
			/* Note: We do not require the full plurality definition here as we use
			 *       static values when resolving the string... Let's put it anyway
			 *       for reference. */
			pluralityDefinition = PluralityDefinition(string: "(1)(2→4:^*[^1][2→4]$)?(*)")
			switch unicodeValue {
			case .one:   n = 1
			case .few:   n = 2
			case .many:  n = 5
			case .other: n = 5 /* Because we don't treat the float cases, “other” is the same as “many” */
			default:     n = nil
			}
		} else if language.range(of: "russian") != nil {
			/* Note: We do not require the full plurality definition here as we use
			 *       static values when resolving the string... Let's put it anyway
			 *       for reference. */
			pluralityDefinition = PluralityDefinition(string: "(1:^*[^1]1$)(2→4:^*[^1][2→4]$)?(*)")
			switch unicodeValue {
			case .one:   n = 1
			case .few:   n = 2
			case .many:  n = 5
			case .other: n = 5 /* Because we don't treat the float cases, “other” is the same as “many” */
			default:     n = nil
			}
		} else {
			throw MappingResolvingError.languageNotFound
		}
		guard let nn = n else {return "---"} /* Code for “this value should be ignored” */
		
		let xibLocInfo = Str2StrXibLocInfo(
			defaultPluralityDefinition: pluralityDefinition,
			simpleSourceTypeReplacements: [OneWordTokens(token: "#"): { _ in "%1$d" }],
			pluralGroups: [(MultipleWordsTokens(leftToken: "<", interiorToken: ":", rightToken: ">"), .int(nn))],
			identityReplacement: { $0 }
		)
		return value.applying(xibLocInfo: xibLocInfo)
	}
	
}

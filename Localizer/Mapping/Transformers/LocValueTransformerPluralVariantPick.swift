/*
 * LocValueTransformerPluralVariantPick.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



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
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		/* TODO */
		var ret = value
		return ret
	}
	
}

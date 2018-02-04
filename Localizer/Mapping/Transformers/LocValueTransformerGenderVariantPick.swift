/*
 * LocValueTransformerGenderVariantPick.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import XibLoc



class LocValueTransformerGenderVariantPick : LocValueTransformer {
	
	override class var serializedType: String {return "gender_variant_pick"}
	
	enum Gender {
		case male, female
		init?(string: String) {
			switch string.lowercased() {
			case "male",   "m": self = .male
			case "female", "f": self = .female
			default: return nil
			}
		}
		func toString() -> String {
			switch self {
			case .male:   return "male"
			case .female: return "female"
			}
		}
	}
	
	override var isValid: Bool {
		return true
	}
	
	let gender: Gender
	let openDelim: String
	let middleDelim: String
	let closeDelim: String
	let escapeToken: String?
	
	init(serialization: [String: Any]) throws {
		guard let gs = serialization["gender"] as? String, let g = Gender(string: gs) else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid gender."])
		}
		
		if let d = serialization["open_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty open delimiter, which is invalid."])}
			openDelim = d
		} else {openDelim = "`"}
		
		if let d = serialization["middle_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty middle delimiter, which is invalid."])}
			middleDelim = d
		} else {middleDelim = "¦"}
		
		if let d = serialization["close_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty close delimiter, which is invalid."])}
			closeDelim = d
		} else {closeDelim = "´"}
		
		gender = g
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = nil}
		
		/* Let's check the values retrieved from serialization are ok.
		 * TODO: Maybe check the open/close/middle delimiter constraints from XibLoc. */
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		var ret = [
			"gender": gender.toString(),
			"open_delimiter": openDelim,
			"middle_delimiter": middleDelim,
			"close_delimiter": closeDelim
		]
		if let e = escapeToken {ret["escape_token"] = e}
		return ret
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		return value.applying(xibLocInfo: XibLocResolvingInfo(genderReplacementWithLeftToken: openDelim, interiorToken: middleDelim, rightToken: closeDelim, valueIsMale: gender == .male))
	}
	
}

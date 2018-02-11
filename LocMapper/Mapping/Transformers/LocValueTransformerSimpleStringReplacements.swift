/*
 * LocValueTransformerSimpleStringReplacements.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class LocValueTransformerSimpleStringReplacements : LocValueTransformer {
	
	override class var serializedType: String {return "simple_string_replacements"}
	
	override var isValid: Bool {
		return true
	}
	
	let replacements: [String: String]
	
	init(serialization: [String: Any]) throws {
		guard let r = serialization["replacements"] as? [String: String] else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key \"replacements\" is either undefined or not [String: String]."])
		}
		
		replacements = r
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		return ["replacements": replacements]
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		var ret = value
		for (r, v) in replacements {
			ret = ret.replacingOccurrences(of: r, with: v)
		}
		return ret
	}
	
}

/*
 * LocKeyMappingComponentToConstant.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class LocKeyMappingComponentToConstant : LocKeyMappingComponent {
	
	override class var serializedType: String {return "to_constant"}
	
	override var isValid: Bool {
		return true
	}
	
	let constant: String
	
	init(serialization: [String: Any]) throws {
		guard let c = serialization["constant"] as? String else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key \"constant\" is either undefined or not a String."])
		}
		
		constant = c
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		return ["constant": constant]
	}
	
	override func apply(forLanguage language: String, entries: [LocFile.LineKey: LocFile.LineValue]) throws -> String {
		return constant
	}
	
}

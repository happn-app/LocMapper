/*
 * LocValueTransformerToUpper.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class LocValueTransformerToUpper : LocValueTransformer {
	
	override var isValid: Bool {
		return true
	}
	
	init(serialization: [String: Any]) throws {
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		return [:]
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		return value.uppercased()
	}
	
}

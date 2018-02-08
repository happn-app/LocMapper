/*
 * LocValueTransformerRegionDelimitersReplacement.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import XibLoc



class LocValueTransformerRegionDelimitersReplacement : LocValueTransformer {
	
	override class var serializedType: String {return "region_delimiters_replacement"}
	
	override var isValid: Bool {
		return true
	}
	
	let openDelim: String
	let closeDelim: String
	let escapeToken: String?
	
	let replacement: String
	
	init(serialization: [String: Any]) throws {
		guard let r  = serialization["replacement"] as? String else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid or missing open_delimiter, close_delimiter or replacement."])
		}
		
		if let d = serialization["open_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty open delimiter, which is invalid."])}
			openDelim = d
		} else {openDelim = "|"}
		
		if let d = serialization["close_delimiter"] as? String {
			guard !d.isEmpty else {throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Got empty close delimiter, which is invalid."])}
			closeDelim = d
		} else {closeDelim = "|"}
		
		replacement = r
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = nil}
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any] {
		var ret = [
			"open_delimiter": openDelim,
			"close_delimiter": closeDelim,
			"replacement": replacement
		]
		if let e = escapeToken {ret["escape_token"] = e}
		return ret
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		return value.applying(xibLocInfo: XibLocResolvingInfo(simpleReplacementWithLeftToken: openDelim, rightToken: closeDelim, value: replacement))
	}
	
}

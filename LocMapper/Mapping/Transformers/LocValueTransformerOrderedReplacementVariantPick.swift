/*
 * LocValueTransformerOrderedReplacementVariantPick.swift
 * LocMapper
 *
 * Created by François Lamboley on 4/24/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import XibLoc



class LocValueTransformerOrderedReplacementVariantPick : LocValueTransformer {
	
	override class var serializedType: String {return "ordered_replacement_pick"}
	
	override var isValid: Bool {
		return true
	}
	
	let index: Int
	let openDelim: String
	let middleDelim: String
	let closeDelim: String
	
	let escapeToken: String?
	
	init(index i: Int, openDelim od: String, middleDelim md: String, closeDelim cd: String, escapeToken e: String? = "~") {
		index = i
		openDelim = od
		middleDelim = md
		closeDelim = cd
		
		escapeToken = e
	}
	
	init(serialization: [String: Any?]) throws {
		guard let i = serialization["index"] as? Int else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid index."])
		}
		
		index = i
		
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
		
		if let e = serialization["escape_token"] as? String, !e.isEmpty {escapeToken = e}
		else                                                            {escapeToken = "~"}
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any?] {
		return [
			"index": index,
			"open_delimiter": openDelim,
			"middle_delimiter": middleDelim,
			"close_delimiter": closeDelim,
			"escape_token": escapeToken
		]
	}
	
	override func apply(toValue value: String, withLanguage: String) throws -> String {
		guard let xibLocInfo = Str2StrXibLocInfo(
			defaultPluralityDefinition: PluralityDefinition(matchingNothing: ()), escapeToken: escapeToken, simpleSourceTypeReplacements: [:],
			orderedReplacements: [MultipleWordsTokens(leftToken: openDelim, interiorToken: middleDelim, rightToken: closeDelim): index],
			pluralGroups: [], attributesModifications: [:], simpleReturnTypeReplacements: [:],
			identityReplacement: { $0 }
		) else {
			throw MappingResolvingError.invalidXibLocTokens
		}
		return value.applying(xibLocInfo: xibLocInfo)
	}
	
}

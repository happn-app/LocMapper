/*
 * happnCSVLocKeyMapping.swift
 * Localizer
 *
 * Created by François Lamboley on 12/3/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation
import os.log



class happnCSVLocKeyMapping {
	
	let originalStringRepresentation: String
	var components: [happnCSVLocKeyMappingComponent]?
	
	/** Compute whether the given transform is valid (do not check for
	existence of keys for mapping components though). */
	var isValid: Bool {
		guard let components = components else {return false}
		for c in components {guard c.isValid else {return false}}
		return true
	}
	
	/** Inits a happn CSV Loc Key Mapping from a string representation (JSON).
	
	If the string is empty, returns nil.
	
	If the string representation is invalid (invalid JSON, etc.), a fully inited
	object is returned with nil components. */
	convenience init?(stringRepresentation: String) {
		guard !stringRepresentation.isEmpty else {return nil}
		
		guard
			let data = stringRepresentation.data(using: .utf8),
			let serializedComponent_s = try? JSONSerialization.jsonObject(with: data, options: []) else
		{
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Invalid mapping; cannot serialize JSON string: \"%@\"", log: $0, type: .info, stringRepresentation) }}
			else                        {NSLog("Invalid mapping; cannot serialize JSON string: \"%@\"", stringRepresentation)}
			self.init(components: nil, stringRepresentation: stringRepresentation)
			return
		}
		let serializedComponents: [[String: AnyObject]]
		if      let array = serializedComponent_s as? [[String: AnyObject]] {serializedComponents = array}
		else if let simple = serializedComponent_s as? [String: AnyObject]  {serializedComponents = [simple]}
		else {
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Invalid mapping; cannot convert string to array of dictionary: \"%@\"", log: $0, type: .info, stringRepresentation) }}
			else                        {NSLog("Invalid mapping; cannot convert string to array of dictionary: \"%@\"", stringRepresentation)}
			self.init(components: nil, stringRepresentation: stringRepresentation)
			return
		}
		
		self.init(components: serializedComponents.map {happnCSVLocKeyMappingComponent.createCSVLocKeyMappingFromSerialization($0)}, stringRepresentation: stringRepresentation)
	}
	
	convenience init(components: [happnCSVLocKeyMappingComponent]) {
		self.init(components: components, stringRepresentation: happnCSVLocKeyMapping.stringRepresentationFromComponentsList(components))
	}
	
	init(components c: [happnCSVLocKeyMappingComponent]?, stringRepresentation: String) {
		components = c
		originalStringRepresentation = stringRepresentation
	}
	
	func stringRepresentation() -> String {
		if let components = components {
			return happnCSVLocKeyMapping.stringRepresentationFromComponentsList(components)
		} else {
			return originalStringRepresentation
		}
	}
	
	func apply(forLanguage language: String, entries: [happnCSVLocFile.LineKey: happnCSVLocFile.LineValue]) throws -> String {
		guard isValid, let components = components else {
			throw MappingResolvingError.invalidMapping
		}
		
		var res = ""
		for component in components {
			assert(component.isValid) /* Checked above with isValid */
			res += try component.apply(forLanguage: language, entries: entries)
		}
		return res
	}
	
	private static func stringRepresentationFromComponentsList(_ components: [happnCSVLocKeyMappingComponent]) -> String {
		let allSerialized = components.map {$0.serialize()}
		return try! String(
			data: JSONSerialization.data(
				withJSONObject: (allSerialized.count == 1 ? allSerialized[0] as AnyObject : allSerialized as AnyObject),
				options: [.prettyPrinted]
			),
			encoding: .utf8
		)!
	}
	
}

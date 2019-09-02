/*
 * LocKeyMapping.swift
 * LocMapper
 *
 * Created by François Lamboley on 12/3/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

#if !canImport(os) && canImport(DummyLinuxOSLog)
	import DummyLinuxOSLog
#endif



public final class LocKeyMapping {
	
	public let originalStringRepresentation: String
	public var components: [LocKeyMappingComponent]?
	
	/** Compute whether the given transform is valid (do not check for
	existence of keys for mapping components though). */
	public var isValid: Bool {
		guard let components = components else {return false}
		for c in components {guard c.isValid else {return false}}
		return true
	}
	
	public var linkedKeys: [LocFile.LineKey] {
		return components?.flatMap{ $0.linkedKeys } ?? []
	}
	
	/** Inits a LocFile Key Mapping from a string representation (JSON).
	
	If the string is empty, returns nil.
	
	If the string representation is invalid (invalid JSON, etc.), a fully inited
	object is returned with nil components. */
	public convenience init?(stringRepresentation: String) {
		guard !stringRepresentation.isEmpty else {return nil}
		
		guard
			let data = stringRepresentation.data(using: .utf8),
			let serializedComponent_s = try? JSONSerialization.jsonObject(with: data, options: []) else
		{
			#if canImport(os)
				di.log.flatMap{ os_log("Invalid mapping; cannot serialize JSON string: \"%@\"", log: $0, type: .info, stringRepresentation) }
			#else
				NSLogString("Invalid mapping; cannot serialize JSON string: \"\(stringRepresentation)\"", log: di.log)
			#endif
			self.init(components: nil, stringRepresentation: stringRepresentation)
			return
		}
		let serializedComponents: [[String: Any?]]
		if      let array = serializedComponent_s as? [[String: Any?]] {serializedComponents = array}
		else if let simple = serializedComponent_s as? [String: Any?]  {serializedComponents = [simple]}
		else {
			#if canImport(os)
				di.log.flatMap{ os_log("Invalid mapping; cannot convert string to array of dictionary: \"%@\"", log: $0, type: .info, stringRepresentation) }
			#else
				NSLogString("Invalid mapping; cannot convert string to array of dictionary: \"\(stringRepresentation)\"", log: di.log)
			#endif
			self.init(components: nil, stringRepresentation: stringRepresentation)
			return
		}
		
		self.init(components: serializedComponents.map{ LocKeyMappingComponent.createCSVLocKeyMappingFromSerialization($0) }, stringRepresentation: stringRepresentation)
	}
	
	public convenience init(components: [LocKeyMappingComponent]) {
		self.init(components: components, stringRepresentation: LocKeyMapping.stringRepresentationFromComponentsList(components, prettyPrint: false))
	}
	
	init(components c: [LocKeyMappingComponent]?, stringRepresentation: String) {
		components = c
		originalStringRepresentation = stringRepresentation
	}
	
	public func stringRepresentation(prettyPrint: Bool) -> String {
		if let components = components {
			return LocKeyMapping.stringRepresentationFromComponentsList(components, prettyPrint: prettyPrint)
		} else {
			return originalStringRepresentation
		}
	}
	
	public func apply(forLanguage language: String, entries: [LocFile.LineKey: LocFile.LineValue]) throws -> String {
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
	
	private static func stringRepresentationFromComponentsList(_ components: [LocKeyMappingComponent], prettyPrint: Bool) -> String {
		let jsonOptions: JSONSerialization.WritingOptions
		let baseJSONOptions: JSONSerialization.WritingOptions = (prettyPrint ? [.prettyPrinted] : [])
		if #available(OSX 10.13, iOS 11.0, *) {jsonOptions = baseJSONOptions.union(.sortedKeys)}
		else                                  {jsonOptions = baseJSONOptions}
		let allSerialized = components.map{ $0.serialize() }
		let str = try! String(
			data: JSONSerialization.data(
				withJSONObject: (allSerialized.count == 1 ? allSerialized[0] : allSerialized),
				options: jsonOptions
			),
			encoding: .utf8
		)!
		return str
	}
	
}

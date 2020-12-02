/*
 * LocValueTransformerRegexReplacements.swift
 * LocMapper
 *
 * Created by François Lamboley on 4/24/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



class LocValueTransformerRegexReplacements : LocValueTransformer {
	
	override class var serializedType: String {return "regex_replacements"}
	
	override var isValid: Bool {
		return true
	}
	
	let replacements: [(NSRegularExpression, String)]
	
	init(replacements r: [(NSRegularExpression, String)]) {
		replacements = r
	}
	
	init(serialization: [String: Any?]) throws {
		guard let r = serialization["replacements"] as? [String], r.count % 2 == 0 else {
			throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key \"replacements\" is either undefined or not [String] or does not have an even number of elements."])
		}
		
		let even = stride(from: r.startIndex,   to: r.endIndex, by: 2).map{ r[$0] }
		let odd  = stride(from: r.startIndex+1, to: r.endIndex, by: 2).map{ r[$0] }
		replacements = try zip(even, odd).map{
			let (k, v) = $0
			guard let regex = try? NSRegularExpression(pattern: k, options: []) else {
				throw NSError(domain: "MigratorMapping", code: 1, userInfo: [NSLocalizedDescriptionKey: "Key \"replacements\" contains an invalid regular expression: \(k)"])
			}
			return (regex, v)
		}
		
		super.init()
	}
	
	override func serializePrivateData() -> [String: Any?] {
		return ["replacements": replacements.flatMap{ rv -> [String] in
			let (r, v) = rv
			return [r.pattern, v]
		}]
	}
	
	override func apply(toValue value: String, withLanguage language: String) throws -> String {
		var ret = value
		for (r, v) in replacements {
			ret = r.stringByReplacingMatches(in: ret, options: [], range: NSRange(ret.startIndex..<ret.endIndex, in: ret), withTemplate: v)
		}
		return ret
	}
	
}

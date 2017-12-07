/*
 * PluralityDefinitionZoneValueGlob.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct PluralityDefinitionZoneValueGlob : PluralityDefinitionZoneValue {
	
	/** Returns an “any number” glob match zone value (matches any number, either
	ints or floats). Equivalent of `init(string: "*")!`. An argument is required
	because we can't create an init method that has no argument and a name... */
	init(forAnyNumber: Void) {
		value = .anyNumber
	}
	
	/** Returns an “any float” glob match zone value (matches 1.0 but not 1).
	Equivalent of `init(string: "*.")!`. An argument is required because we can't
	create an init method that has no argument and a name... */
	init(forAnyFloat: Void) {
		value = .anyFloat
	}
	
	init?(string: String) {
		switch string {
		case "*", "^*{.*}$": value = .anyNumber
		case "*.", "^*.*$":  value = .anyFloat
			
		default:
			guard string.hasPrefix("^") && string.hasSuffix("$") else {return nil}
			
			var transformedString = string
			transformedString = transformedString.replacingOccurrences(of: ".", with: "\\.")
			transformedString = transformedString.replacingOccurrences(of: "?", with: "[0-9]")
			transformedString = transformedString.replacingOccurrences(of: "*", with: "[0-9]*")
			transformedString = transformedString.replacingOccurrences(of: "→", with: "-")
			transformedString = transformedString.replacingOccurrences(of: "{", with: "(")
			transformedString = transformedString.replacingOccurrences(of: "}", with: ")?")
			
			if       transformedString.hasPrefix("^+") {transformedString.remove(at: transformedString.index(after: transformedString.startIndex))} /* We remove the "+" */
			else if !transformedString.hasPrefix("^-") {transformedString.insert(contentsOf: "-?+", at: transformedString.index(after: transformedString.startIndex))}
//			HCLogTS("Glob language to regex conversion: \(string) --> \(transformedString)")
			
			do {value = .regex(try NSRegularExpression(pattern: string, options: []))}
			catch {
				/* We used to use HCLogES */
				NSLog("%@", "Cannot create regular expression from string \"\(transformedString)\" (original was \"\(string)\"); got error \(error)")
				return nil
			}
		}
	}
	
	func matches(int: Int) -> Bool {
		switch value {
		case .anyNumber: return true
		case .anyFloat:  return false
		case .regex:     return matches(string: String(int))
		}
	}
	
	func matches(float: Float, precision: Float) -> Bool {
		switch value {
		case .anyNumber, .anyFloat: return true
			
		case .regex:
			var stringValue = String(format: "%.15f", float)
			while stringValue.hasSuffix("0") {stringValue = String(stringValue.dropLast())}
			return matches(string: stringValue)
		}
	}
	
	var debugDescription: String {
		return "HCPluralityDefinitionZoneValueGlob: value = \(value)"
	}
	
	private enum ValueType {
		case anyNumber
		case anyFloat
		case regex(NSRegularExpression)
	}
	
	private let value: ValueType
	
	private func matches(string: String) -> Bool {
		switch value {
		case .anyNumber, .anyFloat: return false
			
		case .regex(let regexp):
			guard let r = regexp.firstMatch(in: string, options: [], range: NSRange(location: 0, length: (string as NSString).length)) else {return false}
			guard r.range.location != NSNotFound else {return false} /* Not sure if needed, but better safe than sorry... */
			return true
		}
	}
	
}

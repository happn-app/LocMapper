/*
 * XcodeStringsFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation



protocol StringsComponent {
	var stringValue: String { get }
}

class XcodeStringsFile: Streamable {
	let filepath: String
	let components: [StringsComponent]
	
	class WhiteSpace: StringsComponent {
		let content: String
		
		var stringValue: String {return content}
		
		init(_ c: String) {
			assert(c.rangeOfCharacterFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet().invertedSet) == nil, "Invalid white space string")
			content = c
		}
	}
	
	class Comment: StringsComponent {
		let content: String
		
		var stringValue: String {return "/*\(content)*/"}
		
		init(_ c: String) {
			assert(c.rangeOfString("*/") == nil, "Invalid comment string")
			content = c
		}
	}
	
	class LocalizedString: StringsComponent {
		let key: String
		let equal: String
		let value: String
		let semicolon: String
		let keyHasQuotes: Bool
		
		var stringValue: String {
			var ret = ""
			if keyHasQuotes {ret += "\""}
			ret += key
			if keyHasQuotes {ret += "\""}
			ret += "\(equal)\"\(value)\"\(semicolon)"
			return ret
		}
		
		init(key k: String, keyHasQuotes qfk: Bool, equalSign e: String, value v: String, andSemicolon s: String) {
			assert(e.componentsSeparatedByString("=").count == 2, "Invalid equal sign")
			assert(e.componentsSeparatedByString("=")[0].rangeOfCharacterFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet().invertedSet) == nil, "Invalid equal sign")
			assert(e.componentsSeparatedByString("=")[1].rangeOfCharacterFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet().invertedSet) == nil, "Invalid equal sign")
			key = k
			equal = e
			value = v
			semicolon = s
			keyHasQuotes = qfk
		}
	}
	
	convenience init(fromPath path: String) {
		var encoding: UInt = 0
		let filecontent = NSString(contentsOfFile: path, usedEncoding: &encoding, error: nil)! /* Currently not possible to correctly handle failure in init */
		self.init(filepath: path, filecontent: filecontent)
	}
	
	convenience init(filepath path: String, filecontent: String) {
		/* Let's parse the stream */
		var components = [StringsComponent]()
		var idling = true
		var currentKey = String()
		var currentValue = String()
		var currentWhite = String()
		var currentEqual = String()
		var currentComment = String()
		var currentSemicolon = String()
		var currentKeyHasQuote = true
		
		var engine: ((Character) -> Bool)!
		var treat_key_char_ptr: ((Character) -> Bool)!
		var treat_idle_char_ptr: ((Character) -> Bool)!
		var wait_end_comment_ptr: ((Character) -> Bool)!
		var treat_value_char_ptr: ((Character) -> Bool)!
		var confirm_end_comment_ptr: ((Character) -> Bool)!
		var treat_semicolon_char_ptr: ((Character) -> Bool)!
		var confirm_comment_start_ptr: ((Character) -> Bool)!
		var treat_key_escaped_char_ptr: ((Character) -> Bool)!
		var treat_value_escaped_char_ptr: ((Character) -> Bool)!
		var treat_after_equal_between_char_ptr: ((Character) -> Bool)!
		var treat_before_equal_between_char_ptr: ((Character) -> Bool)!
		var treat_key_char_no_double_quotes_ptr: ((Character) -> Bool)!
		
		/* Confirm End Comment */
		func confirm_end_comment(c: Character) -> Bool {
			if c == "/" {
				components.append(Comment(currentComment))
				idling = true
				engine = treat_idle_char_ptr
			} else {
				currentComment.append("*" as Character)
				if c != "*" {
					currentComment.append(c)
					engine = wait_end_comment_ptr
				}
			}
			
			return true
		}
		confirm_end_comment_ptr = confirm_end_comment
		
		/* Confirm End Comment */
		func wait_end_comment(c: Character) -> Bool {
			if c != "*" {
				currentComment.append(c)
				return true
			}
			engine = confirm_end_comment_ptr
			return true
		}
		wait_end_comment_ptr = wait_end_comment
		
		func confirm_comment_start(c: Character) -> Bool {
			if c != "*" {return false}
			
			currentComment = String()
			engine = wait_end_comment_ptr
			return true
		}
		confirm_comment_start_ptr = confirm_comment_start
		
		func treat_semicolon_char(c: Character) -> Bool {
			if c == "\n" || c == "\t" || c == " " {
				currentSemicolon.append(c)
				return true
			}
			if c == ";" {
				currentSemicolon.append(c)
				components.append(LocalizedString(key: currentKey, keyHasQuotes: currentKeyHasQuote, equalSign: currentEqual, value: currentValue, andSemicolon: currentSemicolon))
				idling = true
				engine = treat_idle_char_ptr
				return true
			}
			return false
		}
		treat_semicolon_char_ptr = treat_semicolon_char
		
		func treat_value_escaped_char(c: Character) -> Bool {
			currentValue.append("\\" as Character)
			currentValue.append(c)
			engine = treat_value_char_ptr
			return true
		}
		treat_value_escaped_char_ptr = treat_value_escaped_char
		
		func treat_value_char(c: Character) -> Bool {
			if      c == "\\" {engine = treat_value_escaped_char_ptr}
			else if c != "\"" {currentValue.append(c)}
			else              {engine = treat_semicolon_char_ptr}
			return true
		}
		treat_value_char_ptr = treat_value_char
		
		func treat_after_equal_between_char(c: Character) -> Bool {
			if c == "\"" {
				engine = treat_value_char_ptr
				return true
			}
			if c == "\n" || c == "\t" || c == " " {
				currentEqual.append(c)
				return true
			}
			return false
		}
		treat_after_equal_between_char_ptr = treat_after_equal_between_char
		
		func treat_before_equal_between_char(c: Character) -> Bool {
			if c == "=" {
				engine = treat_after_equal_between_char_ptr
				currentEqual.append(c)
				return true
			}
			if c == "\n" || c == "\t" || c == " " {
				currentEqual.append(c)
				return true
			}
			return false
		}
		treat_before_equal_between_char_ptr = treat_before_equal_between_char
		
		func treat_key_escaped_char(c: Character) -> Bool {
			currentKey.append("\\" as Character)
			currentKey.append(c)
			engine = treat_key_char_ptr
			return true
		}
		treat_key_escaped_char_ptr = treat_key_escaped_char
		
		func treat_key_char(c: Character) -> Bool {
			if      c == "\\" {engine = treat_key_escaped_char_ptr}
			else if c == "\"" {engine = treat_before_equal_between_char_ptr}
			else              {currentKey.append(c)}
			return true
		}
		treat_key_char_ptr = treat_key_char
		
		func treat_key_char_no_double_quotes(c: Character) -> Bool {
			if (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") {
				currentKey.append(c)
				return true
			}
			if c == "\n" || c == "\t" || c == " " {
				currentEqual.append(c)
				engine = treat_before_equal_between_char_ptr
				return true
			}
			
			return false
		}
		treat_key_char_no_double_quotes_ptr = treat_key_char_no_double_quotes
		
		func treat_idle_char(c: Character) -> Bool {
			if c == "\n" || c == "\t" || c == " " {
				currentWhite.append(c)
				return true
			} else if c == "/" {
				components.append(WhiteSpace(currentWhite))
				currentWhite = String()
				idling = false
				engine = confirm_comment_start_ptr
				return true
			} else if c == "\"" {
				components.append(WhiteSpace(currentWhite))
				currentWhite = String()
				currentKeyHasQuote = true
				currentKey = String(); currentEqual = String(); currentValue = String(); currentSemicolon = String()
				idling = false
				engine = treat_key_char_ptr
				return true
			} else if (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") {
				components.append(WhiteSpace(currentWhite))
				currentWhite = String()
				currentKeyHasQuote = false
				currentKey = String(c); currentEqual = String(); currentValue = String(); currentSemicolon = String()
				idling = false
				engine = treat_key_char_no_double_quotes_ptr
				return true
			}
			
			return false
		}
		treat_idle_char_ptr = treat_idle_char
		
		
		var i = 0
		var ok = true
		engine = treat_idle_char
		for c in filecontent {
			ok = engine(c)
			if !ok {break}
		}
		
		assert(ok, "There was an error parsing the file \(path)")
		assert(idling, "There was an error parsing the file \(path)")
		
		if !currentWhite.isEmpty {components.append(WhiteSpace(currentWhite))}
		self.init(filepath: path, components: components)
	}
	
	init(filepath: String, components: [StringsComponent]) {
		self.filepath   = filepath
		self.components = components
	}
	
	func writeTo<Target : OutputStreamType>(inout target: Target) {
		for component in components {
			component.stringValue.writeTo(&target)
		}
	}
}

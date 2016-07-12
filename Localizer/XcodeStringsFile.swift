/*
 * XcodeStringsFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation



protocol XcodeStringsComponent {
	var stringValue: String { get }
}

class XcodeStringsFile: Streamable {
	let filepath: String
	let components: [XcodeStringsComponent]
	
	class WhiteSpace: XcodeStringsComponent {
		let content: String
		
		var stringValue: String {return content}
		
		init(_ c: String) {
			assert(c.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) == nil, "Invalid white space string")
			content = c
		}
	}
	
	class Comment: XcodeStringsComponent {
		let content: String
		
		var stringValue: String {return "/*\(content)*/"}
		
		init(_ c: String) {
			assert(c.range(of: "*/") == nil, "Invalid comment string")
			content = c
		}
	}
	
	class LocalizedString: XcodeStringsComponent {
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
			assert(e.components(separatedBy: "=").count == 2, "Invalid equal sign")
			assert(e.components(separatedBy: "=")[0].rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) == nil, "Invalid equal sign")
			assert(e.components(separatedBy: "=")[1].rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.inverted) == nil, "Invalid equal sign")
			key = k
			equal = e
			value = v
			semicolon = s
			keyHasQuotes = qfk
		}
	}
	
	/* If included_paths is nil (default), no inclusion check will be done. */
	class func stringsFilesInProject(_ root_folder: String, excluded_paths: [String], included_paths: [String]? = nil) throws -> [XcodeStringsFile] {
		guard let e = FileManager.default.enumerator(atPath: root_folder) else {
			throw NSError(domain: "XcodeStringsFileErrDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot list files at path \(root_folder)."])
		}
		
		var parsed_strings_files = [XcodeStringsFile]()
		fileLoop: while let cur_file = e.nextObject() as? String {
			guard cur_file.hasSuffix(".strings") else {
				continue
			}
			
			if let included_paths = included_paths {
				var found = false
				for included in included_paths {
					if cur_file.range(of: included) != nil {
						found = true
						break
					}
				}
				if !found {continue fileLoop}
			}
			
			for excluded in excluded_paths {
				guard cur_file.range(of: excluded) == nil else {
					continue fileLoop
				}
			}
			
			/* We have a non-excluded strings file. Let's parse it. */
			do {
				let xcodeStringsFile = try XcodeStringsFile(fromPath: cur_file, relativeToProjectPath: root_folder)
				parsed_strings_files.append(xcodeStringsFile)
			} catch let error as NSError {
				print("*** Warning: Got error while parsing strings file (skipping) \(cur_file): \(error)", to: &mx_stderr)
			}
		}
		return parsed_strings_files
	}
	
	convenience init(fromPath path: String, relativeToProjectPath projectPath: String) throws {
		var encoding: UInt = 0
		let filecontent = try NSString(contentsOfFile: (projectPath as NSString).appendingPathComponent(path), usedEncoding: &encoding)
		try self.init(filepath: path, filecontent: filecontent as String)
	}
	
	convenience init(filepath path: String, filecontent: String) throws {
		/* Let's parse the stream */
		var components = [XcodeStringsComponent]()
		var idling = true
		var currentKey = String()
		var currentValue = String()
		var currentWhite = String()
		var currentEqual = String()
		var currentComment = String()
		var currentSemicolon = String()
		var currentKeyHasQuote = true
		
		var engine: ((Character) -> Bool)!
		
		/* Confirm End Comment */
		func confirm_end_comment(_ c: Character) -> Bool {
			if c == "/" {
				components.append(Comment(currentComment))
				idling = true
				engine = treat_idle_char
			} else {
				currentComment.append("*" as Character)
				if c != "*" {
					currentComment.append(c)
					engine = wait_end_comment
				}
			}
			
			return true
		}
		
		/* Confirm End Comment */
		func wait_end_comment(_ c: Character) -> Bool {
			if c != "*" {
				currentComment.append(c)
				return true
			}
			engine = confirm_end_comment
			return true
		}
		
		func confirm_comment_start(_ c: Character) -> Bool {
			if c != "*" {return false}
			
			currentComment = String()
			engine = wait_end_comment
			return true
		}
		
		func treat_semicolon_char(_ c: Character) -> Bool {
			if c == "\n" || c == "\t" || c == " " {
				currentSemicolon.append(c)
				return true
			}
			if c == ";" {
				currentSemicolon.append(c)
				components.append(LocalizedString(key: currentKey, keyHasQuotes: currentKeyHasQuote, equalSign: currentEqual, value: currentValue, andSemicolon: currentSemicolon))
				idling = true
				engine = treat_idle_char
				return true
			}
			return false
		}
		
		func treat_value_escaped_char(_ c: Character) -> Bool {
			currentValue.append("\\" as Character)
			currentValue.append(c)
			engine = treat_value_char
			return true
		}
		
		func treat_value_char(_ c: Character) -> Bool {
			if      c == "\\" {engine = treat_value_escaped_char}
			else if c != "\"" {currentValue.append(c)}
			else              {engine = treat_semicolon_char}
			return true
		}
		
		func treat_after_equal_between_char(_ c: Character) -> Bool {
			if c == "\"" {
				engine = treat_value_char
				return true
			}
			if c == "\n" || c == "\t" || c == " " {
				currentEqual.append(c)
				return true
			}
			return false
		}
		
		func treat_before_equal_between_char(_ c: Character) -> Bool {
			if c == "=" {
				engine = treat_after_equal_between_char
				currentEqual.append(c)
				return true
			}
			if c == "\n" || c == "\t" || c == " " {
				currentEqual.append(c)
				return true
			}
			return false
		}
		
		func treat_key_escaped_char(_ c: Character) -> Bool {
			currentKey.append("\\" as Character)
			currentKey.append(c)
			engine = treat_key_char
			return true
		}
		
		func treat_key_char(_ c: Character) -> Bool {
			if      c == "\\" {engine = treat_key_escaped_char}
			else if c == "\"" {engine = treat_before_equal_between_char}
			else              {currentKey.append(c)}
			return true
		}
		
		func treat_key_char_no_double_quotes(_ c: Character) -> Bool {
			if (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") {
				currentKey.append(c)
				return true
			}
			if c == "\n" || c == "\t" || c == " " {
				currentEqual.append(c)
				engine = treat_before_equal_between_char
				return true
			}
			
			return false
		}
		
		func treat_idle_char(_ c: Character) -> Bool {
			if c == "\n" || c == "\t" || c == " " {
				currentWhite.append(c)
				return true
			} else if c == "/" {
				components.append(WhiteSpace(currentWhite))
				currentWhite = String()
				idling = false
				engine = confirm_comment_start
				return true
			} else if c == "\"" {
				components.append(WhiteSpace(currentWhite))
				currentWhite = String()
				currentKeyHasQuote = true
				currentKey = String(); currentEqual = String(); currentValue = String(); currentSemicolon = String()
				idling = false
				engine = treat_key_char
				return true
			} else if (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") {
				components.append(WhiteSpace(currentWhite))
				currentWhite = String()
				currentKeyHasQuote = false
				currentKey = String(c); currentEqual = String(); currentValue = String(); currentSemicolon = String()
				idling = false
				engine = treat_key_char_no_double_quotes
				return true
			}
			
			return false
		}
		
		engine = treat_idle_char
		for c in filecontent.characters {
			guard engine(c) else {
				throw NSError(domain: "XcodeStringsFileErrDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Cannot parse file (syntax error)"])
			}
		}
		
		guard idling else {
			throw NSError(domain: "XcodeStringsFileErrDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Cannot parse file (early EOF)"])
		}
		
		if !currentWhite.isEmpty {components.append(WhiteSpace(currentWhite))}
		self.init(filepath: path, components: components)
	}
	
	init(filepath: String, components: [XcodeStringsComponent]) {
		self.filepath   = filepath
		self.components = components
	}
	
	func write<Target : OutputStream>(to target: inout Target) {
		for component in components {
			component.stringValue.write(to: &target)
		}
		"\n".write(to: &target)
	}
}

/*
 * XcodeStringsFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation
import os.log


/* strings files are, in essence, old-style plist files.
 * FYI: https://pewpewthespells.com/blog/dangers_of_ascii_plists.html
 *      -> Xcode reads those old-style plists as Unicode, but original parser
 *         read them as ASCII, with support for Unicode with \Uxxxx, but not
 *         more than four numbers were read after the “U”.
 *         https://opensource.apple.com/source/CF/CF-1153.18/CFOldStylePList.c
 *         PropertyListSerialization does serialize as Unicode though.
 * From the CFOldStylePList.c file, we get:
 *    #define isValidUnquotedStringCharacter(x) (((x) >= 'a' && (x) <= 'z') || ((x) >= 'A' && (x) <= 'Z') || ((x) >= '0' && (x) <= '9') || (x) == '_' || (x) == '$' || (x) == '/' || (x) == ':' || (x) == '.' || (x) == '-')
 * _ = try? PropertyListSerialization.propertyList(from: Data("{\"hello\"=/w_o$r:l.d ;}".utf8), options: [], format: nil)
 *    -> ["hello": "/w_o$r:l.d"]
 * _ = try? PropertyListSerialization.propertyList(from: Data("{\"hello\"=\"/w_o$r:l.d🙃\";}".utf8), options: [], format: nil)
 *    -> ["hello": "/w_o$r:l.d🙃"]
 */


protocol XcodeStringsComponent {
	
	var stringValue: String { get }
	
}

class XcodeStringsFile: TextOutputStreamable {
	
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
		let isDoubleSlashStyle: Bool
		
		var stringValue: String {return (isDoubleSlashStyle ? "//" : "/*") + content + (isDoubleSlashStyle ? "\n" : "*/")}
		
		init(_ c: String, doubleSlashed: Bool) {
			assert(c.range(of: "\n") == nil || !doubleSlashed, "Invalid comment string")
			assert(c.range(of: "*/") == nil ||  doubleSlashed, "Invalid comment string")
			isDoubleSlashStyle = doubleSlashed
			content = c
		}
	}
	
	class LocalizedString: XcodeStringsComponent {
		let key: String
		let equal: String
		let value: String
		let semicolon: String
		let keyHasQuotes: Bool
		let valueHasQuotes: Bool
		
		var stringValue: String {
			return quotedString(key, forceQuotes: keyHasQuotes) + equal + quotedString(value, forceQuotes: valueHasQuotes) + semicolon
		}
		
		private func stringNeedsQuotes(_ string: String) -> Bool {
			return string.rangeOfCharacter(from: XcodeStringsFile.validUnquotedStringChars.inverted) != nil
		}
		
		private func quotedString(_ string: String, forceQuotes: Bool) -> String {
			let useQuotes = forceQuotes || stringNeedsQuotes(string)
			let quotes = (useQuotes ? "\"" : "")
			/* Note: Replacing new lines is not strictly speaking required... */
			return quotes + (!useQuotes ? string : string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\"", with: "\\\"")) + quotes
		}
		
		init(key k: String, keyHasQuotes qfk: Bool, equalSign e: String, value v: String, valueHasQuotes qfv: Bool, semicolon s: String) {
			key = k
			equal = e
			value = v
			semicolon = s
			keyHasQuotes = qfk
			valueHasQuotes = qfv
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
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got error while parsing strings file (skipping) %@: %@", log: $0, type: .info, cur_file, String(describing: error)) }}
				else                        {NSLog("Got error while parsing strings file (skipping) %@: %@", cur_file, String(describing: error))}
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
		var startIdx = filecontent.startIndex
		while true {
			guard let (preKey, fullKey) = XcodeStringsFile.parseString(source: filecontent, startIdx: &startIdx, separatorToken: "=") else {
				throw NSError(domain: "XcodeStringsFileErrDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Cannot parse file (syntax error, cannot parse key)"])
			}
			guard let (key, keyHasQuotes, postKey) = fullKey else {
				components.append(contentsOf: preKey)
				break
			}
			guard let (preValue, fullValue) = XcodeStringsFile.parseString(source: filecontent, startIdx: &startIdx, separatorToken: ";") else {
				throw NSError(domain: "XcodeStringsFileErrDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Cannot parse file (syntax error, cannot parse value)"])
			}
			guard let (value, valueHasQuotes, postValue) = fullValue else {
				throw NSError(domain: "XcodeStringsFileErrDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Cannot parse file (syntax error, value not found)"])
			}
			let localizedString = LocalizedString(
				key: key, keyHasQuotes: keyHasQuotes,
				equalSign: postKey.reduce("", { $0 + $1.stringValue }) + "=" + preValue.reduce("", { $0 + $1.stringValue }),
				value: value, valueHasQuotes: valueHasQuotes,
				semicolon: postValue.reduce("", { $0 + $1.stringValue }) + "=")
			components.append(contentsOf: preKey)
			components.append(localizedString)
		}
		self.init(filepath: path, components: components)
	}
	
	init(filepath: String, components: [XcodeStringsComponent]) {
		self.filepath   = filepath
		self.components = components
	}
	
	func write<Target : TextOutputStream>(to target: inout Target) {
		for component in components {
			component.stringValue.write(to: &target)
		}
		"\n".write(to: &target)
	}
	
	private static let validUnquotedStringChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$/:.-")
	private static func isValidUnquotedStringChar(_ c: Character) -> Bool {
		return c.unicodeScalars.count == 1 && XcodeStringsFile.validUnquotedStringChars.contains(c.unicodeScalars.first!)
	}
	
	private static let whiteChars = CharacterSet.whitespacesAndNewlines
	private static func isWhiteChar(_ c: Character) -> Bool {
		return c.unicodeScalars.count == 1 && XcodeStringsFile.whiteChars.contains(c.unicodeScalars.first!)
	}
	
}

/* ******************************* State Engine ******************************* */
/*	wait_string_start -> wait_string_start [label=" \"white\" "];
	wait_string_start -> confirm_prestring_comment_start [label=" / "];
	wait_string_start -> wait_end_string_no_double_quotes [label=" \"alphanum\" "];
	wait_string_start -> wait_end_string [label=" \" "];
	wait_string_start -> ERROR;
	confirm_prestring_comment_start -> wait_end_prestring_star_comment [label=" * "];
	confirm_prestring_comment_start -> wait_end_prestring_slash_comment [label=" / "];
	confirm_prestring_comment_start -> wait_end_string_no_double_quotes [label=" \"alphanum\" "];
	confirm_prestring_comment_start -> SUCCESS [label=" \"separatorToken\" "];
	confirm_prestring_comment_start -> ERROR;
	wait_end_prestring_star_comment -> confirm_end_prestring_star_comment [label=" * "];
	wait_end_prestring_star_comment -> wait_end_prestring_star_comment;
	confirm_end_prestring_star_comment -> wait_string_start [label=" / "];
	confirm_end_prestring_star_comment -> wait_end_prestring_star_comment;
	wait_end_prestring_slash_comment -> wait_string_start [label=" \\n "];
	wait_end_prestring_slash_comment -> wait_end_prestring_slash_comment;

	wait_end_string_no_double_quotes -> wait_end_string_no_double_quotes [label=" \"alphanum\" "];
	wait_end_string_no_double_quotes -> wait_separator_token [label=" \"white\" "];
	wait_end_string_no_double_quotes -> ERROR;
	wait_end_string -> treat_string_escaped_char [label=" \\ "];
	wait_end_string -> wait_separator_token [label=" \" "];
	wait_end_string -> wait_end_string;
	treat_string_escaped_char -> wait_end_string;

	wait_separator_token -> confirm_poststring_comment_start [label = " / "];
	wait_separator_token -> wait_separator_token [label = " \"white\" "];
	wait_separator_token -> SUCCESS [label = " \"separatorToken\" "];
	wait_separator_token -> ERROR;
	confirm_poststring_comment_start -> wait_end_poststring_star_comment [label=" * "];
	confirm_poststring_comment_start -> wait_end_poststring_slash_comment [label=" / "];
	confirm_poststring_comment_start -> ERROR;
	wait_end_poststring_star_comment -> confirm_end_poststring_star_comment [label=" * "];
	wait_end_poststring_star_comment -> wait_end_poststring_star_comment;
	confirm_end_poststring_star_comment -> wait_separator_token [label = " / "];
	confirm_end_poststring_star_comment -> wait_end_poststring_star_comment;
	wait_end_poststring_slash_comment -> wait_separator_token [label=" \\n "];
	wait_end_poststring_slash_comment -> wait_end_poststring_slash_comment; */
/* ******************************* State Engine ******************************* */

extension XcodeStringsFile {
	
	private static func parseString(source: String, startIdx: inout String.Index, separatorToken: Character) -> (preString: [XcodeStringsComponent], (string: String, hadQuotes: Bool, postString: [XcodeStringsComponent])?)? {
		assert(!"/*\"".contains(separatorToken))
		var engine: ((Character) -> Bool)?
		
		/* Engine state */
		var earlyEOF = false
		var hasQuote = false
		var currentString = ""
		
		var string: String?
		var preString = [XcodeStringsComponent]()
		var postString = [XcodeStringsComponent]()
		
		func wait_string_start(_ c: Character) -> Bool {
			if isWhiteChar(c) {
				currentString.append(c)
				return true
			}
			if c == "/" {
				if !currentString.isEmpty {preString.append(WhiteSpace(currentString))}
				currentString = ""
				engine = confirm_prestring_comment_start
				return true
			}
			if c == "\"" {
				if !currentString.isEmpty {preString.append(WhiteSpace(currentString))}
				currentString = ""
				hasQuote = true
				engine = wait_end_string
				return true
			}
			if isValidUnquotedStringChar(c) {
				if !currentString.isEmpty {preString.append(WhiteSpace(currentString))}
				currentString = String(c)
				engine = wait_end_string_no_double_quotes
				return true
			}
			return false
		}
		
		func confirm_prestring_comment_start(_ c: Character) -> Bool {
			if c == separatorToken {
				string = "/"
				engine = nil
				return true
			}
			if c == "*" {
				engine = wait_end_prestring_star_comment
				return true
			}
			if c == "/" {
				engine = wait_end_prestring_slash_comment
				return true
			}
			if isValidUnquotedStringChar("/") && isValidUnquotedStringChar(c) {
				currentString = "/" + String(c)
				engine = wait_end_string_no_double_quotes
				return true
			}
			return false
		}
		
		func wait_end_prestring_star_comment(_ c: Character) -> Bool {
			if c == "*" {
				engine = confirm_end_prestring_star_comment
				return true
			}
			currentString.append(c)
			return true
		}
		
		func confirm_end_prestring_star_comment(_ c: Character) -> Bool {
			if c == "/" {
				preString.append(Comment(currentString, doubleSlashed: false))
				currentString = ""
				engine = wait_string_start
				return true
			}
			engine = wait_end_prestring_star_comment
			currentString += "*"
			currentString.append(c)
			return true
		}
		
		func wait_end_prestring_slash_comment(_ c: Character) -> Bool {
			if c == "\n" {
				preString.append(Comment(currentString, doubleSlashed: true))
				currentString = ""
				engine = wait_string_start
				return true
			}
			currentString.append(c)
			return true
		}
		
		func wait_end_string_no_double_quotes(_ c: Character) -> Bool {
			if isValidUnquotedStringChar(c) {
				currentString.append(c)
				return true
			}
			if isWhiteChar(c) {
				string = currentString
				currentString = String(c)
				engine = wait_separator_token
				return true
			}
			return false
		}
		
		func wait_end_string(_ c: Character) -> Bool {
			if c == "\\" {
				currentString.append(c)
				engine = treat_string_escaped_char
				return true
			}
			if c == "\"" {
				string = currentString
				currentString = ""
				engine = wait_separator_token
				return true
			}
			currentString.append(c)
			return true
		}
		
		func treat_string_escaped_char(_ c: Character) -> Bool {
			currentString.append(c)
			engine = wait_end_string
			return true
		}
		
		func wait_separator_token(_ c: Character) -> Bool {
			if c == separatorToken {
				if !currentString.isEmpty {preString.append(WhiteSpace(currentString))}
				currentString = ""
				engine = nil
				return true
			}
			if c == "/" {
				if !currentString.isEmpty {preString.append(WhiteSpace(currentString))}
				currentString = ""
				engine = confirm_poststring_comment_start
				return true
			}
			if isWhiteChar(c) {
				currentString.append(c)
				return true
			}
			return false
		}
		
		func confirm_poststring_comment_start(_ c: Character) -> Bool {
			if c == "*" {
				engine = wait_end_poststring_star_comment
				return true
			}
			if c == "/" {
				engine = wait_end_poststring_slash_comment
				return true
			}
			return false
		}
		
		func wait_end_poststring_star_comment(_ c: Character) -> Bool {
			if c == "*" {
				engine = confirm_end_poststring_star_comment
				return true
			}
			currentString.append(c)
			return true
		}
		
		func confirm_end_poststring_star_comment(_ c: Character) -> Bool {
			if c == "/" {
				preString.append(Comment(currentString, doubleSlashed: false))
				currentString = ""
				engine = wait_separator_token
				return true
			}
			currentString += "*"
			currentString.append(c)
			engine = wait_end_poststring_star_comment
			return true
		}
		
		func wait_end_poststring_slash_comment(_ c: Character) -> Bool {
			if c == "\n" {
				preString.append(Comment(currentString, doubleSlashed: true))
				currentString = ""
				engine = wait_separator_token
				return true
			}
			currentString.append(c)
			return true
		}
		
		engine = wait_string_start
		for c in source[startIdx...] {
			startIdx = source.index(after: startIdx)
			guard let engine = engine else {break}
			guard engine(c) else {return nil}
		}
		
		guard !earlyEOF else {return nil}
		
		if let string = string {
			let quote = hasQuote ? "\"" : ""
			guard let parsedString = (try? PropertyListSerialization.propertyList(from: Data((quote + string + quote).utf8), options: [], format: nil)) as? String else {
				return nil
			}
			return (preString: preString, (string: parsedString, hadQuotes: hasQuote, postString: postString))
		} else {
			return (preString: preString, nil)
		}
	}
	
}

/*
 * XcodeStringsFile.swift
 * LocMapper
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

import Logging


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

public class XcodeStringsFile: TextOutputStreamable {
	
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
	
	/* If includedPaths is nil (default), no inclusion check will be done. */
	public static func stringsFilesInProject(_ rootFolder: String, excludedPaths: [String], includedPaths: [String]? = nil) throws -> [XcodeStringsFile] {
		guard let dirEnumerator = FilteredDirectoryEnumerator(path: rootFolder, includedPaths: includedPaths, excludedPaths: excludedPaths, pathSuffixes: [".swift"], fileManager: .default) else {
			throw NSError(domain: "XcodeStringsFileErrDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot list files at path \(rootFolder)."])
		}
		
		var parsedStringsFiles = [XcodeStringsFile]()
		for curFileURL in dirEnumerator {
			let curFile = curFileURL.path
			do {
				let xcodeStringsFile = try XcodeStringsFile(fromPath: curFile, relativeToProjectPath: rootFolder)
				parsedStringsFiles.append(xcodeStringsFile)
			} catch let error as NSError {
				#if canImport(os)
					LocMapperConfig.oslog.flatMap{ os_log("Got error while parsing strings file (skipping) %@: %@", log: $0, type: .info, curFile, String(describing: error)) }
				#endif
				LocMapperConfig.logger?.warning("Got error while parsing strings file (skipping) \(curFile): \(String(describing: error))")
			}
		}
		return parsedStringsFiles
	}
	
	public convenience init(fromPath path: String, relativeToProjectPath projectPath: String) throws {
		var encoding: UInt = 0
		let filecontent = try NSString(contentsOfFile: (projectPath as NSString).appendingPathComponent(path), usedEncoding: &encoding)
		try self.init(filepath: path, filecontent: filecontent as String)
	}
	
	/**
	Merges the new strings file in the original.
	
	Any new key not present in the original is added at the end of the original
	with their comments and whitespaces.
	
	All keys that were present in the original are left unmodified (the value are
	not changed either!).
	
	If a key is present in the original but not in the new file, behavior will
	depend on the `obsoleteKeys` parameter. If the parameter is `nil`, the keys
	and their comments/whitespaces will be removed from the original. If the
	parameter is non-nil, the key will be left in the original and added to the
	`obsoleteKeys` parameter.
	
	If the new file has a key not present in the original, and duplicated, it
	will be added only once in the resulting file. Which comment will be chosen
	is undefined.
	
	If the original file has duplicated keys, they won’t be de-duplicated.
	
	If the original file has a duplicated key that is not in the new file, only
	one key will be removed. Which one is undefined. */
	public convenience init(merging new: XcodeStringsFile, in original: XcodeStringsFile?, obsoleteKeys: inout [String]?, filepath: String) {
		let newKeys = Set(new.components.compactMap{ ($0 as? LocalizedString)?.key })
		let originalKeys = Set((original?.components ?? []).compactMap{ ($0 as? LocalizedString)?.key })
		
		func fullKeyRange(for key: String, in components: [XcodeStringsComponent]) -> ClosedRange<Array<XcodeStringsComponent>.Index>? {
			guard let keyIdx = components.firstIndex(where: { ($0 as? LocalizedString)?.key == key }) else {
				return nil
			}
			var commentStartIdx = keyIdx
			while commentStartIdx != components.startIndex && !(components[components.index(before: commentStartIdx)] is LocalizedString) {
				commentStartIdx = components.index(before: commentStartIdx)
			}
			return commentStartIdx...keyIdx
		}
		
		var components = original?.components ?? []
		for keyToRemove in originalKeys.subtracting(newKeys) {
			if obsoleteKeys != nil {obsoleteKeys?.append(keyToRemove)}
			else                   {components.removeSubrange(fullKeyRange(for: keyToRemove, in: components)!)} /* See next comment for force unwrap justification. */
		}
		/* Note: We search again for the key in the new file components. We
		  *       probably could save the index info when building newKeys, but
		  *       I wasn’t able to do it one shot when writing this code, and I
		  *       got bored, so we search again…
		  *       We can force unwrap because we know the key exists. */
		let rangesToAdd = newKeys.subtracting(originalKeys).map{ keyToAdd in fullKeyRange(for: keyToAdd, in: new.components)! }
		for rangeToAdd in rangesToAdd.sorted(by: { $0.lowerBound < $1.lowerBound }) {
			components.append(contentsOf: new.components[rangeToAdd])
		}
		
		self.init(filepath: filepath, components: components)
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
				semicolon: postValue.reduce("", { $0 + $1.stringValue }) + ";")
			components.append(contentsOf: preKey)
			components.append(localizedString)
		}
		self.init(filepath: path, components: components)
	}
	
	init(filepath: String, components: [XcodeStringsComponent]) {
		self.filepath   = filepath
		self.components = components
	}
	
	public func write<Target : TextOutputStream>(to target: inout Target) {
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
	confirm_prestring_comment_start -> wait_separator_token [label=" \"white\" "];
	confirm_prestring_comment_start -> SUCCESS [label=" \"separatorToken\" "];
	confirm_prestring_comment_start -> ERROR;
	wait_end_prestring_star_comment -> confirm_end_prestring_star_comment [label=" * "];
	wait_end_prestring_star_comment -> wait_end_prestring_star_comment;
	confirm_end_prestring_star_comment -> confirm_end_prestring_star_comment [label=" * "];
	confirm_end_prestring_star_comment -> wait_string_start [label=" / "];
	confirm_end_prestring_star_comment -> wait_end_prestring_star_comment;
	wait_end_prestring_slash_comment -> wait_string_start [label=" \\n "];
	wait_end_prestring_slash_comment -> wait_end_prestring_slash_comment;

	wait_end_string_no_double_quotes -> wait_end_string_no_double_quotes [label=" \"alphanum\" "];
	wait_end_string_no_double_quotes -> SUCCESS [label=" \"separatorToken\" "];
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
	confirm_end_poststring_star_comment -> confirm_end_poststring_star_comment [label = " * "];
	confirm_end_poststring_star_comment -> wait_separator_token [label = " / "];
	confirm_end_poststring_star_comment -> wait_end_poststring_star_comment;
	wait_end_poststring_slash_comment -> wait_separator_token [label=" \\n "];
	wait_end_poststring_slash_comment -> wait_end_poststring_slash_comment; */
/* ******************************* State Engine ******************************* */

extension XcodeStringsFile {
	
	private enum EOFHandling {
		case nop
		case earlyEOF
		case addWhite
		case addDoubleSlashedComment
	}
	
	private static func parseString(source: String, startIdx: inout String.Index, separatorToken: Character) -> (preString: [XcodeStringsComponent], (string: String, hadQuotes: Bool, postString: [XcodeStringsComponent])?)? {
		assert(!"/*\"".contains(separatorToken))
		/* Engine state */
		var hasQuote = false
		var currentString = ""
		var engine: ((Character) -> Bool)?
		var eofHandling = EOFHandling.addWhite
		
		/* Results */
		var string: String?
		var preString = [XcodeStringsComponent]()
		var postString = [XcodeStringsComponent]()
		
		func wait_string_start(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("wait_string_start: %@", log: $0, type: .debug, String(c)) }
			if isWhiteChar(c) {
				currentString.append(c)
				return true
			}
			if c == "/" {
				if !currentString.isEmpty {preString.append(WhiteSpace(currentString))}
				currentString = ""
				eofHandling = .earlyEOF
				engine = confirm_prestring_comment_start
				return true
			}
			if c == "\"" {
				if !currentString.isEmpty {preString.append(WhiteSpace(currentString))}
				currentString = ""
				hasQuote = true
				eofHandling = .earlyEOF
				engine = wait_end_string
				return true
			}
			if isValidUnquotedStringChar(c) {
				if !currentString.isEmpty {preString.append(WhiteSpace(currentString))}
				currentString = String(c)
				eofHandling = .earlyEOF
				engine = wait_end_string_no_double_quotes
				return true
			}
			return false
		}
		
		func confirm_prestring_comment_start(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("confirm_prestring_comment_start: %@", log: $0, type: .debug, String(c)) }
			if c == separatorToken {
				string = "/"
				currentString = ""
				eofHandling = .nop
				engine = nil
				return true
			}
			if c == "*" {
				eofHandling = .earlyEOF
				engine = wait_end_prestring_star_comment
				return true
			}
			if c == "/" {
				eofHandling = .addDoubleSlashedComment
				engine = wait_end_prestring_slash_comment
				return true
			}
			if isWhiteChar(c) {
				string = "/"
				currentString = String(c)
				eofHandling = .earlyEOF
				engine = wait_separator_token
				return true
			}
			if isValidUnquotedStringChar("/") && isValidUnquotedStringChar(c) {
				currentString = "/" + String(c)
				eofHandling = .earlyEOF
				engine = wait_end_string_no_double_quotes
				return true
			}
			return false
		}
		
		func wait_end_prestring_star_comment(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("wait_end_prestring_star_comment: %@", log: $0, type: .debug, String(c)) }
			if c == "*" {
				eofHandling = .earlyEOF
				engine = confirm_end_prestring_star_comment
				return true
			}
			currentString.append(c)
			return true
		}
		
		func confirm_end_prestring_star_comment(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("confirm_end_prestring_star_comment: %@", log: $0, type: .debug, String(c)) }
			if c == "/" {
				preString.append(Comment(currentString, doubleSlashed: false))
				currentString = ""
				eofHandling = .addWhite
				engine = wait_string_start
				return true
			}
			currentString += "*"
			if c == "*" {
				return true
			}
			currentString.append(c)
			eofHandling = .earlyEOF
			engine = wait_end_prestring_star_comment
			return true
		}
		
		func wait_end_prestring_slash_comment(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("wait_end_prestring_slash_comment: %@", log: $0, type: .debug, String(c)) }
			if c == "\n" {
				preString.append(Comment(currentString, doubleSlashed: true))
				currentString = ""
				eofHandling = .addWhite
				engine = wait_string_start
				return true
			}
			currentString.append(c)
			return true
		}
		
		func wait_end_string_no_double_quotes(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("wait_end_string_no_double_quotes: %@", log: $0, type: .debug, String(c)) }
			if isValidUnquotedStringChar(c) {
				currentString.append(c)
				return true
			}
			if c == separatorToken {
				string = currentString
				currentString = ""
				eofHandling = .nop
				engine = nil
				return true
			}
			if isWhiteChar(c) {
				string = currentString
				currentString = String(c)
				eofHandling = .earlyEOF
				engine = wait_separator_token
				return true
			}
			return false
		}
		
		func wait_end_string(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("wait_end_string: %@", log: $0, type: .debug, String(c)) }
			if c == "\\" {
				currentString.append(c)
				eofHandling = .earlyEOF
				engine = treat_string_escaped_char
				return true
			}
			if c == "\"" {
				string = currentString
				currentString = ""
				eofHandling = .earlyEOF
				engine = wait_separator_token
				return true
			}
			currentString.append(c)
			return true
		}
		
		func treat_string_escaped_char(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("treat_string_escaped_char: %@", log: $0, type: .debug, String(c)) }
			currentString.append(c)
			eofHandling = .earlyEOF
			engine = wait_end_string
			return true
		}
		
		func wait_separator_token(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("wait_separator_token: %@", log: $0, type: .debug, String(c)) }
			if c == separatorToken {
				if !currentString.isEmpty {postString.append(WhiteSpace(currentString))}
				currentString = ""
				eofHandling = .nop
				engine = nil
				return true
			}
			if c == "/" {
				if !currentString.isEmpty {postString.append(WhiteSpace(currentString))}
				currentString = ""
				eofHandling = .earlyEOF
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
//			LocMapperConfig.oslog.flatMap{ os_log("confirm_poststring_comment_start: %@", log: $0, type: .debug, String(c)) }
			if c == "*" {
				eofHandling = .earlyEOF
				engine = wait_end_poststring_star_comment
				return true
			}
			if c == "/" {
				eofHandling = .earlyEOF
				engine = wait_end_poststring_slash_comment
				return true
			}
			return false
		}
		
		func wait_end_poststring_star_comment(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("wait_end_poststring_star_comment: %@", log: $0, type: .debug, String(c)) }
			if c == "*" {
				eofHandling = .earlyEOF
				engine = confirm_end_poststring_star_comment
				return true
			}
			currentString.append(c)
			return true
		}
		
		func confirm_end_poststring_star_comment(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("confirm_end_poststring_star_comment: %@", log: $0, type: .debug, String(c)) }
			if c == "/" {
				postString.append(Comment(currentString, doubleSlashed: false))
				currentString = ""
				eofHandling = .earlyEOF
				engine = wait_separator_token
				return true
			}
			currentString += "*"
			if c == "*" {
				return true
			}
			currentString.append(c)
			eofHandling = .earlyEOF
			engine = wait_end_poststring_star_comment
			return true
		}
		
		func wait_end_poststring_slash_comment(_ c: Character) -> Bool {
//			LocMapperConfig.oslog.flatMap{ os_log("wait_end_poststring_slash_comment: %@", log: $0, type: .debug, String(c)) }
			if c == "\n" {
				postString.append(Comment(currentString, doubleSlashed: true))
				currentString = ""
				eofHandling = .earlyEOF
				engine = wait_separator_token
				return true
			}
			currentString.append(c)
			return true
		}
		
		var isEOF = true
		engine = wait_string_start
		for c in source[startIdx...] {
			guard let engine = engine else {isEOF = false; break}
			
			startIdx = source.index(after: startIdx)
			guard engine(c) else {return nil}
		}
		
		if isEOF {
			switch eofHandling {
			case .nop:                     (/*nop*/)
			case .earlyEOF:                return nil
			case .addWhite:                if !currentString.isEmpty {assert(string == nil); preString.append(WhiteSpace(currentString))}
			case .addDoubleSlashedComment:                            assert(string == nil); preString.append(Comment(currentString, doubleSlashed: true))
			}
		}
		
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

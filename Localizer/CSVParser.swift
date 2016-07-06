/*
 * CSVParser.swift
 * Localizer
 *
 * Created by François Lamboley on 12/12/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

/* Credits to Matt Gallagher from which this class comes from
 * http://projectswithlove.com/projects/CSVImporter.zip
 * http://www.cocoawithlove.com/2009/11/writing-parser-using-nsscanner-csv.html */

import Foundation



class CSVParser {
	private(set) var fieldNames: [String]
	
	private let hasHeader: Bool
	private let csvString: String
	
	private let separator: String
	private let separatorIsSingleChar: Bool
	private let endTextCharacterSet: CharacterSet
	
	private var scanner: Scanner!
	
	/* fieldNames is ignored if hasHeader is true */
	init(source str: String, separator sep: String, hasHeader header: Bool, fieldNames names: [String]?) {
		csvString = str
		separator = sep
		
		/* Note: Should be CharacterSet.newlines, but crash when doing that. */
		var cs = NSCharacterSet.newlines
		cs.insert(charactersIn: "\"")
		cs.insert(charactersIn: separator.substring(to: separator.index(after: separator.startIndex)))
		endTextCharacterSet = cs as CharacterSet
		
		separatorIsSingleChar = (separator.characters.count == 1)
		
		hasHeader = header
		if names != nil {fieldNames = names!}
		else            {fieldNames = [String]()}
		
		assert(
			!separator.isEmpty && separator.range(of: "\"") == nil && separator.rangeOfCharacter(from: CharacterSet.newlines) == nil,
			"CSV separator string must not be empty and must not contain the double quote character or newline characters."
		)
	}
	
	func arrayOfParsedRows() -> [[String: String]]? {
		scanner = Scanner(string: csvString)
		scanner.charactersToBeSkipped = CharacterSet()
		return parseFile()
	}
	
	private func parseFile() -> [[String: String]]? {
		if hasHeader {
			if let fn = parseHeader() {
				fieldNames = fn
				if parseLineSeparator() == nil {
					return nil
				}
			} else {
				return nil
			}
		}
		
		var ok = false
		var records = [[String: String]]()
		while let record = parseRecord() {
			ok = true
			records.append(record)
			if parseLineSeparator() == nil {
				break
			}
		}
		
		return (ok ? records : nil)
	}
	
	private func parseHeader() -> [String]? {
		var ok = false
		var names = [String]()
		
		while let name = parseName() {
			ok = true
			names.append(name)
			if parseSeparator() == nil {
				break
			}
		}
		
		return (ok ? names : nil)
	}
	
	/* Attempts to parse a record from the current scan location. The record
	 * dictionary will use the _fieldNames as keys, or FIELD_X for each column
	 * X-1 if no fieldName exists for a given column.
	 *
	 * Returns the parsed record as a dictionary, or nil on failure. */
	private func parseRecord() -> [String: String]? {
		if scanner.isAtEnd {
			return nil
		}
		if let newlines = parseLineSeparator() {
			scanner.scanLocation -= newlines.characters.count /* ish... actually not 100% true because NSScanner uses UTF-16 view of the string, Swift uses actual character count. */
			return [:]
		}
		
		var fieldCount = 0
		var fieldNamesCount = fieldNames.count
		
		var ok = false
		var record = [String: String]()
		
		while let field = parseField() {
			ok = true
			var fieldName: String!
			if fieldNamesCount > fieldCount {
				fieldName = fieldNames[fieldCount]
			} else {
				fieldNamesCount += 1
				fieldName = NSString(format: "FIELD_%d", fieldNamesCount) as String
				fieldNames.append(fieldName)
			}
			record[fieldName] = field
			fieldCount += 1
			if parseSeparator() == nil {
				break
			}
		}
		
		return (ok ? record : nil)
	}
	
	private func parseName() -> String? {
		return parseField()
	}
	
	private func parseField() -> String? {
		if let escaped = parseQuoted() {
			return escaped
		}
		
		if let nonQuoted = parseNonQuoted() {
			return nonQuoted
		}
		
		/* Special case: if the current location is immediately
		 * followed by a separator, then the field is a valid, empty string. */
		let currentLocation = scanner.scanLocation
		if parseSeparator() != nil || parseLineSeparator() != nil || scanner.isAtEnd {
			scanner.scanLocation = currentLocation
			return ""
		}
		
		return nil
	}
	
	private func parseQuoted() -> String? {
		guard parseDoubleQuote() != nil else {
			return nil
		}
		
		var accumulatedData = String()
		while true {
			let fragment: String
			if      let s = parseTextData()        {fragment = s}
			else if let s = parseSeparator()       {fragment = s}
			else if let s = parseLineSeparator()   {fragment = s}
			else if let _ = parseTwoDoubleQuotes() {fragment = "\""}
			else                                   {break}
			accumulatedData += fragment
		}
		
		guard parseDoubleQuote() != nil else {
			return nil
		}
		
		return accumulatedData
	}
	
	private func parseNonQuoted() -> String? {
		return parseTextData()
	}
	
	private func parseDoubleQuote() -> String? {
		let dq = "\""
		if scanner.scanString(dq, into: nil) {
			return dq
		}
		return nil
	}
	
	private func parseSeparator() -> String? {
		if scanner.scanString(separator, into: nil) {
			return separator
		}
		return nil
	}
	
	private func parseLineSeparator() -> String? {
		var matchedNewlines: NSString?
		let scanLocation = scanner.scanLocation
		guard scanner.scanCharacters(from: CharacterSet.newlines, into: &matchedNewlines) else {
			return nil
		}
		
		/* newlines will contains all new lines from scanLocation. We only want
		 * one new line. */
		let newlines = matchedNewlines! as String
		if newlines.hasPrefix("\r\n") {scanner.scanLocation = scanLocation + 2; return "\r\n"}
		if newlines.hasPrefix("\n")   {scanner.scanLocation = scanLocation + 1; return "\n"}
		if newlines.hasPrefix("\r")   {scanner.scanLocation = scanLocation + 1; return "\r"}
		print("*** Warning: Unknown new line! oO (\(newlines))")
		return newlines
	}
	
	private func parseTwoDoubleQuotes() -> String? {
		let dq = "\"\""
		if scanner.scanString(dq, into: nil) {
			return dq
		}
		return nil
	}
	
	private func parseTextData() -> String? {
		var accumulatedData = String()
		
		while true {
			var fragment: NSString?
			if scanner.scanUpToCharacters(from: endTextCharacterSet, into: &fragment) {
				accumulatedData += fragment! as String
			}
			
			/* If the separator is just a single character (common case) then
			 * we know we've reached the end of parseable text */
			if separatorIsSingleChar {
				break
			}
			
			/* Otherwise, we need to consider the case where the first character
			 * of the separator is matched but we don't have the full separator. */
			let location = scanner.scanLocation
			var firstCharOfSeparator: NSString?
			if scanner.scanString(separator.substring(to: separator.characters.index(after: separator.startIndex)), into: &firstCharOfSeparator) {
				if scanner.scanString(separator.substring(from: separator.characters.index(after: separator.startIndex)), into: nil) {
					scanner.scanLocation = location
					break
				}
				
				/* We have the first char of the separator but not the whole
				 * separator, so just append the char and continue */
				accumulatedData += firstCharOfSeparator! as String
				continue
			} else {
				break
			}
		}
		
		if !accumulatedData.isEmpty {
			return accumulatedData
		}
		
		return nil
	}
}

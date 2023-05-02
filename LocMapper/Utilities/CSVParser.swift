/*
 * CSVParser.swift
 * LocMapper
 *
 * Created by François Lamboley on 12/12/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

/* Credits to Matt Gallagher from which this class comes from
 * http://projectswithlove.com/projects/CSVImporter.zip
 * http://www.cocoawithlove.com/2009/11/writing-parser-using-nsscanner-csv.html */

import Foundation
#if canImport(os)
import os.log
#endif

import Logging



class CSVParser {
	
	private(set) var fieldNames: [String]
	
	private let hasHeader: Bool
	private let csvString: String
	private let startOffset: Scanner.Location
	
	private let separator: String
	private let separatorIsSingleChar: Bool
	private let endTextCharacterSet: CharacterSet
	
	private var scanner: Scanner!
	
	/* fieldNames is ignored if hasHeader is true */
	init(source str: String, startOffset offset: String.Index, separator sep: String, hasHeader header: Bool, fieldNames names: [String]?) {
		assert(offset < str.endIndex)
		assert(
			!sep.isEmpty && sep.range(of: "\"") == nil && sep.rangeOfCharacter(from: CSVParser.newLinesCharacterSet) == nil && sep.unicodeScalars.count == 1,
			"CSV separator string must not be empty, must contain a single unicode scalar and must not contain the double quote character or newline characters."
		)
		
		csvString = str
		separator = sep
		startOffset = .init(index: offset, in: str)
		
		var cs = CSVParser.newLinesCharacterSet
		cs.insert(charactersIn: "\"")
		cs.insert(separator.unicodeScalars.first!)
		endTextCharacterSet = cs
		
		separatorIsSingleChar = (separator.count == 1)
		
		hasHeader = header
		if let names = names {fieldNames = names}
		else                 {fieldNames = [String]()}
	}
	
	func arrayOfParsedRows() -> [[String: String]]? {
		scanner = Scanner(string: csvString)
		scanner.charactersToBeSkipped = CharacterSet()
		scanner.lm_scanLocation = startOffset
		return parseFile()
	}
	
	private static var newLinesCharacterSet = CharacterSet(charactersIn: "\n\r")
	
	private func parseFile() -> [[String: String]]? {
		if hasHeader {
			guard let fn = parseHeader() else {
				return nil
			}
			fieldNames = fn
			
			guard parseLineSeparator() != nil else {
				return nil
			}
		}
		
		var ok = false
		var records = [[String: String]]()
		while let record = parseRecord() {
			ok = true
			records.append(record)
			guard parseLineSeparator() != nil else {
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
			guard parseSeparator() != nil else {
				break
			}
		}
		
		return (ok ? names : nil)
	}
	
	/**
	 Attempts to parse a record from the current scan location.
	 The record dictionary will use the `_fieldNames` as keys, or `FIELD_X` for each column `X-1` if no fieldName exists for a given column.
	 
	 - Returns: The parsed record as a dictionary, or nil on failure. */
	private func parseRecord() -> [String: String]? {
		if scanner.isAtEnd {
			return nil
		}
		if let newlines = parseLineSeparator() {
			scanner.lm_scanLocation = scanner.lm_scanLocation.offset(by: -newlines.count, in: scanner.string)
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
				fieldName = String(format: "FIELD_%d", fieldNamesCount)
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
		
		/* Special case: if the current location is immediately followed by a separator, then the field is a valid, empty string. */
		let currentLocation = scanner.lm_scanLocation
		if parseSeparator() != nil || parseLineSeparator() != nil || scanner.isAtEnd {
			scanner.lm_scanLocation = currentLocation
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
		if scanner.lm_scanString(dq) != nil {
			return dq
		}
		return nil
	}
	
	private func parseSeparator() -> String? {
		if scanner.lm_scanString(separator) != nil {
			return separator
		}
		return nil
	}
	
	private func parseLineSeparator() -> String? {
		let scanLocation = scanner.lm_scanLocation
		guard let matchedNewlines = scanner.lm_scanCharacters(from: CSVParser.newLinesCharacterSet) else {
			return nil
		}
		
		/* newlines will contains all new lines from scanLocation.
		 * We only want one new line. */
		let newlines = matchedNewlines
		if newlines.hasPrefix("\r\n") {scanner.lm_scanLocation = scanLocation.offset(by: 2, in: scanner.string); return "\r\n"}
		if newlines.hasPrefix("\n")   {scanner.lm_scanLocation = scanLocation.offset(by: 1, in: scanner.string); return "\n"}
		if newlines.hasPrefix("\r")   {scanner.lm_scanLocation = scanLocation.offset(by: 1, in: scanner.string); return "\r"}
#if canImport(os)
		Conf.oslog.flatMap{ os_log("Unknown new line! oO (%@)", log: $0, type: .error, newlines) }
#endif
		Conf.logger?.error("Unknown new line! oO (\(newlines))")
		return newlines
	}
	
	private func parseTwoDoubleQuotes() -> String? {
		let dq = "\"\""
		if scanner.lm_scanString(dq) != nil {
			return dq
		}
		return nil
	}
	
	private func parseTextData() -> String? {
		var accumulatedData = String()
		
		while true {
			if let fragment = scanner.lm_scanUpToCharacters(from: endTextCharacterSet) {
				accumulatedData += fragment
			}
			
			/* If the separator is just a single character (common case) then we know we've reached the end of parsable text. */
			if separatorIsSingleChar {
				break
			}
			
			/* Otherwise, we need to consider the case where the first character of the separator is matched but we don't have the full separator. */
			let location = scanner.lm_scanLocation
			if let firstCharOfSeparator = scanner.lm_scanString(String(separator.first!)) {
				if scanner.lm_scanString(String(separator.dropFirst())) != nil {
					scanner.lm_scanLocation = location
					break
				}
				
				/* We have the first char of the separator but not the whole separator, so just append the char and continue. */
				accumulatedData += firstCharOfSeparator
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

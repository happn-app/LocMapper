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
	private var _fieldNames: [String]
	var fieldNames: [String] {get {return _fieldNames}}
	
	private let hasHeader: Bool
	private let csvString: String
	
	private let separator: String
	private let separatorIsSingleChar: Bool
	private let endTextCharacterSet: NSCharacterSet
	
	private var scanner: NSScanner!
	
	/* fieldNames is ignored if hasHeader is true */
	init(source str: String, separator sep: String, hasHeader header: Bool, fieldNames names: [String]?) {
		csvString = str
		separator = sep
		
		let cs: NSMutableCharacterSet = NSCharacterSet.newlineCharacterSet().mutableCopy() as NSMutableCharacterSet
		cs.addCharactersInString("\"")
		cs.addCharactersInString(separator.substringToIndex(separator.startIndex.successor()))
		endTextCharacterSet = cs
		
		separatorIsSingleChar = (countElements(separator) == 1)
		
		hasHeader = header
		if names != nil {_fieldNames = names!}
		else            {_fieldNames = [String]()}
		
		assert(
			countElements(separator) > 0 &&
				separator.rangeOfString("\"") == nil &&
				separator.rangeOfCharacterFromSet(NSCharacterSet.newlineCharacterSet()) == nil,
			"CSV separator string must not be empty and must not contain the double quote character or newline characters.")
	}
	
	func arrayOfParsedRows() -> [[String: String]]? {
		scanner = NSScanner(string: csvString)
		scanner.charactersToBeSkipped = NSCharacterSet()
		return parseFile()
	}
	
/*	- (void)parseRowsForReceiver:(id)aReceiver selector:(SEL)aSelector
	{
		scanner = [[NSScanner alloc] initWithString:csvString];
		[scanner setCharactersToBeSkipped:[[[NSCharacterSet alloc] init] autorelease]];
		receiver = [aReceiver retain];
		receiverSelector = aSelector;
	
		[self parseFile];
	
		[scanner release];
		scanner = nil;
		[receiver release];
		receiver = nil;
	}*/
	
	private func parseFile() -> [[String: String]]? {
		if hasHeader {
			if let fn = parseHeader() {
				_fieldNames = fn
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
		/*
		 * Special case: return nil if the line is blank. Without this special case,
		 * it would parse as a single blank field.
		 */
		if parseLineSeparator() != nil || scanner.atEnd {
			return nil
		}
		
		var fieldCount = 0
		var fieldNamesCount = _fieldNames.count
		
		var ok = false
		var record = [String: String]()
		
		while let field = parseField() {
			ok = true
			var fieldName: String!
			if fieldNamesCount > fieldCount {
				fieldName = _fieldNames[fieldCount]
			} else {
				fieldName = NSString(format: "FIELD_%d", ++fieldNamesCount)
				_fieldNames.append(fieldName)
			}
			record[fieldName] = field
			++fieldCount
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
		if let escaped = parseEscaped() {
			return escaped
		}
		
		if let nonEscaped = parseNonEscaped() {
			return nonEscaped
		}
		
		/* Special case: if the current location is immediately
		 * followed by a separator, then the field is a valid, empty string. */
		let currentLocation = scanner.scanLocation
		if parseSeparator() != nil || parseLineSeparator() != nil || scanner.atEnd {
			scanner.scanLocation = currentLocation
			return ""
		}
		
		return nil;
	}
	
	private func parseEscaped() -> String? {
		if parseDoubleQuote() == nil {
			return nil
		}
		
		var accumulatedData = String()
		while true {
			var fragment = parseTextData()
			if fragment == nil {
				fragment = parseSeparator()
				if fragment == nil {
					fragment = parseLineSeparator()
					if fragment == nil {
						if parseTwoDoubleQuotes() != nil {
							fragment = "\""
						} else {
							break
						}
					}
				}
			}
			accumulatedData += fragment!
		}
		
		if parseDoubleQuote() == nil {
			return nil
		}
		
		return accumulatedData;
	}
	
	private func parseNonEscaped() -> String? {
		return parseTextData()
	}
	
	private func parseDoubleQuote() -> String? {
		let dq = "\""
		if scanner.scanString(dq, intoString: nil) {
			return dq
		}
		return nil
	}
	
	private func parseSeparator() -> String? {
		if scanner.scanString(separator, intoString: nil) {
			return separator
		}
		return nil;
	}
	
	private func parseLineSeparator() -> String? {
		var matchedNewlines: NSString?
		scanner.scanCharactersFromSet(NSCharacterSet.newlineCharacterSet(), intoString: &matchedNewlines)
		return matchedNewlines
	}
	
	private func parseTwoDoubleQuotes() -> String? {
		let dq = "\"\""
		if scanner.scanString(dq, intoString: nil) {
			return dq
		}
		return nil
	}
	
	private func parseTextData() -> String? {
		var accumulatedData = String()
		
		while true {
			var fragment: NSString?
			if scanner.scanUpToCharactersFromSet(endTextCharacterSet, intoString: &fragment) {
				accumulatedData += fragment!
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
			if scanner.scanString(separator.substringToIndex(separator.startIndex.successor()), intoString: &firstCharOfSeparator) {
				if scanner.scanString(separator.substringFromIndex(separator.startIndex.successor()), intoString: nil) {
					scanner.scanLocation = location
					break
				}
				
				/* We have the first char of the separator but not the whole
				 * separator, so just append the char and continue */
				accumulatedData += firstCharOfSeparator!
				continue
			} else {
				break
			}
		}
		
		if countElements(accumulatedData) > 0 {
			return accumulatedData
		}
		
		return nil;
	}
}

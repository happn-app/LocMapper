/*
 * StdRefLocFile.swift
 * LocMapper
 *
 * Created by François Lamboley on 7/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation
import os.log



public class StdRefLocFile {
	
	typealias Key = String
	typealias Value = [TaggedString]
	public typealias Language = String
	
	private(set) var languages: [Language]
	private(set) var entries: [Key: [Language: Value]]
	
	public convenience init(fromURL url: URL, languages: [Language], csvSeparator: String = ",") throws {
		var encoding = String.Encoding.utf8
		let filecontent = try String(contentsOf: url, usedEncoding: &encoding)
		try self.init(filecontent: filecontent, languages: languages, csvSeparator: csvSeparator)
	}
	
	init(filecontent: String, languages sourceLanguages: [Language], csvSeparator: String = ",") throws {
		let error = NSError(domain: "XibRefLocFile", code: 1, userInfo: nil)
		let parser = CSVParser(source: filecontent, startOffset: 0, separator: csvSeparator, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw error
		}
		
		var entriesBuilding = [Key: [Language: Value]]()
		for row in parsedRows {
			guard let keyStr = row["KEY"], !keyStr.isEmpty else {continue}
			let taggedKey = TaggedString(string: keyStr)
			var values = entriesBuilding[taggedKey.value] ?? [:]
			for language in sourceLanguages {values[language, default: []].append(TaggedString(value: row[language] ?? "", tags: taggedKey.tags))}
			entriesBuilding[taggedKey.value] = values
		}
		languages = sourceLanguages
		entries = entriesBuilding
	}
	
	public init(xibRefLoc: XibRefLocFile) {
		languages = xibRefLoc.languages
		
		var entriesBuilding = [Key: [Language: Value]]()
		for (xibLocKey, xibLocValues) in xibRefLoc.entries {
			entriesBuilding[xibLocKey] = Xib2Std.taggedValues(from: xibLocValues)
		}
		entries = entriesBuilding
	}
	
}

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
	
	struct TaggedValue {
		
		let tags: Set<String>
		let value: String
		
	}
	
	typealias Key = String
	typealias Value = [TaggedValue]
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
			guard let key = row["KEY"], !key.isEmpty else {continue}
			if entriesBuilding[key] != nil {
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Found duplicated key %@ when parsing reference translation loc file. The latest one wins.", log: $0, type: .info, key) }}
				else                        {NSLog("Found duplicated key %@ when parsing reference translation loc file. The latest one wins.", key)}
			}
			
			var values = [Language: Value]()
			for language in sourceLanguages {values[language] = row[language] ?? ""}
			entriesBuilding[key] = values
		}
		languages = sourceLanguages
		entries = entriesBuilding
	}
	
}

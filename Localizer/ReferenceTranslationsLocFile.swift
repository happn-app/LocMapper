/*
 * ReferenceTranslationsLocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 7/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation



class ReferenceTranslationsLocFile {
	
	typealias Key = String
	typealias Value = String
	typealias Language = String
	
	private(set) var languages: [Language]
	private(set) var entries: [Key: [Language: Value]]
	
	convenience init(fromURL url: URL, languages: [Language], csvSeparator: String = ",") throws {
		var encoding = String.Encoding.utf8
		let filecontent = try String(contentsOf: url, usedEncoding: &encoding)
		try self.init(filecontent: filecontent, languages: languages, csvSeparator: csvSeparator)
	}
	
	init(filecontent: String, languages sourceLanguages: [Language], csvSeparator: String = ",") throws {
		let error = NSError(domain: "ReferenceTranslationsLocFile", code: 1, userInfo: nil)
		let parser = CSVParser(source: filecontent, startOffset: 0, separator: csvSeparator, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw error
		}
		
		var entriesBuilding = [Key: [Language: Value]]()
		for row in parsedRows {
			guard let key = row["KEY"], !key.isEmpty else {continue}
			if entriesBuilding[key] != nil {
				print("*** Warning: Found duplicated key \(key) when parsing reference translation loc file. The latest one wins.")
			}
			
			var values = [Language: Value]()
			for language in sourceLanguages {values[language] = row[language] ?? ""}
			entriesBuilding[key] = values
		}
		languages = sourceLanguages
		entries = entriesBuilding
	}
	
}

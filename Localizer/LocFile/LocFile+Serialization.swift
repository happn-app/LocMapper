/*
 * LocFile+Serialization.swift
 * Localizer
 *
 * Created by François Lamboley on 2/4/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log



extension LocFile : TextOutputStreamable {
	
	/* ***********************
	   MARK: - Deserialization
	   *********************** */
	
	public convenience init() {
		self.init(languages: [], entries: [:], metadata: [:], csvSeparator: ",")
	}
	
	/* *** Init from path. The metadata should be retrieved with the
	`unserializedMetadata(from:)` method. They are not read from the given path,
	it is the caller responsability to retrieve them by its own means. *** */
	public convenience init(fromPath path: String, withCSVSeparator csvSep: String, metadata: Any? = nil) throws {
		var encoding: UInt = 0
		var filecontent: String?
		if FileManager.default.fileExists(atPath: path) {
			filecontent = try NSString(contentsOfFile: path, usedEncoding: &encoding) as String
		}
		try self.init(filecontent: filecontent ?? "", csvSeparator: csvSep, metadata: metadata)
	}
	
	/* *** Init with data file content. The metadata should be retrieved with the
	`unserializedMetadata(from:)` method. *** */
	public convenience init(filecontent: Data, csvSeparator csvSep: String, metadata: Any?) throws {
		guard let fileContentStr = String(data: filecontent, encoding: .utf8) else {
			throw NSError(domain: "Migrator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot read file as UTF8."])
		}
		try self.init(filecontent: fileContentStr, csvSeparator: csvSep, metadata: metadata)
	}
	
	/* *** Init with file content. The metadata should be retrieved with the
	`unserializedMetadata(from:)` method. *** */
	convenience init(filecontent: String, csvSeparator csvSep: String, metadata: Any?) throws {
		let defaultError = NSError(domain: "Migrator", code: 1, userInfo: nil)
		if filecontent.isEmpty {
			self.init(languages: [], entries: [:], metadata: [:], csvSeparator: csvSep)
			return
		}
		
		let parser = CSVParser(source: filecontent, startOffset: 0, separator: csvSep, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw defaultError
		}
		
		var languages = [String]()
		var entries = [LineKey: LineValue]()
		
		/* Retrieving languages from header */
		for h in parser.fieldNames {
			if h != LocFile.PRIVATE_KEY_HEADER_NAME && h != LocFile.PRIVATE_ENV_HEADER_NAME && h != LocFile.PRIVATE_FILENAME_HEADER_NAME &&
				h != LocFile.PRIVATE_COMMENT_HEADER_NAME && h != LocFile.PRIVATE_MAPPINGS_HEADER_NAME && h != LocFile.FILENAME_HEADER_NAME &&
				h != LocFile.COMMENT_HEADER_NAME {
				languages.append(h)
			}
		}
		
		var i = 0
		var groupComment = ""
		for row in parsedRows {
			/* We drop empty rows. */
			guard !row.reduce(true, { result, keyval in result && keyval.1.isEmpty }) else {continue}
			
			guard
				let locKey              = row[LocFile.PRIVATE_KEY_HEADER_NAME],
				let env                 = row[LocFile.PRIVATE_ENV_HEADER_NAME],
				let filename            = row[LocFile.PRIVATE_FILENAME_HEADER_NAME],
				let rawComment          = row[LocFile.PRIVATE_COMMENT_HEADER_NAME],
				let userReadableComment = row[LocFile.COMMENT_HEADER_NAME]
			else {
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Invalid row %@ found in csv file. Ignoring this row.", log: $0, type: .info, row) }}
					else                        {NSLog("Invalid row %@ found in csv file. Ignoring this row.", row)}
					continue
			}
			
			/* Does the row have a valid environment? */
			if env.isEmpty {
				/* If the environment is empty, we may have a group comment row */
				groupComment = userReadableComment
				continue
			}
			
			/* Let's get the comment and the user info */
			let comment: String
			let userInfo: [String: String]
			if rawComment.hasPrefix("__") && rawComment.hasSuffix("__") {
				let prefixAndSuffixLess = rawComment
					.replacingOccurrences(of: "__", with: "", options: [NSString.CompareOptions.anchored])
					.replacingOccurrences(of: "__", with: "", options: [NSString.CompareOptions.anchored, NSString.CompareOptions.backwards])
				(comment, userInfo) = LineKey.parse(attributedComment: prefixAndSuffixLess)
			} else {
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got comment \"%@\" which does not have the __ prefix and suffix. Setting raw comment as comment, but expect troubles.", log: $0, type: .info, rawComment) }}
				else                        {NSLog("Got comment \"%@\" which does not have the __ prefix and suffix. Setting raw comment as comment, but expect troubles.", rawComment)}
				(comment, userInfo) = LineKey.parse(attributedComment: rawComment)
			}
			
			/* Let's create the line key */
			let k = LineKey(
				locKey: locKey,
				env: env,
				filename: filename,
				index: i,
				comment: comment,
				userInfo: userInfo,
				userReadableGroupComment: groupComment,
				userReadableComment: userReadableComment
			)
			i += 1
			groupComment = ""
			
			if let mappingStr = row[LocFile.PRIVATE_MAPPINGS_HEADER_NAME], let mapping = LocKeyMapping(stringRepresentation: mappingStr) {
				/* We have a mapping (may be invalid though). Let's set it for the
				 * current line key. */
				entries[k] = .mapping(mapping)
			} else {
				/* No valid mapping. Value for current line key is dictionary of
				 * language/value. */
				var values = [String: String]()
				for l in languages {
					if let v = row[l] {
						values[l] = v
					}
				}
				entries[k] = .entries(values)
			}
		}
		self.init(languages: languages, entries: entries, metadata: metadata, csvSeparator: csvSep)
	}
	
	/* *********************
      MARK: - Serialization
	   ********************* */
	
	public func write<Target : TextOutputStream>(to target: inout Target) {
		target.write(
			LocFile.PRIVATE_KEY_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
				LocFile.PRIVATE_ENV_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
				LocFile.PRIVATE_FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
				LocFile.PRIVATE_COMMENT_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
				LocFile.PRIVATE_MAPPINGS_HEADER_NAME.csvCellValueWithSeparator(csvSeparator)
		)
		target.write(
			csvSeparator + LocFile.FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) +
				csvSeparator + LocFile.COMMENT_HEADER_NAME.csvCellValueWithSeparator(csvSeparator)
		)
		for language in languages {
			target.write(csvSeparator + language.csvCellValueWithSeparator(csvSeparator))
		}
		target.write("\n")
		var previousBasename: String?
		for entry_key in entries.keys.sorted() {
			let value = entries[entry_key]!
			
			var basename = entry_key.filename
			if let slashRange = basename.range(of: "/", options: .backwards) {
				if slashRange.lowerBound != basename.endIndex {
					basename = String(basename[basename.index(after: slashRange.lowerBound)...])
				}
			}
			if basename.hasSuffix(".xml") {basename = (basename as NSString).deletingPathExtension}
			if basename.hasSuffix(".strings") {basename = (basename as NSString).deletingPathExtension}
			
			if basename != previousBasename {
				previousBasename = basename
				target.write("\n")
				target.write(csvSeparator + csvSeparator + csvSeparator + csvSeparator + csvSeparator)
				target.write(("\\o/ \\o/ \\o/ " + previousBasename! + " \\o/ \\o/ \\o/").csvCellValueWithSeparator(csvSeparator))
				target.write(csvSeparator + "\n")
			}
			
			/* Writing group comment */
			if !entry_key.userReadableGroupComment.isEmpty {
				target.write(csvSeparator + csvSeparator + csvSeparator + csvSeparator + csvSeparator + csvSeparator)
				target.write(entry_key.userReadableGroupComment.csvCellValueWithSeparator(csvSeparator))
				target.write("\n")
			}
			
			let comment = "__" + entry_key.fullComment + "__" /* Adding text in front and at the end so editors won't fuck up the csv */
			target.write(
				entry_key.locKey.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
					entry_key.env.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
					entry_key.filename.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
					comment.csvCellValueWithSeparator(csvSeparator) + csvSeparator
			)
			if case .mapping(let mapping) = value {target.write(mapping.stringRepresentation().csvCellValueWithSeparator(csvSeparator))}
			target.write(
				csvSeparator + basename.csvCellValueWithSeparator(csvSeparator) +
					csvSeparator + entry_key.userReadableComment.csvCellValueWithSeparator(csvSeparator)
			)
			if case .entries(let entries) = value {
				for language in languages {
					target.write(csvSeparator + (entries[language] ?? "!¡!TODOLOC!¡!").csvCellValueWithSeparator(csvSeparator))
				}
			}
			target.write("\n")
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private static let PRIVATE_KEY_HEADER_NAME = "__Key"
	private static let PRIVATE_ENV_HEADER_NAME = "__Env"
	private static let PRIVATE_FILENAME_HEADER_NAME = "__Filename"
	private static let PRIVATE_COMMENT_HEADER_NAME = "__Comments"
	private static let PRIVATE_MAPPINGS_HEADER_NAME = "__Mappings"
	private static let FILENAME_HEADER_NAME = "File"
	private static let COMMENT_HEADER_NAME = "Comments"
	
}

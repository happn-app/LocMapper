/*
 * happnCSVLocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/26/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation



/* Must be a one-char string */
let CSV_SEPARATOR = ";"

let PRIVATE_KEY_HEADER_NAME = "__Key"
let PRIVATE_ENV_HEADER_NAME = "__Env"
let PRIVATE_FILENAME_HEADER_NAME = "__Filename"
let PRIVATE_COMMENT_HEADER_NAME = "__Comments"
let FILENAME_HEADER_NAME = "File"
let COMMENT_HEADER_NAME = "Comments"



extension String {
	var csvCellValue: String {
		if self.rangeOfCharacterFromSet(NSCharacterSet(charactersInString: "\(CSV_SEPARATOR)\"\n\r")) != nil {
			/* Double quotes needed */
			let doubledDoubleQuotes = self.stringByReplacingOccurrencesOfString("\"", withString: "\"\"")
			return "\"\(doubledDoubleQuotes)\""
		} else {
			/* Double quotes not needed */
			return self
		}
	}
}

class happnCSVLocFile: Streamable {
	let filepath: String
	let languages: [String]
	let entries: [LineKey: [String: String]]
	
	struct LineKey: Equatable, Hashable, Comparable {
		let locKey: String
		let env: String
		let filename: String
		let comment: String
		
		/* Used when comparing for lt or gt, but not for equality */
		let index: Int
		
		/* Not used when comparing line keys */
		let userReadableGroupComment: String
		let userReadableComment: String
		
		var hashValue: Int {
			return locKey.hashValue &+ env.hashValue &+ filename.hashValue &+ (comment.isEmpty ? 0 : 1)
		}
	}
	
	convenience init?(fromPath path: String, inout error: NSError?) {
		self.init(filepath: path, stringsFiles: [], folderNameToLanguageName: [:], error: &error)
	}
	
	convenience init?(filepath path: String, stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String], inout error: NSError?) {
		var encoding: UInt = 0
		var filecontent: String?
		if NSFileManager.defaultManager().fileExistsAtPath(path) {
			filecontent = NSString(contentsOfFile: path, usedEncoding: &encoding, error: &error)
			if filecontent == nil {
				self.init(filepath: path, languages: [], entries: [:])
				return nil
			}
		}
		self.init(filepath: path, filecontent: (filecontent != nil ? filecontent! : ""), stringsFiles: stringsFiles, folderNameToLanguageName: folderNameToLanguageName, error: &error)
	}
	
	convenience init?(filepath path: String, filecontent: String?, stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String], inout error: NSError?) {
		/* TODO: Parse the given filename, _then_ merge with the strings file */
		var index = 0
		var languages = [String]()
		var entries = [LineKey: [String: String]]()
		
		let env = "Xcode"
		for stringsFile in stringsFiles {
			var languageName = "(Unknown)"
			var filenameNoLproj = stringsFile.filepath
			for (fn, ln) in folderNameToLanguageName {
				if let range = filenameNoLproj.rangeOfString("/" + fn + "/") {
					languageName = ln
					filenameNoLproj.replaceRange(range, with: "//LANGUAGE//")
					if find(languages, ln) == nil {
						languages.append(ln)
						sort(&languages)
					}
				}
			}
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			for component in stringsFile.components {
				switch component {
				case let whiteSpace as XcodeStringsFile.WhiteSpace:
					if whiteSpace.stringValue.rangeOfString("\n\n", options: NSStringCompareOptions.LiteralSearch) != nil && !currentUserReadableComment.isEmpty {
						if !currentUserReadableGroupComment.isEmpty {
							currentUserReadableGroupComment += "\n\n\n"
						}
						currentUserReadableGroupComment += currentUserReadableComment
						currentUserReadableComment = ""
					}
					currentComment += whiteSpace.stringValue
				case let comment as XcodeStringsFile.Comment:
					if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
					currentUserReadableComment += comment.content.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).stringByReplacingOccurrencesOfString("\n * ", withString: "\n", options: NSStringCompareOptions.LiteralSearch)
					currentComment += comment.stringValue
				case let locString as XcodeStringsFile.LocalizedString:
					let key = LineKey(
						locKey: locString.key, env: env, filename: filenameNoLproj, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					if entries[key] == nil {entries[key] = [String: String]()}
					entries[key]![languageName] = locString.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				default:
					println("Got unknown XcodeStringsFile component \(component)")
				}
			}
		}
		self.init(filepath: path, languages: languages, entries: entries)
	}
	
	init(filepath path: String, languages l: [String], entries e: [LineKey: [String: String]]) {
		filepath = path
		languages = l
		entries = e
	}
	
	func writeTo<Target : OutputStreamType>(inout target: Target) {
		target.write("\(PRIVATE_KEY_HEADER_NAME.csvCellValue)\(CSV_SEPARATOR)\(PRIVATE_ENV_HEADER_NAME.csvCellValue)\(CSV_SEPARATOR)\(PRIVATE_FILENAME_HEADER_NAME.csvCellValue)\(CSV_SEPARATOR)\(PRIVATE_COMMENT_HEADER_NAME.csvCellValue)")
		target.write("\(CSV_SEPARATOR)\(FILENAME_HEADER_NAME.csvCellValue)\(CSV_SEPARATOR)\(COMMENT_HEADER_NAME.csvCellValue)");
		for language in languages {
			target.write("\(CSV_SEPARATOR)\(language.csvCellValue)")
		}
		target.write("\n")
		var previousBasename: String?
		for entry_key in sorted(entries.keys) {
			let value = entries[entry_key]!
			
			var basename = entry_key.filename
			if let slashRange = basename.rangeOfString("/", options: NSStringCompareOptions.BackwardsSearch) {
				if slashRange.startIndex != basename.endIndex {
					basename = basename.substringFromIndex(slashRange.startIndex.successor())
				}
			}
			if basename.hasSuffix(".strings") {basename = basename.stringByDeletingPathExtension}
			
			if basename != previousBasename {
				previousBasename = basename
				target.write("\n")
				target.write("\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)")
				target.write(("\\o/ \\o/ \\o/ " + previousBasename! + " \\o/ \\o/ \\o/").csvCellValue)
				target.write("\n")
			}
			
			/* Writing group comment */
			if !entry_key.userReadableGroupComment.isEmpty {
				target.write("\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)\(CSV_SEPARATOR)")
				target.write(entry_key.userReadableGroupComment.csvCellValue)
				target.write("\n")
			}
			
			let comment = "__" + entry_key.comment + "__" /* Adding text in front and at the end so editors won't fuck up the csv */
			target.write("\(entry_key.locKey.csvCellValue)\(CSV_SEPARATOR)\(entry_key.env.csvCellValue)\(CSV_SEPARATOR)\(entry_key.filename.csvCellValue)\(CSV_SEPARATOR)\(comment.csvCellValue)")
			target.write("\(CSV_SEPARATOR)\(basename.csvCellValue)\(CSV_SEPARATOR)\(entry_key.userReadableComment.csvCellValue)")
			for language in languages {
				if let languageValue = value[language] {
					target.write("\(CSV_SEPARATOR)\(languageValue.csvCellValue)")
				} else {
					target.write("\(CSV_SEPARATOR)")
				}
			}
			target.write("\n")
		}
	}
}

func ==(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	return k1.locKey == k2.locKey && k1.env == k2.env && k1.filename == k2.filename
}

func <=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	if k1.index    < k2.index    {return true}
	if k1.index    > k2.index    {return false}
	return k1.locKey <= k2.locKey
}

func >=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	if k1.index    > k2.index    {return true}
	if k1.index    < k2.index    {return false}
	return k1.locKey >= k2.locKey
}

func <(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	if k1.index    < k2.index    {return true}
	if k1.index    > k2.index    {return false}
	return k1.locKey < k2.locKey
}

func >(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	if k1.index    > k2.index    {return true}
	if k1.index    < k2.index    {return false}
	return k1.locKey > k2.locKey
}

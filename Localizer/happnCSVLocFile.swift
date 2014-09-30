/*
 * happnCSVLocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/26/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

let KEY_HEADER_NAME = "Clef"
let ENV_HEADER_NAME = "Environment"
let FILENAME_HEADER_NAME = "Fichier"
let COMMENT_HEADER_NAME = "Commentaires"



extension String {
	var csvCellValue: String {
		if self.rangeOfCharacterFromSet(NSCharacterSet(charactersInString: ",\"\n\r")) != nil {
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
		var hashValue: Int {
			return locKey.hashValue &+ env.hashValue &+ filename.hashValue &+ (comment.isEmpty ? 0 : 1)
		}
	}
	
	convenience init(fromPath path: String) {
		self.init(filepath: path, stringsFiles: [], folderNameToLanguageName: [:])
	}
	
	convenience init(filepath path: String, stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String]) {
		var encoding: UInt = 0
		let filecontent = NSString(contentsOfFile: path, usedEncoding: &encoding, error: nil)
		self.init(filepath: path, filecontent: (filecontent != nil ? filecontent! : ""), stringsFiles: stringsFiles, folderNameToLanguageName: folderNameToLanguageName)
	}
	
	convenience init(filepath path: String, filecontent: String, stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String]) {
		/* TODO: Parse the given filename, _then_ merge with the strings file */
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
			for component in stringsFile.components {
				switch component {
				case let whiteSpace as XcodeStringsFile.WhiteSpace:
					currentComment += whiteSpace.stringValue
				case let comment as XcodeStringsFile.Comment:
					currentComment += comment.stringValue
				case let locString as XcodeStringsFile.LocalizedString:
					let key = LineKey(locKey: locString.key, env: env, filename: filenameNoLproj, comment: currentComment)
					if entries[key] == nil {entries[key] = [String: String]()}
					entries[key]![languageName] = locString.value
					currentComment = ""
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
		target.write("\(KEY_HEADER_NAME),\(ENV_HEADER_NAME),\(FILENAME_HEADER_NAME),\(COMMENT_HEADER_NAME)")
		for language in languages {
			target.write(",\(language)")
		}
		target.write("\n")
		for entry_key in sorted(entries.keys) {
			let value = entries[entry_key]!
			target.write("\(entry_key.locKey.csvCellValue),\(entry_key.env.csvCellValue),\(entry_key.filename.csvCellValue),\(entry_key.comment.csvCellValue)")
			for language in languages {
				if let languageValue = value[language] {
					target.write(",\(languageValue.csvCellValue)")
				} else {
					target.write(",")
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
	return k1.locKey <= k2.locKey
}

func >=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	return k1.locKey >= k2.locKey
}

func <(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	return k1.locKey < k2.locKey
}

func >(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	return k1.locKey > k2.locKey
}

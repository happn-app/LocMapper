/*
 * LocFile+Xcode.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log



extension LocFile {
	
	public func mergeXcodeStringsFiles(_ stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let originalEntries = entries
		entries = [:]
		
		let env = "Xcode"
		var keys = [LineKey]()
		for stringsFile in stringsFiles {
			let (filenameNoLproj, languageName) = getLanguageAgnosticFilenameAndAddLanguageToList(stringsFile.filepath, withMapping: folderNameToLanguageName)
			
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			for component in stringsFile.components {
				switch component {
				case let whiteSpace as XcodeStringsFile.WhiteSpace:
					if whiteSpace.stringValue.range(of: "\n\n", options: NSString.CompareOptions.literal) != nil && !currentUserReadableComment.isEmpty {
						if !currentUserReadableGroupComment.isEmpty {
							currentUserReadableGroupComment += "\n\n\n"
						}
						currentUserReadableGroupComment += currentUserReadableComment
						currentUserReadableComment = ""
					}
					currentComment += whiteSpace.stringValue
					
				case let comment as XcodeStringsFile.Comment:
					if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
					currentUserReadableComment += comment.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: "\n * ", with: "\n", options: NSString.CompareOptions.literal)
					currentComment += comment.stringValue
					
				case let locString as XcodeStringsFile.LocalizedString:
					let refKey = LineKey(
						locKey: locString.key, env: env, filename: filenameNoLproj, index: index, comment: currentComment,
						userInfo: ["=": locString.equal, ";": locString.semicolon, "k'¿": locString.keyHasQuotes ? "0": "1", "v'¿": locString.valueHasQuotes ? "0": "1"],
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if setValue(locString.value, forKey: key, withLanguage: languageName) {index += 1}
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
					
				default:
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got unknown XcodeStringsFile component %@", log: $0, type: .info, String(describing: component)) }}
					else                        {NSLog("Got unknown XcodeStringsFile component %@", String(describing: component))}
				}
			}
		}
		
		for (refKey, val) in originalEntries {
			/* Dropping keys not in given strings files. */
			guard refKey.env != env || keys.contains(refKey) else {continue}
			
			let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
			entries[key] = val
		}
	}
	
	public func exportToXcodeProjectWithRoot(_ rootPath: String, folderNameToLanguageName: [String: String]) {
		var filenameToComponents = [String: [XcodeStringsComponent]]()
		for entry_key in entries.keys.sorted() {
			guard entry_key.env == "Xcode" else {continue}
			
			let keyHasNoQuotes   = (entry_key.userInfo["k'¿"] == "1" || entry_key.userInfo["'?"] == "0")
			let equalString      = (entry_key.userInfo["="] ?? " = ")
			let valueHasNoQuotes = (entry_key.userInfo["v'¿"] == "1")
			let semicolonString  = (entry_key.userInfo[";"] ?? ";")
			
			/* Now let's parse the comment to separate the WhiteSpace and the
			 * Comment components. */
			var commentComponents = [XcodeStringsComponent]()
			let commentScanner = Scanner(string: entry_key.comment)
			commentScanner.charactersToBeSkipped = CharacterSet() /* No characters should be skipped. */
			while !commentScanner.isAtEnd {
				var white: NSString?
				if commentScanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: &white) {
					commentComponents.append(XcodeStringsFile.WhiteSpace(white! as String))
				}
				if commentScanner.scanString("/*", into: nil) {
					var comment: NSString?
					if commentScanner.scanUpTo("*/", into: &comment) && !commentScanner.isAtEnd {
						commentComponents.append(XcodeStringsFile.Comment(comment! as String, doubleSlashed: false))
						commentScanner.scanString("*/", into: nil)
					}
				}
				if commentScanner.scanString("//", into: nil) {
					var comment: NSString?
					if commentScanner.scanUpTo("\n", into: &comment) && !commentScanner.isAtEnd {
						commentComponents.append(XcodeStringsFile.Comment(comment! as String, doubleSlashed: true))
						commentScanner.scanString("\n", into: nil)
					}
				}
				var invalid: NSString?
				if commentScanner.scanUpToCharacters(from: CharacterSet.whitespacesAndNewlines.intersection(CharacterSet(charactersIn: "/")), into: &invalid) {
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Found invalid string in comment; ignoring: “%@”", log: $0, type: .info, invalid!) }}
					else                        {NSLog("Found invalid string in comment; ignoring: “%@”", invalid!)}
				}
			}
			
			for (folderName, languageName) in folderNameToLanguageName {
				let filename = entry_key.filename.replacingOccurrences(of: "//LANGUAGE//", with: "/"+folderName+"/")
				if filenameToComponents[filename] == nil {
					filenameToComponents[filename] = [XcodeStringsComponent]()
				}
				
				filenameToComponents[filename]! += commentComponents
				
				if let v = exportedValueForKey(entry_key, withLanguage: languageName) {
					filenameToComponents[filename]!.append(XcodeStringsFile.LocalizedString(
						key: entry_key.locKey,
						keyHasQuotes: !keyHasNoQuotes,
						equalSign: equalString,
						value: v,
						valueHasQuotes: !valueHasNoQuotes,
						semicolon: semicolonString
					))
				}
			}
		}
		
		for (filename, components) in filenameToComponents {
			let locFile = XcodeStringsFile(filepath: filename, components: components)
			let fullOutputPath = (rootPath as NSString).appendingPathComponent(locFile.filepath)
			
			var stringsText = ""
			print(locFile, terminator: "", to: &stringsText)
			var err: NSError?
			do {
				try writeText(stringsText, toFile: fullOutputPath, usingEncoding: .utf8)
			} catch let error as NSError {
				err = error
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Cannot write file to path %@, got error %@", log: $0, type: .error, fullOutputPath, String(describing: err)) }}
				else                        {NSLog("Cannot write file to path %@, got error %@", fullOutputPath, String(describing: err))}
			}
		}
	}
	
}

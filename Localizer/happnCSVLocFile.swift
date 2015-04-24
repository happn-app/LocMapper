/*
 * happnCSVLocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/26/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation



let PRIVATE_KEY_HEADER_NAME = "__Key"
let PRIVATE_ENV_HEADER_NAME = "__Env"
let PRIVATE_FILENAME_HEADER_NAME = "__Filename"
let PRIVATE_COMMENT_HEADER_NAME = "__Comments"
let FILENAME_HEADER_NAME = "File"
let COMMENT_HEADER_NAME = "Comments"



extension String {
	func csvCellValueWithSeparator(sep: String) -> String {
		if count(sep) != 1 {NSException(name: "Invalid Separator", reason: "Cannot use \"\(sep)\" as a CSV separator", userInfo: nil).raise()}
		if self.rangeOfCharacterFromSet(NSCharacterSet(charactersInString: "\(sep)\"\n\r")) != nil {
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
	let csvSeparator: String
	private var languages: [String]
	private var entries: [LineKey: [String: String]]
	
	/* *************** LineKey struct. Key for each entries in the happn CSV loc file. *************** */
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
	
	/* *** Init from path *** */
	convenience init?(fromPath path: String, withCSVSeparator csvSep: String, inout error: NSError?) {
		var encoding: UInt = 0
		var filecontent: String?
		if NSFileManager.defaultManager().fileExistsAtPath(path) {
			filecontent = NSString(contentsOfFile: path, usedEncoding: &encoding, error: &error) as String?
			if filecontent == nil {
				self.init(filepath: path, languages: [], entries: [:], csvSeparator: csvSep)
				return nil
			}
		}
		self.init(filepath: path, filecontent: (filecontent != nil ? filecontent! : ""), withCSVSeparator: csvSep, error: &error)
	}
	
	/* *** Init with file content *** */
	convenience init?(filepath path: String, filecontent: String, withCSVSeparator csvSep: String, inout error: NSError?) {
		if filecontent.isEmpty {
			self.init(filepath: path, languages: [], entries: [:], csvSeparator: csvSep)
			return
		}
		
		let parser = CSVParser(source: filecontent, separator: csvSep, hasHeader: true, fieldNames: nil)
		if let parsedRows = parser.arrayOfParsedRows() {
			var languages = [String]()
			var entries = [LineKey: [String: String]]()
			
			/* Retrieving languages from header */
			for h in parser.fieldNames {
				if h != PRIVATE_KEY_HEADER_NAME && h != PRIVATE_ENV_HEADER_NAME && h != PRIVATE_FILENAME_HEADER_NAME &&
					h != PRIVATE_COMMENT_HEADER_NAME && h != FILENAME_HEADER_NAME && h != COMMENT_HEADER_NAME {
					languages.append(h)
				}
			}
			
			var i = 0
			var groupComment = ""
			for row in parsedRows {
				let rowKeys = row.keys
				/* Is the row valid? */
				if find(row.keys, PRIVATE_KEY_HEADER_NAME) == nil ||
					find(row.keys, PRIVATE_ENV_HEADER_NAME) == nil ||
					find(row.keys, PRIVATE_FILENAME_HEADER_NAME) == nil ||
					find(row.keys, PRIVATE_COMMENT_HEADER_NAME) == nil ||
					find(row.keys, COMMENT_HEADER_NAME) == nil {
					println("*** Warning: Invalid row \(row) found in csv file. Ignoring this row.")
					continue
				}
				
				/* Does the row have a valid environment? */
				let env = row[PRIVATE_ENV_HEADER_NAME]!
				if env.isEmpty {
					/* If the environment is empty, we may have a group comment row */
					if let gc = row[COMMENT_HEADER_NAME] {
						groupComment = gc
					}
					continue
				}
				
				/* Let's get the comment */
				var comment: String!
				let rawComment = row[PRIVATE_COMMENT_HEADER_NAME]!
//				if !rawComment.hasPrefix("__") || !rawComment.hasSuffix("__") {
					comment = rawComment.stringByReplacingOccurrencesOfString(
						"__", withString: "", options: NSStringCompareOptions.AnchoredSearch
					).stringByReplacingOccurrencesOfString(
						"__", withString: "", options: NSStringCompareOptions.AnchoredSearch | NSStringCompareOptions.BackwardsSearch
					)
/*				} else {
					println("*** Warning: Got comment \"\(rawComment)\" which does not have the __ prefix and suffix. Adding setting raw comment as comment, but expect troubles.")
					comment = rawComment
				}*/
				
				/* Let's create the line key */
				let k = LineKey(
					locKey: row[PRIVATE_KEY_HEADER_NAME]!,
					env: env,
					filename: row[PRIVATE_FILENAME_HEADER_NAME]!,
					comment: comment,
					index: i++,
					userReadableGroupComment: groupComment,
					userReadableComment: row[COMMENT_HEADER_NAME]!)
				groupComment = ""
				
				/* Now let's retrieve the values per language */
				var values = [String: String]()
				for l in languages {
					if let v = row[l] {
						values[l] = v
					}
				}
				entries[k] = values
			}
			self.init(filepath: path, languages: languages, entries: entries, csvSeparator: csvSep)
		} else {
			self.init(filepath: path, languages: [], entries: [:], csvSeparator: csvSep)
			return nil
		}
	}
	
	/* *** Init *** */
	init(filepath path: String, languages l: [String], entries e: [LineKey: [String: String]], csvSeparator csvSep: String) {
		if count(csvSep) != 1 {NSException(name: "Invalid Separator", reason: "Cannot use \"\(csvSep)\" as a CSV separator", userInfo: nil).raise()}
		csvSeparator = csvSep
		filepath = path
		languages = l
		entries = e
	}
	
	func mergeXcodeStringsFiles(stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
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
					let refKey = LineKey(
						locKey: (locString.keyHasQuotes ? "'" : "#")+locString.key, env: env, filename: filenameNoLproj, comment: locString.equal+";"+locString.semicolon+currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = locString.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				default:
					println("Got unknown XcodeStringsFile component \(component)")
				}
			}
		}
	}
	
	func exportToXcodeProjectWithRoot(rootPath: String, folderNameToLanguageName: [String: String]) {
		var filenameToComponents = [String: [XcodeStringsComponent]]()
		for entry_key in sorted(entries.keys) {
			if entry_key.env != "Xcode" {continue}
			
			var scannedString: NSString?
			let keyScanner = NSScanner(string: entry_key.locKey)
			keyScanner.charactersToBeSkipped = NSCharacterSet() /* No characters should be skipped. */
			
			/* Let's see if the key has quotes */
			if !keyScanner.scanCharactersFromSet(NSCharacterSet(charactersInString: "'#"), intoString: &scannedString) {
				println("*** Warning: Got invalid key \(entry_key.locKey)")
				continue
			}
			/* If the key in CSV file begins with a simple quotes, the Xcode key has double-quotes */
			let keyHasQuotes = (scannedString == "'")
			/* Let's get the Xcode original key */
			if !keyScanner.scanUpToString("", intoString: &scannedString) {
				println("*** Warning: Got invalid key \(entry_key.locKey): Cannot scan original key")
				continue
			}
			let k = scannedString!
			
			/* Now let's parse the comment to get the equal and semicolon strings */
			let commentScanner = NSScanner(string: entry_key.comment)
			commentScanner.charactersToBeSkipped = NSCharacterSet() /* No characters should be skipped. */
			
			/* Getting equal string */
			var equalString = ""
			if commentScanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &scannedString) {
				if let white = scannedString {equalString += white as String}
			}
			if !commentScanner.scanString("=", intoString: nil) {
				println("*** Warning: Got invalid key \(entry_key.locKey): No equal sign in equal string")
				continue
			}
			equalString += "="
			if commentScanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &scannedString) {
				if let white = scannedString {equalString += white as String}
			}
			
			/* Separator between equal and semicolon strings */
			if !commentScanner.scanString(";", intoString: nil) {
				println("*** Warning: Got invalid key \(entry_key.locKey): Character after equal string is not a semicolon")
				continue
			}
			
			/* Getting semicolon string */
			var semicolonString = ""
			if commentScanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &scannedString) {
				if let white = scannedString {semicolonString += white as String}
			}
			if !commentScanner.scanString(";", intoString: nil) {
				println("*** Warning: Got invalid key \(entry_key.locKey): No semicolon sign in semicolon string")
				continue
			}
			semicolonString += ";"
			
			var commentComponents = [XcodeStringsComponent]()
			while !commentScanner.atEnd {
				var white: NSString?
				if commentScanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &white) {
					commentComponents.append(XcodeStringsFile.WhiteSpace(white! as String))
				}
				if commentScanner.scanString("/*", intoString: nil) {
					var comment: NSString?
					if commentScanner.scanUpToString("*/", intoString: &comment) && !commentScanner.atEnd {
						commentComponents.append(XcodeStringsFile.Comment(comment! as String))
						commentScanner.scanString("*/", intoString: nil)
						if commentScanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &white) {
							commentComponents.append(XcodeStringsFile.WhiteSpace(white! as String))
						}
					}
				}
			}
			
			let value = entries[entry_key]!
			
			for (folderName, languageName) in folderNameToLanguageName {
				let filename = entry_key.filename.stringByReplacingOccurrencesOfString("//LANGUAGE//", withString: "/"+folderName+"/")
				if filenameToComponents[filename] == nil {
					filenameToComponents[filename] = [XcodeStringsComponent]()
				}
				
				filenameToComponents[filename]! += commentComponents
				
				if let v = value[languageName] {
					filenameToComponents[filename]!.append(XcodeStringsFile.LocalizedString(
						key: k as String,
						keyHasQuotes: keyHasQuotes,
						equalSign: equalString,
						value: v,
						andSemicolon: semicolonString
					))
				}
			}
		}
		
		for (filename, components) in filenameToComponents {
			let locFile = XcodeStringsFile(filepath: filename, components: components)
			let fullOutputPath = rootPath.stringByAppendingPathComponent(locFile.filepath)
			
			var stringsText = ""
			print(locFile, &stringsText)
			var err: NSError?
			if !writeText(stringsText, toFile: fullOutputPath, usingEncoding: NSUTF16StringEncoding, &err) {
				println("Error: Cannot write file to path \(fullOutputPath), got error \(err)")
			}
		}
	}
	
	func mergeAndroidXMLLocStringsFiles(locFiles: [AndroidXMLLocFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let env = "Android"
		var keys = [LineKey]()
		for locFile in locFiles {
			let (filenameNoLanguage, languageName) = getLanguageAgnosticFilenameAndAddLanguageToList(locFile.filepath, withMapping: folderNameToLanguageName)
			
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			for component in locFile.components {
				switch component {
				case let whiteSpace as AndroidXMLLocFile.WhiteSpace:
					if whiteSpace.stringValue.rangeOfString("\n\n", options: NSStringCompareOptions.LiteralSearch) != nil && !currentUserReadableComment.isEmpty {
						if !currentUserReadableGroupComment.isEmpty {
							currentUserReadableGroupComment += "\n\n\n"
						}
						currentUserReadableGroupComment += currentUserReadableComment
						currentUserReadableComment = ""
					}
					currentComment += whiteSpace.stringValue
				case let comment as AndroidXMLLocFile.Comment:
					if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
					currentUserReadableComment += comment.content.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).stringByReplacingOccurrencesOfString("\n * ", withString: "\n", options: NSStringCompareOptions.LiteralSearch)
					currentComment += comment.stringValue
				case let groupOpening as AndroidXMLLocFile.GroupOpening:
					let refKey = LineKey(
						locKey: "o"+groupOpening.fullString, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = "--"
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let groupClosing as AndroidXMLLocFile.GroupClosing:
					let refKey = LineKey(
						locKey: "c"+groupClosing.groupName+(groupClosing.nameAttr != nil ? " "+groupClosing.nameAttr! : ""),
						env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = "--"
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let locString as AndroidXMLLocFile.StringValue:
					let refKey = LineKey(
						locKey: (!locString.isCDATA ? "k" : "K") + locString.key, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = locString.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let arrayItem as AndroidXMLLocFile.ArrayItem:
					let refKey = LineKey(
						locKey: "a"+arrayItem.parentName+"\""+String(arrayItem.idx), env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = arrayItem.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let pluralItem as AndroidXMLLocFile.PluralItem:
					let refKey = LineKey(
						locKey: "p"+pluralItem.parentName+"\""+pluralItem.quantity, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = pluralItem.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				default:
					println("Got unknown AndroidXMLLocFile component \(component)")
				}
			}
		}
	}
	
	func exportToAndroidProjectWithRoot(rootPath: String, folderNameToLanguageName: [String: String]) {
		var filenameToComponents = [String: [AndroidLocComponent]]()
		for entry_key in sorted(entries.keys) {
			if entry_key.env != "Android" {continue}
			
			let value = entries[entry_key]!
			
			for (folderName, languageName) in folderNameToLanguageName {
				let filename = entry_key.filename.stringByReplacingOccurrencesOfString("//LANGUAGE//", withString: "/"+folderName+"/")
				if filenameToComponents[filename] == nil {
					filenameToComponents[filename] = [AndroidLocComponent]()
				}
				
				if !entry_key.comment.isEmpty {
					var white: NSString?
					let scanner = NSScanner(string: entry_key.comment)
					scanner.charactersToBeSkipped = NSCharacterSet()
					if scanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &white) {
						filenameToComponents[filename]!.append(AndroidXMLLocFile.WhiteSpace(white! as String))
					}
					if scanner.scanString("<!--", intoString: nil) {
						var comment: NSString?
						if scanner.scanUpToString("-->", intoString: &comment) && !scanner.atEnd {
							filenameToComponents[filename]!.append(AndroidXMLLocFile.Comment(comment! as String))
							scanner.scanString("-->", intoString: nil)
							if scanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &white) {
								filenameToComponents[filename]!.append(AndroidXMLLocFile.WhiteSpace(white! as String))
							}
						}
					}
					if !scanner.atEnd {
						println("*** Warning: Got invalid comment \"\(entry_key.comment)\"")
					}
				}
				
				switch entry_key.locKey {
				case let k where k.hasPrefix("o"):
					/* We're treating a group opening */
					filenameToComponents[filename]!.append(AndroidXMLLocFile.GroupOpening(fullString: k.substringFromIndex(k.startIndex.successor())))
				case let k where k.hasPrefix("c"):
					/* We're treating a group closing */
					let noC = k.substringFromIndex(k.startIndex.successor())
					let sepBySpace = noC.componentsSeparatedByString(" ")
					if sepBySpace.count > 0 && sepBySpace.count <= 2 {
						filenameToComponents[filename]!.append(AndroidXMLLocFile.GroupClosing(groupName: sepBySpace[0], nameAttributeValue: (sepBySpace.count > 1 ? sepBySpace[1] : nil)))
					} else {
						println("*** Warning: Got invalid closing key \(k)")
					}
				case let k where k.hasPrefix("k"):
					/* We're treating a standard string item */
					if let v = value[languageName] {
						filenameToComponents[filename]!.append(AndroidXMLLocFile.StringValue(key: k.substringFromIndex(k.startIndex.successor()), value: v))
					} else {
						println("*** Warning: Didn't get a value for language \(languageName) for key \(k)")
					}
				case let k where k.hasPrefix("K"):
					/* We're treating a CDATA string item */
					if let v = value[languageName] {
						filenameToComponents[filename]!.append(AndroidXMLLocFile.StringValue(key: k.substringFromIndex(k.startIndex.successor()), cDATAValue: v))
					} else {
						println("*** Warning: Didn't get a value for language \(languageName) for key \(k)")
					}
				case let k where k.hasPrefix("a"):
					/* We're treating an array item */
					if let v = value[languageName] {
						let noA = k.substringFromIndex(k.startIndex.successor())
						let sepByQuote = noA.componentsSeparatedByString("\"")
						if sepByQuote.count == 2 {
							if let idx = sepByQuote[1].toInt() {
								filenameToComponents[filename]!.append(AndroidXMLLocFile.ArrayItem(value: v, index: idx, parentName: sepByQuote[0]))
							} else {
								println("*** Warning: Invalid key '\(k)': cannot find idx")
							}
						} else {
							println("*** Warning: Got invalid array item key '\(k)'")
						}
					} else {
						println("*** Warning: Didn't get a value for language \(languageName) for key \(k)")
					}
				case let k where k.hasPrefix("p"):
					/* We're treating a plural item */
					if let v = value[languageName] {
						let noP = k.substringFromIndex(k.startIndex.successor())
						let sepByQuote = noP.componentsSeparatedByString("\"")
						if sepByQuote.count == 2 {
							filenameToComponents[filename]!.append(AndroidXMLLocFile.PluralItem(quantity: sepByQuote[1], value: v, parentName: sepByQuote[0]))
						} else {
							println("*** Warning: Got invalid plural key '\(k)'")
						}
					} else {
						println("*** Warning: Didn't get a value for language \(languageName) for key \(k)")
					}
				default:
					println("*** Warning: Got invalid key \(entry_key.locKey)")
				}
			}
		}
		for (filename, components) in filenameToComponents {
			let locFile = AndroidXMLLocFile(pathRelativeToProject: filename, components: components)
			let fullOutputPath = rootPath.stringByAppendingPathComponent(locFile.filepath)
			
			var xmlText = ""
			print(locFile, &xmlText)
			var err: NSError?
			if !writeText(xmlText, toFile: fullOutputPath, usingEncoding: NSUTF8StringEncoding, &err) {
				println("Error: Cannot write file to path \(fullOutputPath), got error \(err)")
			}
		}
	}
	
	func writeTo<Target : OutputStreamType>(inout target: Target) {
		target.write("\(PRIVATE_KEY_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)\(PRIVATE_ENV_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)\(PRIVATE_FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)\(PRIVATE_COMMENT_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))")
		target.write("\(csvSeparator)\(FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)\(COMMENT_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))");
		for language in languages {
			target.write("\(csvSeparator)\(language.csvCellValueWithSeparator(csvSeparator))")
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
				target.write("\(csvSeparator)\(csvSeparator)\(csvSeparator)\(csvSeparator)")
				target.write(("\\o/ \\o/ \\o/ " + previousBasename! + " \\o/ \\o/ \\o/").csvCellValueWithSeparator(csvSeparator))
				target.write("\n")
			}
			
			/* Writing group comment */
			if !entry_key.userReadableGroupComment.isEmpty {
				target.write("\(csvSeparator)\(csvSeparator)\(csvSeparator)\(csvSeparator)\(csvSeparator)")
				target.write(entry_key.userReadableGroupComment.csvCellValueWithSeparator(csvSeparator))
				target.write("\n")
			}
			
			let comment = "__" + entry_key.comment + "__" /* Adding text in front and at the end so editors won't fuck up the csv */
			target.write("\(entry_key.locKey.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)\(entry_key.env.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)\(entry_key.filename.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)\(comment.csvCellValueWithSeparator(csvSeparator))")
			target.write("\(csvSeparator)\(basename.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)\(entry_key.userReadableComment.csvCellValueWithSeparator(csvSeparator))")
			for language in languages {
				if let languageValue = value[language] {
					target.write("\(csvSeparator)\(languageValue.csvCellValueWithSeparator(csvSeparator))")
				} else {
					target.write("\(csvSeparator)")
				}
			}
			target.write("\n")
		}
	}
	
	private func getLanguageAgnosticFilenameAndAddLanguageToList(filename: String, withMapping languageMapping: [String: String]) -> (String, String) {
		var found = false
		var languageName = "(Unknown)"
		var filenameNoLproj = filename
		
		for (fn, ln) in languageMapping {
			if let range = filenameNoLproj.rangeOfString("/" + fn + "/") {
				assert(!found)
				found = true
				
				languageName = ln
				filenameNoLproj.replaceRange(range, with: "//LANGUAGE//")
			}
		}
		
		if find(languages, languageName) == nil {
			languages.append(languageName)
			sort(&languages)
		}
		
		return (filenameNoLproj, languageName)
	}
	
	private func getKeyFrom(refKey: LineKey, inout withListOfKeys keys: [LineKey]) -> LineKey {
		if let idx = find(keys, refKey) {
			if keys[idx].comment != refKey.comment {
				println("*** Warning: Got different comment for same loc key \"\(refKey.locKey)\" (file \(refKey.filename)): \"\(keys[idx].comment)\" and \"\(refKey.comment)\"")
			}
			return keys[idx]
		}
		keys.append(refKey)
		return refKey
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

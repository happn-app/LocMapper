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
let PRIVATE_MAPPINGS_HEADER_NAME = "__Mappings"
let FILENAME_HEADER_NAME = "File"
let COMMENT_HEADER_NAME = "Comments"



extension String {
	func csvCellValueWithSeparator(sep: String) -> String {
		if sep.characters.count != 1 {NSException(name: "Invalid Separator", reason: "Cannot use \"\(sep)\" as a CSV separator", userInfo: nil).raise()}
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
	private var mappings: [LineKey: happnCSVLocKeyMapping]
	private var entries: [LineKey: [String /* Language */: String /* Value */]]
	
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
			return locKey.hashValue &+ env.hashValue &+ filename.hashValue
		}
	}
	
	/* *************** Key Mapping. *************** */
	class happnCSVLocKeyMapping {
		
		let originalStringRepresentation: String
		var components: [happnCSVLocKeyMappingComponent]?
		
		convenience init(stringRepresentation: String) {
			guard let
				data = stringRepresentation.dataUsingEncoding(NSUTF8StringEncoding),
				serializedComponent_s = try? NSJSONSerialization.JSONObjectWithData(data, options: [])
				else {
					if stringRepresentation.characters.count > 0 { /* No need to print a warning for empty strings. We know. */
						print("*** Warning: Invalid mapping; cannot serialize JSON string: \"\(stringRepresentation)\"")
					}
					self.init(components: nil, stringRepresentation: stringRepresentation)
					return
			}
			let serializedComponents: [[String: AnyObject]]
			if      let array = serializedComponent_s as? [[String: AnyObject]] {serializedComponents = array}
			else if let simple = serializedComponent_s as? [String: AnyObject]  {serializedComponents = [simple]}
			else {
				print("*** Warning: Invalid mapping; cannot convert string to array of dictionary: \"\(stringRepresentation)\"")
				self.init(components: nil, stringRepresentation: stringRepresentation)
				return
			}
			
			self.init(components: serializedComponents.map {return happnCSVLocKeyMappingComponent.createCSVLocKeyMappingFromSerialization($0)}, stringRepresentation: stringRepresentation)
		}
		
		convenience init(components: [happnCSVLocKeyMappingComponent]) {
			self.init(components: components, stringRepresentation: happnCSVLocKeyMapping.stringRepresentationFromComponentsList(components))
		}
		
		init(components c: [happnCSVLocKeyMappingComponent]?, stringRepresentation: String) {
			components = c
			originalStringRepresentation = stringRepresentation
		}
		
		func stringRepresentation() -> String {
			if let components = components {
				return happnCSVLocKeyMapping.stringRepresentationFromComponentsList(components)
			} else {
				return originalStringRepresentation
			}
		}
		
		private static func stringRepresentationFromComponentsList(components: [happnCSVLocKeyMappingComponent]) -> String {
			let allSerialized = components.map {return $0.serialize()}
			return try! String(data: NSJSONSerialization.dataWithJSONObject(
				(allSerialized.count == 1 ? allSerialized[0] as AnyObject : allSerialized as AnyObject),
				options: [.PrettyPrinted]),
				encoding: NSUTF8StringEncoding
			)!
		}
		
	}
	
	/* *** Init from path *** */
	convenience init(fromPath path: String, withCSVSeparator csvSep: String) throws {
		var encoding: UInt = 0
		var filecontent: String?
		if NSFileManager.defaultManager().fileExistsAtPath(path) {
			filecontent = try NSString(contentsOfFile: path, usedEncoding: &encoding) as String
		}
		try self.init(filepath: path, filecontent: (filecontent != nil ? filecontent! : ""), withCSVSeparator: csvSep)
	}
	
	/* *** Init with file content *** */
	convenience init(filepath path: String, filecontent: String, withCSVSeparator csvSep: String) throws {
		let error: NSError! = NSError(domain: "Migrator", code: 0, userInfo: nil)
		if filecontent.isEmpty {
			self.init(filepath: path, languages: [], entries: [:], mappings: [:], csvSeparator: csvSep)
			return
		}
		
		let parser = CSVParser(source: filecontent, separator: csvSep, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw error
		}
		
		var languages = [String]()
		var entries = [LineKey: [String: String]]()
		var mappings = [LineKey: happnCSVLocKeyMapping]()
		
		/* Retrieving languages from header */
		for h in parser.fieldNames {
			if h != PRIVATE_KEY_HEADER_NAME && h != PRIVATE_ENV_HEADER_NAME && h != PRIVATE_FILENAME_HEADER_NAME &&
				h != PRIVATE_COMMENT_HEADER_NAME && h != PRIVATE_MAPPINGS_HEADER_NAME && h != FILENAME_HEADER_NAME &&
				h != COMMENT_HEADER_NAME {
				languages.append(h)
			}
		}
		
		var i = 0
		var groupComment = ""
		for row in parsedRows {
			let rowKeys = row.keys
			/* Is the row valid? */
			if rowKeys.indexOf(PRIVATE_KEY_HEADER_NAME) == nil ||
				rowKeys.indexOf(PRIVATE_ENV_HEADER_NAME) == nil ||
				rowKeys.indexOf(PRIVATE_FILENAME_HEADER_NAME) == nil ||
				rowKeys.indexOf(PRIVATE_COMMENT_HEADER_NAME) == nil ||
				rowKeys.indexOf(PRIVATE_MAPPINGS_HEADER_NAME) == nil ||
				rowKeys.indexOf(COMMENT_HEADER_NAME) == nil {
				print("*** Warning: Invalid row \(row) found in csv file. Ignoring this row.")
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
//			if !rawComment.hasPrefix("__") || !rawComment.hasSuffix("__") {
				comment = rawComment.stringByReplacingOccurrencesOfString(
					"__", withString: "", options: NSStringCompareOptions.AnchoredSearch
				).stringByReplacingOccurrencesOfString(
					"__", withString: "", options: [NSStringCompareOptions.AnchoredSearch, NSStringCompareOptions.BackwardsSearch]
				)
/*			} else {
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
			
			/* Let's get the mappings for this key. */
			mappings[k] = happnCSVLocKeyMapping(stringRepresentation: row[PRIVATE_MAPPINGS_HEADER_NAME]!)
			
			/* Now let's retrieve the values per language */
			var values = [String: String]()
			for l in languages {
				if let v = row[l] {
					values[l] = v
				}
			}
			entries[k] = values
		}
		self.init(filepath: path, languages: languages, entries: entries, mappings: mappings, csvSeparator: csvSep)
	}
	
	/* *** Init *** */
	init(filepath path: String, languages l: [String], entries e: [LineKey: [String: String]], mappings m: [LineKey: happnCSVLocKeyMapping], csvSeparator csvSep: String) {
		if csvSep.characters.count != 1 {NSException(name: "Invalid Separator", reason: "Cannot use \"\(csvSep)\" as a CSV separator", userInfo: nil).raise()}
		csvSeparator = csvSep
		filepath = path
		languages = l
		entries = e
		mappings = m
	}
	
	func mergeXcodeStringsFiles(stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let originalEntries = self.entries
		self.entries = [:]
		
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
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = locString.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				default:
					print("Got unknown XcodeStringsFile component \(component)")
				}
			}
		}
		
		for (refKey, val) in originalEntries {
			let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
			entries[key] = val
		}
	}
	
	func exportToXcodeProjectWithRoot(rootPath: String, folderNameToLanguageName: [String: String]) {
		var filenameToComponents = [String: [XcodeStringsComponent]]()
		for entry_key in entries.keys.sort() {
			if entry_key.env != "Xcode" {continue}
			
			var scannedString: NSString?
			let keyScanner = NSScanner(string: entry_key.locKey)
			keyScanner.charactersToBeSkipped = NSCharacterSet() /* No characters should be skipped. */
			
			/* Let's see if the key has quotes */
			if !keyScanner.scanCharactersFromSet(NSCharacterSet(charactersInString: "'#"), intoString: &scannedString) {
				print("*** Warning: Got invalid key \(entry_key.locKey)")
				continue
			}
			/* If the key in CSV file begins with a simple quotes, the Xcode key has double-quotes */
			let keyHasQuotes = (scannedString == "'")
			/* Let's get the Xcode original key */
			if !keyScanner.scanUpToString("", intoString: &scannedString) {
				print("*** Warning: Got invalid key \(entry_key.locKey): Cannot scan original key")
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
				print("*** Warning: Got invalid key \(entry_key.locKey): No equal sign in equal string")
				continue
			}
			equalString += "="
			if commentScanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &scannedString) {
				if let white = scannedString {equalString += white as String}
			}
			
			/* Separator between equal and semicolon strings */
			if !commentScanner.scanString(";", intoString: nil) {
				print("*** Warning: Got invalid key \(entry_key.locKey): Character after equal string is not a semicolon")
				continue
			}
			
			/* Getting semicolon string */
			var semicolonString = ""
			if commentScanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &scannedString) {
				if let white = scannedString {semicolonString += white as String}
			}
			if !commentScanner.scanString(";", intoString: nil) {
				print("*** Warning: Got invalid key \(entry_key.locKey): No semicolon sign in semicolon string")
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
			let fullOutputPath = (rootPath as NSString).stringByAppendingPathComponent(locFile.filepath)
			
			var stringsText = ""
			print(locFile, terminator: "", toStream: &stringsText)
			var err: NSError?
			do {
				try writeText(stringsText, toFile: fullOutputPath, usingEncoding: NSUTF16StringEncoding)
			} catch let error as NSError {
				err = error
				print("Error: Cannot write file to path \(fullOutputPath), got error \(err)")
			}
		}
	}
	
	func mergeAndroidXMLLocStringsFiles(locFiles: [AndroidXMLLocFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let originalEntries = self.entries
		self.entries = [:]
		
		let env = "Android"
		var keys = [LineKey]()
		for locFile in locFiles {
			let (filenameNoLanguage, languageName) = getLanguageAgnosticFilenameAndAddLanguageToList(locFile.filepath, withMapping: folderNameToLanguageName)
			
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			
			func handleWhiteSpace(whiteSpace: AndroidXMLLocFile.WhiteSpace) {
				if whiteSpace.stringValue.rangeOfString("\n\n", options: NSStringCompareOptions.LiteralSearch) != nil && !currentUserReadableComment.isEmpty {
					if !currentUserReadableGroupComment.isEmpty {
						currentUserReadableGroupComment += "\n\n\n"
					}
					currentUserReadableGroupComment += currentUserReadableComment
					currentUserReadableComment = ""
				}
				currentComment += whiteSpace.stringValue
			}
			
			func handleComment(comment: AndroidXMLLocFile.Comment) {
				if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
				currentUserReadableComment += comment.content.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).stringByReplacingOccurrencesOfString("\n * ", withString: "\n", options: NSStringCompareOptions.LiteralSearch)
				currentComment += comment.stringValue
			}
			
			for component in locFile.components {
				switch component {
				case let whiteSpace as AndroidXMLLocFile.WhiteSpace:
					handleWhiteSpace(whiteSpace)
				case let comment as AndroidXMLLocFile.Comment:
					handleComment(comment)
				case let groupOpening as AndroidXMLLocFile.GenericGroupOpening:
					let refKey = LineKey(
						locKey: "o"+groupOpening.fullString, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = "--"
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let groupClosing as AndroidXMLLocFile.GenericGroupClosing:
					let refKey = LineKey(
						locKey: "c"+groupClosing.groupName+(groupClosing.nameAttr != nil ? " "+groupClosing.nameAttr! : ""),
						env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
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
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
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
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = arrayItem.value
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let pluralGroup as AndroidXMLLocFile.PluralGroup:
					let refKey = LineKey(
						locKey: "s"+pluralGroup.name, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if entries[key] == nil {entries[key] = [String: String]()}
					else                   {--index}
					entries[key]![languageName] = "--"
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
					for quantity in ["zero", "one", "two", "few", "many", "other"] {
						if let info = pluralGroup.values[quantity], (spaces, _) = info {
							for space in spaces {
								switch space {
								case let whiteSpace as AndroidXMLLocFile.WhiteSpace:
									handleWhiteSpace(whiteSpace)
								case let comment as AndroidXMLLocFile.Comment:
									handleComment(comment)
								default:
									fatalError("Invalid space: \(space)")
								}
							}
						}
						let pluralItem = pluralGroup.values[quantity]??.1
						let prefix = (pluralItem != nil && pluralItem!.isCDATA ? "P" : "p")
						let refKey = LineKey(
							locKey: prefix+pluralGroup.name+"\""+quantity, env: env, filename: filenameNoLanguage, comment: currentComment, index: index++,
							userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
						)
						let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: true, withListOfKeys: &keys)
						if entries[key] == nil {entries[key] = [String: String]()}
						else                   {--index}
						entries[key]![languageName] = (pluralItem?.value ?? "--")
						currentComment = ""
						currentUserReadableComment = ""
						currentUserReadableGroupComment = ""
					}
				default:
					print("Got unknown AndroidXMLLocFile component \(component)")
				}
			}
		}
		
		for (refKey, val) in originalEntries {
			let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
			entries[key] = val
		}
	}
	
	func exportToAndroidProjectWithRoot(rootPath: String, folderNameToLanguageName: [String: String]) {
		var filenameToComponents = [String: [AndroidLocComponent]]()
		var spaces = [AndroidLocComponent /* Only WhiteSpace and Comment */]()
		var currentPluralsValueByFilename: [String /* Language */: [String /* Quantity */: ([AndroidLocComponent /* Only WhiteSpace and Comment */], AndroidXMLLocFile.PluralGroup.PluralItem)?]] = [:]
		for entry_key in entries.keys.sort() {
			if entry_key.env != "Android" {continue}
			
			let value = entries[entry_key]!
			
			if !entry_key.comment.isEmpty {
				var white: NSString?
				let scanner = NSScanner(string: entry_key.comment)
				scanner.charactersToBeSkipped = NSCharacterSet()
				if scanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &white) {
					spaces.append(AndroidXMLLocFile.WhiteSpace(white! as String))
				}
				if scanner.scanString("<!--", intoString: nil) {
					var comment: NSString?
					if scanner.scanUpToString("-->", intoString: &comment) && !scanner.atEnd {
						spaces.append(AndroidXMLLocFile.Comment(comment! as String))
						scanner.scanString("-->", intoString: nil)
						if scanner.scanCharactersFromSet(NSCharacterSet.whitespaceAndNewlineCharacterSet(), intoString: &white) {
							spaces.append(AndroidXMLLocFile.WhiteSpace(white! as String))
						}
					}
				}
				if !scanner.atEnd {
					print("*** Warning: Got invalid comment \"\(entry_key.comment)\"")
				}
			}
			
			for (folderName, languageName) in folderNameToLanguageName {
				let filename = entry_key.filename.stringByReplacingOccurrencesOfString("//LANGUAGE//", withString: "/"+folderName+"/")
				if filenameToComponents[filename] == nil {
					filenameToComponents[filename] = [AndroidLocComponent]()
				}
				
				switch entry_key.locKey {
				case let k where k.hasPrefix("o"):
					/* We're treating a group opening */
					filenameToComponents[filename]!.appendContentsOf(spaces)
					filenameToComponents[filename]!.append(AndroidXMLLocFile.GenericGroupOpening(fullString: k.substringFromIndex(k.startIndex.successor())))
				case let k where k.hasPrefix("s"):
					/* We're treating a plural group opening */
					filenameToComponents[filename]!.appendContentsOf(spaces)
					currentPluralsValueByFilename[filename] = [:]
				case let k where k.hasPrefix("c"):
					/* We're treating a group closing */
					let noC = k.substringFromIndex(k.startIndex.successor())
					let sepBySpace = noC.componentsSeparatedByString(" ")
					if let plurals = currentPluralsValueByFilename[filename] {
						/* We have a plural group being contructed. We've reached it's
						 * closing component: let's add the finished plural to the
						 * components. */
						if sepBySpace.count == 2 && sepBySpace[0] == "plurals" {
							filenameToComponents[filename]!.append(AndroidXMLLocFile.PluralGroup(name: sepBySpace[1], values: plurals))
						} else {
							print("*** Warning: Got invalid plural closing key \(k). Dropping whole plurals group.")
						}
						currentPluralsValueByFilename.removeValueForKey(filename)
					}
					filenameToComponents[filename]!.appendContentsOf(spaces)
					if sepBySpace.count > 0 && sepBySpace.count <= 2 {
						filenameToComponents[filename]!.append(AndroidXMLLocFile.GenericGroupClosing(groupName: sepBySpace[0], nameAttributeValue: (sepBySpace.count > 1 ? sepBySpace[1] : nil)))
					} else {
						print("*** Warning: Got invalid closing key \(k)")
					}
				case let k where k.hasPrefix("k"):
					/* We're treating a standard string item */
					filenameToComponents[filename]!.appendContentsOf(spaces)
					if let v = value[languageName] {
						filenameToComponents[filename]!.append(AndroidXMLLocFile.StringValue(key: k.substringFromIndex(k.startIndex.successor()), value: v))
					} else {
						print("*** Warning: Didn't get a value for language \(languageName) for key \(k)")
					}
				case let k where k.hasPrefix("K"):
					/* We're treating a CDATA string item */
					filenameToComponents[filename]!.appendContentsOf(spaces)
					if let v = value[languageName] {
						filenameToComponents[filename]!.append(AndroidXMLLocFile.StringValue(key: k.substringFromIndex(k.startIndex.successor()), cDATAValue: v))
					} else {
						print("*** Warning: Didn't get a value for language \(languageName) for key \(k)")
					}
				case let k where k.hasPrefix("a"):
					/* We're treating an array item */
					filenameToComponents[filename]!.appendContentsOf(spaces)
					if let v = value[languageName] {
						let noA = k.substringFromIndex(k.startIndex.successor())
						let sepByQuote = noA.componentsSeparatedByString("\"")
						if sepByQuote.count == 2 {
							if let idx = Int(sepByQuote[1]) {
								filenameToComponents[filename]!.append(AndroidXMLLocFile.ArrayItem(value: v, index: idx, parentName: sepByQuote[0]))
							} else {
								print("*** Warning: Invalid key '\(k)': cannot find idx")
							}
						} else {
							print("*** Warning: Got invalid array item key '\(k)'")
						}
					} else {
						print("*** Warning: Didn't get a value for language \(languageName) for key \(k)")
					}
				case let k where k.hasPrefix("p") || k.hasPrefix("P"):
					let isCData = k.hasPrefix("P")
					/* We're treating a plural item */
					if let v = value[languageName] where v != "--" && currentPluralsValueByFilename[filename] != nil {
						let noP = k.substringFromIndex(k.startIndex.successor())
						let sepByQuote = noP.componentsSeparatedByString("\"")
						if sepByQuote.count == 2 {
							let quantity = sepByQuote[1]
							let p = isCData ?
								AndroidXMLLocFile.PluralGroup.PluralItem(quantity: quantity, cDATAValue: v) :
								AndroidXMLLocFile.PluralGroup.PluralItem(quantity: quantity, value: v)
							
							if currentPluralsValueByFilename[filename]![quantity] != nil {
								print("*** Warning: Got multiple plurals value for quantity '\(quantity)' (key: '\(k)')")
							}
							currentPluralsValueByFilename[filename]![quantity] = (spaces, p)
						} else {
							print("*** Warning: Got invalid plural key '\(k)' (either malformed or misplaced)")
						}
					} else {
						if value[languageName] == nil {
							print("*** Warning: Didn't get a value for language \(languageName) for key \(k)")
						}
					}
				default:
					print("*** Warning: Got invalid key \(entry_key.locKey)")
				}
			}
			
			spaces.removeAll()
		}
		for (filename, components) in filenameToComponents {
			let locFile = AndroidXMLLocFile(pathRelativeToProject: filename, components: components)
			let fullOutputPath = (rootPath as NSString).stringByAppendingPathComponent(locFile.filepath)
			
			var xmlText = ""
			print(locFile, terminator: "", toStream: &xmlText)
			var err: NSError?
			do {
				try writeText(xmlText, toFile: fullOutputPath, usingEncoding: NSUTF8StringEncoding)
			} catch let error as NSError {
				err = error
				print("Error: Cannot write file to path \(fullOutputPath), got error \(err)")
			}
		}
	}
	
	func writeTo<Target : OutputStreamType>(inout target: Target) {
		target.write(
			"\(PRIVATE_KEY_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
			"\(PRIVATE_ENV_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
			"\(PRIVATE_FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
			"\(PRIVATE_COMMENT_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
			"\(PRIVATE_MAPPINGS_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))"
		)
		target.write(
			"\(csvSeparator)\(FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))" +
			"\(csvSeparator)\(COMMENT_HEADER_NAME.csvCellValueWithSeparator(csvSeparator))"
		)
		for language in languages {
			target.write("\(csvSeparator)\(language.csvCellValueWithSeparator(csvSeparator))")
		}
		target.write("\n")
		var previousBasename: String?
		for entry_key in entries.keys.sort() {
			let value = entries[entry_key]!
			
			var basename = entry_key.filename
			if let slashRange = basename.rangeOfString("/", options: NSStringCompareOptions.BackwardsSearch) {
				if slashRange.startIndex != basename.endIndex {
					basename = basename.substringFromIndex(slashRange.startIndex.successor())
				}
			}
			if basename.hasSuffix(".xml") {basename = (basename as NSString).stringByDeletingPathExtension}
			if basename.hasSuffix(".strings") {basename = (basename as NSString).stringByDeletingPathExtension}
			
			if basename != previousBasename {
				previousBasename = basename
				target.write("\n")
				target.write("\(csvSeparator)\(csvSeparator)\(csvSeparator)\(csvSeparator)\(csvSeparator)")
				target.write(("\\o/ \\o/ \\o/ " + previousBasename! + " \\o/ \\o/ \\o/").csvCellValueWithSeparator(csvSeparator))
				target.write("\(csvSeparator)\n")
			}
			
			/* Writing group comment */
			if !entry_key.userReadableGroupComment.isEmpty {
				target.write("\(csvSeparator)\(csvSeparator)\(csvSeparator)\(csvSeparator)\(csvSeparator)\(csvSeparator)")
				target.write(entry_key.userReadableGroupComment.csvCellValueWithSeparator(csvSeparator))
				target.write("\n")
			}
			
			let mappingStr = mappings[entry_key]?.stringRepresentation() ?? ""
			let comment = "__" + entry_key.comment + "__" /* Adding text in front and at the end so editors won't fuck up the csv */
			target.write(
				"\(entry_key.locKey.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
				"\(entry_key.env.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
				"\(entry_key.filename.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
				"\(comment.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
				"\(mappingStr.csvCellValueWithSeparator(csvSeparator))"
			)
			target.write(
				"\(csvSeparator)\(basename.csvCellValueWithSeparator(csvSeparator))" +
				"\(csvSeparator)\(entry_key.userReadableComment.csvCellValueWithSeparator(csvSeparator))"
			)
			for language in languages {
				if let languageValue = value[language] {
					target.write("\(csvSeparator)\(languageValue.csvCellValueWithSeparator(csvSeparator))")
				} else {
					let value = "TODOLOC"
					target.write("\(csvSeparator)\(value.csvCellValueWithSeparator(csvSeparator))")
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
		
		if languages.indexOf(languageName) == nil {
			languages.append(languageName)
			languages.sortInPlace()
		}
		
		return (filenameNoLproj, languageName)
	}
	
	private func getKeyFrom(refKey: LineKey, useNonEmptyCommentIfOneEmptyTheOtherNot: Bool, inout withListOfKeys keys: [LineKey]) -> LineKey {
		if let idx = keys.indexOf(refKey) {
			if keys[idx].comment != refKey.comment {
				if useNonEmptyCommentIfOneEmptyTheOtherNot && (keys[idx].comment.characters.count == 0 || refKey.comment.characters.count == 0) {
					/* We use the non-empty comment because one of the two comments
					 * compared is empty; the other not (both are different and one
					 * of them is empty) */
					if keys[idx].comment.characters.count == 0 {
						let newKey = LineKey(
							locKey: keys[idx].locKey, env: keys[idx].env, filename: keys[idx].filename,
							comment: refKey.comment, index: keys[idx].index,
							userReadableGroupComment: refKey.userReadableGroupComment,
							userReadableComment: refKey.userReadableComment
						)
						keys[idx] = newKey
					}
				} else {
					print("*** Warning: Got different comment for same loc key \"\(refKey.locKey)\" (file \(refKey.filename)): \"\(keys[idx].comment)\" and \"\(refKey.comment)\"")
				}
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

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



private extension String {
	func csvCellValueWithSeparator(_ sep: String) -> String {
		if sep.characters.count != 1 {NSException(name: NSExceptionName(rawValue: "Invalid Separator"), reason: "Cannot use \"\(sep)\" as a CSV separator", userInfo: nil).raise()}
		if rangeOfCharacter(from: CharacterSet(charactersIn: "\(sep)\"\n\r")) != nil {
			/* Double quotes needed */
			let doubledDoubleQuotes = replacingOccurrences(of: "\"", with: "\"\"")
			return "\"\(doubledDoubleQuotes)\""
		} else {
			/* Double quotes not needed */
			return self
		}
	}
}

/* *******
   MARK: -
   ******* */

class happnCSVLocFile: Streamable {
	
	let csvSeparator: String
	private var metadata: [String: String]
	
	private(set) var languages: [String]
	private var entries: [LineKey: LineValue]
	var entryKeys: [LineKey] {
		return Array(entries.keys)
	}
	
	/* *******************************************************
	   MARK: - LineKey Struct
	           Key for each entries in the happn CSV loc file.
	   ******************************************************* */
	
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
	
	/* ***********************************************************
	   MARK: - LineValue Enum
	           Either a mapping or a dictionary of language/value.
	   *********************************************************** */
	
	enum LineValue {
		case mapping(happnCSVLocKeyMapping)
		case entries([String /* Language */: String /* Value */])
		
		var mapping: happnCSVLocKeyMapping? {
			switch self {
			case .mapping(let mapping): return mapping
			default:                    return nil
			}
		}
		
		var entries: [String: String]? {
			switch self {
			case .entries(let entries): return entries
			default:                    return nil
			}
		}
		
		/* Crashes the compiler (Xcode 8b3 (8S174q) with default Swift).
		 * Fortunately I don't really need this method... */
//		func entryForLanguage(_ language: String) -> String? {
//			guard let entries = entries else {return nil}
//			return entries[language]
//		}
	}
	
	/* *******************
	   MARK: - Key Mapping
	   ******************* */
	
	class happnCSVLocKeyMapping {
		
		let originalStringRepresentation: String
		var components: [happnCSVLocKeyMappingComponent]?
		
		/** Inits a happn CSV Loc Key Mapping from a string representation (JSON).
		
		If the string is empty, returns nil.
		
		If the string representation is invalid (invalid JSON, etc.), a fully
		inited object is returned with nil components. */
		convenience init?(stringRepresentation: String) {
			guard !stringRepresentation.isEmpty else {return nil}
			
			guard
				let data = stringRepresentation.data(using: String.Encoding.utf8),
				let serializedComponent_s = try? JSONSerialization.jsonObject(with: data, options: [])
				else
			{
				print("*** Warning: Invalid mapping; cannot serialize JSON string: \"\(stringRepresentation)\"")
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
			
			self.init(components: serializedComponents.map {happnCSVLocKeyMappingComponent.createCSVLocKeyMappingFromSerialization($0)}, stringRepresentation: stringRepresentation)
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
		
		private static func stringRepresentationFromComponentsList(_ components: [happnCSVLocKeyMappingComponent]) -> String {
			let allSerialized = components.map {$0.serialize()}
			return try! String(
				data: JSONSerialization.data(
					withJSONObject: (allSerialized.count == 1 ? allSerialized[0] as AnyObject : allSerialized as AnyObject),
					options: [.prettyPrinted]
				),
				encoding: String.Encoding.utf8
			)!
		}
		
	}
	
	/* ********************
	   MARK: - Initializers
	   ******************** */
	
	convenience init() {
		self.init(languages: [], entries: [:], metadata: [:], csvSeparator: ",")
	}
	
	/* *** Init from path *** */
	convenience init(fromPath path: String, withCSVSeparator csvSep: String) throws {
		var encoding: UInt = 0
		var filecontent: String?
		if FileManager.default.fileExists(atPath: path) {
			filecontent = try NSString(contentsOfFile: path, usedEncoding: &encoding) as String
		}
		try self.init(filecontent: (filecontent != nil ? filecontent! : ""), withCSVSeparator: csvSep)
	}
	
	/* *** Init with file content *** */
	convenience init(filecontent: String, withCSVSeparator csvSep: String) throws {
		let defaultError = NSError(domain: "Migrator", code: 1, userInfo: nil)
		if filecontent.isEmpty {
			self.init(languages: [], entries: [:], metadata: [:], csvSeparator: csvSep)
			return
		}
		
		let parser = CSVParser(source: filecontent, separator: csvSep, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw defaultError
		}
		
		var metadata = [String: String]()
		var languages = [String]()
		var entries = [LineKey: LineValue]()
		
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
		var foundEmptyLine = false
		for row in parsedRows {
			/* Is the row empty? The first empty row signal the start of the actual
			 * data (metadata/data separation). */
			guard row != [:] else {foundEmptyLine = true; continue}
			
			/* If we did not find the empty line, we're still in the metadata. */
			guard foundEmptyLine else {
				if
					let jsonData = row[PRIVATE_KEY_HEADER_NAME]?.data(using: String.Encoding.utf8),
					let parsedJSON = (try? JSONSerialization.jsonObject(with: jsonData, options: [])) as? [String: String]
				{
					if !metadata.isEmpty {print("*** Warning: Got more than one line of metadata. Merging values, last line wins if key is defined more than once.")}
					parsedJSON.forEach {metadata[$0] = $1}
				}
				continue
			}
			
			/* An empty line has been found. We're in the actual data. */
			guard
				let locKey              = row[PRIVATE_KEY_HEADER_NAME],
				let env                 = row[PRIVATE_ENV_HEADER_NAME],
				let filename            = row[PRIVATE_FILENAME_HEADER_NAME],
				let rawComment          = row[PRIVATE_COMMENT_HEADER_NAME],
				let userReadableComment = row[COMMENT_HEADER_NAME]
				else
			{
				print("*** Warning: Invalid row \(row) found in csv file. Ignoring this row.")
				continue
			}
			
			/* Does the row have a valid environment? */
			if env.isEmpty {
				/* If the environment is empty, we may have a group comment row */
				groupComment = userReadableComment
				continue
			}
			
			/* Let's get the comment */
			var comment: String
			if rawComment.hasPrefix("__") && rawComment.hasSuffix("__") {
				comment = rawComment.replacingOccurrences(
					of: "__", with: "", options: NSString.CompareOptions.anchored
				).replacingOccurrences(
					of: "__", with: "", options: [NSString.CompareOptions.anchored, NSString.CompareOptions.backwards]
				)
			} else {
				print("*** Warning: Got comment \"\(rawComment)\" which does not have the __ prefix and suffix. Setting raw comment as comment, but expect troubles.")
				comment = rawComment
			}
			
			/* Let's create the line key */
			let k = LineKey(
				locKey: locKey,
				env: env,
				filename: filename,
				comment: comment,
				index: i,
				userReadableGroupComment: groupComment,
				userReadableComment: userReadableComment
			)
			i += 1
			groupComment = ""
			
			if let mappingStr = row[PRIVATE_MAPPINGS_HEADER_NAME], let mapping = happnCSVLocKeyMapping(stringRepresentation: mappingStr) {
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
	
	/* *** Init *** */
	init(languages l: [String], entries e: [LineKey: LineValue], metadata md: [String: String], csvSeparator csvSep: String) {
		if csvSep.characters.count != 1 {NSException(name: NSExceptionName(rawValue: "Invalid Separator"), reason: "Cannot use \"\(csvSep)\" as a CSV separator", userInfo: nil).raise()}
		csvSeparator = csvSep
		languages = l
		entries = e
		metadata = md
	}
	
	/* *******************************************
	   MARK: - Manual Modification of CSV Loc File
	   ******************************************* */
	
	func lineValueForKey(_ key: LineKey) -> LineValue? {
		return entries[key]
	}
	
	func resolvedValueForKey(_ key: LineKey, withLanguage language: String) -> String {
		let defaultValue = "TODOLOC"
		guard let v = entries[key] else {return defaultValue}
		switch v {
		case .entries(let entries): return entries[language] ?? defaultValue
		case .mapping(_): return "TODO: MAPPING RESOLVING"
		}
	}
	
	/** Sets the given value for the given key and language.
	
	- important: If the key had a mapping, the mapping is **dropped**.
	
	- returns: `true` if the key had to be added to the list of entries, `false`
	if the key was already present and was only modified. */
	func setValue(_ val: String, forKey key: LineKey, withLanguage language: String) -> Bool {
		let created: Bool
		var entriesForKey: [String: String]
		if case .some(.entries(let e)) = entries[key] {created = false;               entriesForKey = e}
		else                                          {created = entries[key] == nil; entriesForKey = [:]}
		entriesForKey[language] = val
		entries[key] = .entries(entriesForKey)
		return created
	}
	
	func stringMetadataValueForKey(_ key: String) -> String? {
		return metadata[key]
	}
	
	func intMetadataValueForKey(_ key: String) -> Int? {
		guard let strVal = metadata[key] else {return nil}
		return Int(strVal)
	}
	
	func setMetadataValue(_ value: String, forKey key: String) {
		metadata[key] = value
	}
	
	func setMetadataValue(_ value: Int, forKey key: String) {
		metadata[key] = String(value)
	}
	
	/* ***********************************
	   MARK: - Xcode Strings Files Support
	   *********************************** */
	
	func mergeXcodeStringsFiles(_ stringsFiles: [XcodeStringsFile], folderNameToLanguageName: [String: String]) {
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
						locKey: (locString.keyHasQuotes ? "'" : "#")+locString.key, env: env, filename: filenameNoLproj, comment: locString.equal+";"+locString.semicolon+currentComment, index: index,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if setValue(locString.value, forKey: key, withLanguage: languageName) {index += 1}
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				default:
					print("Got unknown XcodeStringsFile component \(component)")
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
	
	func exportToXcodeProjectWithRoot(_ rootPath: String, folderNameToLanguageName: [String: String]) {
		var filenameToComponents = [String: [XcodeStringsComponent]]()
		for entry_key in entries.keys.sorted() {
			guard entry_key.env == "Xcode" else {continue}
			
			var scannedString: NSString?
			let keyScanner = Scanner(string: entry_key.locKey)
			keyScanner.charactersToBeSkipped = CharacterSet() /* No characters should be skipped. */
			
			/* Let's see if the key has quotes */
			if !keyScanner.scanCharacters(from: CharacterSet(charactersIn: "'#"), into: &scannedString) {
				print("*** Warning: Got invalid key \(entry_key.locKey)")
				continue
			}
			/* If the key in CSV file begins with a simple quotes, the Xcode key has double-quotes */
			let keyHasQuotes = (scannedString == "'")
			/* Let's get the Xcode original key */
			if !keyScanner.scanUpTo("", into: &scannedString) {
				print("*** Warning: Got invalid key \(entry_key.locKey): Cannot scan original key")
				continue
			}
			let k = scannedString!
			
			/* Now let's parse the comment to get the equal and semicolon strings */
			let commentScanner = Scanner(string: entry_key.comment)
			commentScanner.charactersToBeSkipped = CharacterSet() /* No characters should be skipped. */
			
			/* Getting equal string */
			var equalString = ""
			if commentScanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: &scannedString) {
				if let white = scannedString {equalString += white as String}
			}
			if !commentScanner.scanString("=", into: nil) {
				print("*** Warning: Got invalid key \(entry_key.locKey): No equal sign in equal string")
				continue
			}
			equalString += "="
			if commentScanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: &scannedString) {
				if let white = scannedString {equalString += white as String}
			}
			
			/* Separator between equal and semicolon strings */
			if !commentScanner.scanString(";", into: nil) {
				print("*** Warning: Got invalid key \(entry_key.locKey): Character after equal string is not a semicolon")
				continue
			}
			
			/* Getting semicolon string */
			var semicolonString = ""
			if commentScanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: &scannedString) {
				if let white = scannedString {semicolonString += white as String}
			}
			if !commentScanner.scanString(";", into: nil) {
				print("*** Warning: Got invalid key \(entry_key.locKey): No semicolon sign in semicolon string")
				continue
			}
			semicolonString += ";"
			
			var commentComponents = [XcodeStringsComponent]()
			while !commentScanner.isAtEnd {
				var white: NSString?
				if commentScanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: &white) {
					commentComponents.append(XcodeStringsFile.WhiteSpace(white! as String))
				}
				if commentScanner.scanString("/*", into: nil) {
					var comment: NSString?
					if commentScanner.scanUpTo("*/", into: &comment) && !commentScanner.isAtEnd {
						commentComponents.append(XcodeStringsFile.Comment(comment! as String))
						commentScanner.scanString("*/", into: nil)
						if commentScanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: &white) {
							commentComponents.append(XcodeStringsFile.WhiteSpace(white! as String))
						}
					}
				}
			}
			
			for (folderName, languageName) in folderNameToLanguageName {
				let filename = entry_key.filename.replacingOccurrences(of: "//LANGUAGE//", with: "/"+folderName+"/")
				if filenameToComponents[filename] == nil {
					filenameToComponents[filename] = [XcodeStringsComponent]()
				}
				
				filenameToComponents[filename]! += commentComponents
				
				filenameToComponents[filename]!.append(XcodeStringsFile.LocalizedString(
					key: k as String,
					keyHasQuotes: keyHasQuotes,
					equalSign: equalString,
					value: resolvedValueForKey(entry_key, withLanguage: languageName),
					andSemicolon: semicolonString
				))
			}
		}
		
		for (filename, components) in filenameToComponents {
			let locFile = XcodeStringsFile(filepath: filename, components: components)
			let fullOutputPath = (rootPath as NSString).appendingPathComponent(locFile.filepath)
			
			var stringsText = ""
			print(locFile, terminator: "", to: &stringsText)
			var err: NSError?
			do {
				try writeText(stringsText, toFile: fullOutputPath, usingEncoding: String.Encoding.utf16)
			} catch let error as NSError {
				err = error
				print("Error: Cannot write file to path \(fullOutputPath), got error \(err)")
			}
		}
	}
	
	/* ***************************************
	   MARK: - Android XML Loc Strings Support
	   *************************************** */
	
	func mergeAndroidXMLLocStringsFiles(_ locFiles: [AndroidXMLLocFile], folderNameToLanguageName: [String: String]) {
		var index = 0
		
		let originalEntries = entries
		entries = [:]
		
		let env = "Android"
		var keys = [LineKey]()
		for locFile in locFiles {
			let (filenameNoLanguage, languageName) = getLanguageAgnosticFilenameAndAddLanguageToList(locFile.filepath, withMapping: folderNameToLanguageName)
			
			var currentComment = ""
			var currentUserReadableComment = ""
			var currentUserReadableGroupComment = ""
			
			func handleWhiteSpace(_ whiteSpace: AndroidXMLLocFile.WhiteSpace) {
				if whiteSpace.stringValue.range(of: "\n\n", options: NSString.CompareOptions.literal) != nil && !currentUserReadableComment.isEmpty {
					if !currentUserReadableGroupComment.isEmpty {
						currentUserReadableGroupComment += "\n\n\n"
					}
					currentUserReadableGroupComment += currentUserReadableComment
					currentUserReadableComment = ""
				}
				currentComment += whiteSpace.stringValue
			}
			
			func handleComment(_ comment: AndroidXMLLocFile.Comment) {
				if !currentUserReadableComment.isEmpty {currentUserReadableComment += "\n"}
				currentUserReadableComment += comment.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: "\n * ", with: "\n", options: NSString.CompareOptions.literal)
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
						locKey: "o"+groupOpening.fullString, env: env, filename: filenameNoLanguage, comment: currentComment, index: index,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if setValue("--", forKey: key, withLanguage: languageName) {index += 1}
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let groupClosing as AndroidXMLLocFile.GenericGroupClosing:
					let refKey = LineKey(
						locKey: "c"+groupClosing.groupName+(groupClosing.nameAttr != nil ? " "+groupClosing.nameAttr! : ""),
						env: env, filename: filenameNoLanguage, comment: currentComment, index: index,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if setValue("--", forKey: key, withLanguage: languageName) {index += 1}
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let locString as AndroidXMLLocFile.StringValue:
					let refKey = LineKey(
						locKey: (!locString.isCDATA ? "k" : "K") + locString.key, env: env, filename: filenameNoLanguage, comment: currentComment, index: index,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if setValue(locString.value, forKey: key, withLanguage: languageName) {index += 1}
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let arrayItem as AndroidXMLLocFile.ArrayItem:
					let refKey = LineKey(
						locKey: "a"+arrayItem.parentName+"\""+String(arrayItem.idx), env: env, filename: filenameNoLanguage, comment: currentComment, index: index,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if setValue(arrayItem.value, forKey: key, withLanguage: languageName) {index += 1}
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
				case let pluralGroup as AndroidXMLLocFile.PluralGroup:
					let refKey = LineKey(
						locKey: "s"+pluralGroup.name, env: env, filename: filenameNoLanguage, comment: currentComment, index: index,
						userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
					)
					let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
					if setValue("--", forKey: key, withLanguage: languageName) {index += 1}
					currentComment = ""
					currentUserReadableComment = ""
					currentUserReadableGroupComment = ""
					for quantity in ["zero", "one", "two", "few", "many", "other"] {
						if let info = pluralGroup.values[quantity], let (spaces, _) = info {
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
							locKey: prefix+pluralGroup.name+"\""+quantity, env: env, filename: filenameNoLanguage, comment: currentComment, index: index,
							userReadableGroupComment: currentUserReadableGroupComment, userReadableComment: currentUserReadableComment
						)
						let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: true, withListOfKeys: &keys)
						if setValue((pluralItem?.value ?? "--"), forKey: key, withLanguage: languageName) {index += 1}
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
			/* Dropping keys not in given strings files. */
			guard refKey.env != env || keys.contains(refKey) else {continue}
			
			let key = getKeyFrom(refKey, useNonEmptyCommentIfOneEmptyTheOtherNot: false, withListOfKeys: &keys)
			entries[key] = val
		}
	}
	
	func exportToAndroidProjectWithRoot(_ rootPath: String, folderNameToLanguageName: [String: String]) {
		var filenameToComponents = [String: [AndroidLocComponent]]()
		var spaces = [AndroidLocComponent /* Only WhiteSpace and Comment */]()
		var currentPluralsValueByFilename: [String /* Language */: [String /* Quantity */: ([AndroidLocComponent /* Only WhiteSpace and Comment */], AndroidXMLLocFile.PluralGroup.PluralItem)?]] = [:]
		for entry_key in entries.keys.sorted() {
			guard entry_key.env == "Android" else {continue}
			
			if !entry_key.comment.isEmpty {
				var white: NSString?
				let scanner = Scanner(string: entry_key.comment)
				scanner.charactersToBeSkipped = CharacterSet()
				if scanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: &white) {
					spaces.append(AndroidXMLLocFile.WhiteSpace(white! as String))
				}
				if scanner.scanString("<!--", into: nil) {
					var comment: NSString?
					if scanner.scanUpTo("-->", into: &comment) && !scanner.isAtEnd {
						spaces.append(AndroidXMLLocFile.Comment(comment! as String))
						scanner.scanString("-->", into: nil)
						if scanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines, into: &white) {
							spaces.append(AndroidXMLLocFile.WhiteSpace(white! as String))
						}
					}
				}
				if !scanner.isAtEnd {
					print("*** Warning: Got invalid comment \"\(entry_key.comment)\"")
				}
			}
			
			for (folderName, languageName) in folderNameToLanguageName {
				let filename = entry_key.filename.replacingOccurrences(of: "//LANGUAGE//", with: "/"+folderName+"/")
				if filenameToComponents[filename] == nil {
					filenameToComponents[filename] = [AndroidLocComponent]()
				}
				
				switch entry_key.locKey {
				case let k where k.hasPrefix("o"):
					/* We're treating a group opening */
					filenameToComponents[filename]!.append(contentsOf: spaces)
					filenameToComponents[filename]!.append(AndroidXMLLocFile.GenericGroupOpening(fullString: k.substring(from: k.characters.index(after: k.startIndex))))
				case let k where k.hasPrefix("s"):
					/* We're treating a plural group opening */
					filenameToComponents[filename]!.append(contentsOf: spaces)
					currentPluralsValueByFilename[filename] = [:]
				case let k where k.hasPrefix("c"):
					/* We're treating a group closing */
					let noC = k.substring(from: k.characters.index(after: k.startIndex))
					let sepBySpace = noC.components(separatedBy: " ")
					if let plurals = currentPluralsValueByFilename[filename] {
						/* We have a plural group being contructed. We've reached it's
						 * closing component: let's add the finished plural to the
						 * components. */
						if sepBySpace.count == 2 && sepBySpace[0] == "plurals" {
							filenameToComponents[filename]!.append(AndroidXMLLocFile.PluralGroup(name: sepBySpace[1], values: plurals))
						} else {
							print("*** Warning: Got invalid plural closing key \(k). Dropping whole plurals group.")
						}
						currentPluralsValueByFilename.removeValue(forKey: filename)
					}
					filenameToComponents[filename]!.append(contentsOf: spaces)
					if sepBySpace.count > 0 && sepBySpace.count <= 2 {
						filenameToComponents[filename]!.append(AndroidXMLLocFile.GenericGroupClosing(groupName: sepBySpace[0], nameAttributeValue: (sepBySpace.count > 1 ? sepBySpace[1] : nil)))
					} else {
						print("*** Warning: Got invalid closing key \(k)")
					}
				case let k where k.hasPrefix("k"):
					/* We're treating a standard string item */
					filenameToComponents[filename]!.append(contentsOf: spaces)
					let v = resolvedValueForKey(entry_key, withLanguage: languageName)
					filenameToComponents[filename]!.append(AndroidXMLLocFile.StringValue(key: k.substring(from: k.characters.index(after: k.startIndex)), value: v))
				case let k where k.hasPrefix("K"):
					/* We're treating a CDATA string item */
					filenameToComponents[filename]!.append(contentsOf: spaces)
					let v = resolvedValueForKey(entry_key, withLanguage: languageName)
					filenameToComponents[filename]!.append(AndroidXMLLocFile.StringValue(key: k.substring(from: k.characters.index(after: k.startIndex)), cDATAValue: v))
				case let k where k.hasPrefix("a"):
					/* We're treating an array item */
					filenameToComponents[filename]!.append(contentsOf: spaces)
					let v = resolvedValueForKey(entry_key, withLanguage: languageName)
					let noA = k.substring(from: k.characters.index(after: k.startIndex))
					let sepByQuote = noA.components(separatedBy: "\"")
					if sepByQuote.count == 2 {
						if let idx = Int(sepByQuote[1]) {
							filenameToComponents[filename]!.append(AndroidXMLLocFile.ArrayItem(value: v, index: idx, parentName: sepByQuote[0]))
						} else {
							print("*** Warning: Invalid key '\(k)': cannot find idx")
						}
					} else {
						print("*** Warning: Got invalid array item key '\(k)'")
					}
				case let k where k.hasPrefix("p") || k.hasPrefix("P"):
					let isCData = k.hasPrefix("P")
					/* We're treating a plural item */
					let v = resolvedValueForKey(entry_key, withLanguage: languageName)
					if v != "--" && currentPluralsValueByFilename[filename] != nil {
						let noP = k.substring(from: k.characters.index(after: k.startIndex))
						let sepByQuote = noP.components(separatedBy: "\"")
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
					}
				default:
					print("*** Warning: Got invalid key \(entry_key.locKey)")
				}
			}
			
			spaces.removeAll()
		}
		for (filename, components) in filenameToComponents {
			let locFile = AndroidXMLLocFile(pathRelativeToProject: filename, components: components)
			let fullOutputPath = (rootPath as NSString).appendingPathComponent(locFile.filepath)
			
			var xmlText = ""
			print(locFile, terminator: "", to: &xmlText)
			var err: NSError?
			do {
				try writeText(xmlText, toFile: fullOutputPath, usingEncoding: String.Encoding.utf8)
			} catch let error as NSError {
				err = error
				print("Error: Cannot write file to path \(fullOutputPath), got error \(err)")
			}
		}
	}
	
	/* ***************************************
	   MARK: - Reference Translations Loc File
	   *************************************** */
	
	func replaceReferenceTranslationsWithLocFile(_ locFile: ReferenceTranslationsLocFile) {
		for key in entries.keys {
			guard key.env == "RefLoc" else {continue}
			entries.removeValue(forKey: key)
		}
		
		/* Adding languages in reference translations. But not removing languages
		 * not in reference translations! */
		for l in locFile.languages {
			if !languages.contains(l) {
				languages.append(l)
			}
		}
		
		var isFirst = true
		for (refKey, refVals) in locFile.entries {
			let key = LineKey(locKey: refKey, env: "RefLoc", filename: "ReferencesTranslations.csv", comment: "", index: isFirst ? 0 : 1, userReadableGroupComment: isFirst ? "••••••••••••••••••••••••••••••••••••• START OF REF TRADS — DO NOT MODIFY •••••••••••••••••••••••••••••••••••••" : "", userReadableComment: "REF TRAD. DO NOT MODIFY.")
			entries[key] = .entries(refVals)
			isFirst = false
		}
	}
	
	/* *********************************
	   MARK: - Streamable Implementation
	   ********************************* */
	
	func write<Target : TextOutputStream>(to target: inout Target) {
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
		if !metadata.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: []), let jsonStr = String(data: jsonData, encoding: String.Encoding.utf8) {
			/* Let's write the metadata */
			target.write("\n\(jsonStr.csvCellValueWithSeparator(csvSeparator))")
		}
		target.write("\n")
		var previousBasename: String?
		for entry_key in entries.keys.sorted() {
			let value = entries[entry_key]!
			
			var basename = entry_key.filename
			if let slashRange = basename.range(of: "/", options: NSString.CompareOptions.backwards) {
				if slashRange.lowerBound != basename.endIndex {
					basename = basename.substring(from: basename.index(after: slashRange.lowerBound))
				}
			}
			if basename.hasSuffix(".xml") {basename = (basename as NSString).deletingPathExtension}
			if basename.hasSuffix(".strings") {basename = (basename as NSString).deletingPathExtension}
			
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
			
			let comment = "__" + entry_key.comment + "__" /* Adding text in front and at the end so editors won't fuck up the csv */
			target.write(
				"\(entry_key.locKey.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
				"\(entry_key.env.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
				"\(entry_key.filename.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)" +
				"\(comment.csvCellValueWithSeparator(csvSeparator))\(csvSeparator)"
			)
			if case .mapping(let mapping) = value {target.write(csvSeparator + mapping.stringRepresentation().csvCellValueWithSeparator(csvSeparator))}
			target.write(
				"\(csvSeparator)\(basename.csvCellValueWithSeparator(csvSeparator))" +
				"\(csvSeparator)\(entry_key.userReadableComment.csvCellValueWithSeparator(csvSeparator))"
			)
			if case .entries(let entries) = value {
				for language in languages {
					target.write("\(csvSeparator)\((entries[language] ?? "TODOLOC").csvCellValueWithSeparator(csvSeparator))")
				}
			}
			target.write("\n")
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private func getLanguageAgnosticFilenameAndAddLanguageToList(_ filename: String, withMapping languageMapping: [String: String]) -> (String, String) {
		var found = false
		var languageName = "(Unknown)"
		var filenameNoLproj = filename
		
		for (fn, ln) in languageMapping {
			if let range = filenameNoLproj.range(of: "/" + fn + "/") {
				assert(!found)
				found = true
				
				languageName = ln
				filenameNoLproj.replaceSubrange(range, with: "//LANGUAGE//")
			}
		}
		
		if languages.index(of: languageName) == nil {
			languages.append(languageName)
			languages.sort()
		}
		
		return (filenameNoLproj, languageName)
	}
	
	private func getKeyFrom(_ refKey: LineKey, useNonEmptyCommentIfOneEmptyTheOtherNot: Bool, withListOfKeys keys: inout [LineKey]) -> LineKey {
		if let idx = keys.index(of: refKey) {
			if keys[idx].comment != refKey.comment {
				if useNonEmptyCommentIfOneEmptyTheOtherNot && (keys[idx].comment.isEmpty || refKey.comment.isEmpty) {
					/* We use the non-empty comment because one of the two comments
					 * compared is empty; the other not (both are different and one
					 * of them is empty) */
					if keys[idx].comment.isEmpty {
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

/* *************************
   MARK: - LineKey Operators
   ************************* */

func ==(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	return k1.locKey == k2.locKey && k1.env == k2.env && k1.filename == k2.filename
}

func <=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	if k1.index    < k2.index    {return true}
	if k1.index    > k2.index    {return false}
	return k1.locKey <= k2.locKey
}

func >=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	if k1.index    > k2.index    {return true}
	if k1.index    < k2.index    {return false}
	return k1.locKey >= k2.locKey
}

func <(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	if k1.index    < k2.index    {return true}
	if k1.index    > k2.index    {return false}
	return k1.locKey < k2.locKey
}

func >(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	if k1.index    > k2.index    {return true}
	if k1.index    < k2.index    {return false}
	return k1.locKey > k2.locKey
}

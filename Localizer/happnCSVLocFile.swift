/*
 * happnCSVLocFile.swift
 * Localizer
 *
 * Created by François Lamboley on 9/26/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation
import os.log



private extension String {
	
	func csvCellValueWithSeparator(_ sep: String) -> String {
		guard sep.utf16.count == 1, sep != "\"", sep != "\n", sep != "\r" else {fatalError("Cannot use \"\(sep)\" as a CSV separator")}
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

public class happnCSVLocFile: TextOutputStreamable {
	
	public let csvSeparator: String
	private var metadata: [String: String]
	
	public internal(set) var languages: [String]
	var entries: [LineKey: LineValue]
	public var entryKeys: [LineKey] {
		return Array(entries.keys)
	}
	
	/* *******************************************************
	   MARK: - LineKey Struct
	           Key for each entries in the happn CSV loc file.
	   ******************************************************* */
	
	public struct LineKey: Equatable, Hashable, Comparable {
		public let locKey: String
		public let env: String
		public let filename: String
		
		/* Used when comparing for lt or gt, but not for equality */
		public let index: Int
		
		/* Not used when comparing line keys. Both keys are store in the "comment"
		 * column. We could (should?) use a json in its own column for the
		 * userInfo... but why do simply what can be done in a complicated way? */
		public let comment: String
		public let userInfo: [String: String]
		
		/* Not used when comparing line keys */
		public let userReadableGroupComment: String
		public let userReadableComment: String
		
		public init(locKey k: String, env e: String, filename f: String, index i: Int, comment c: String, userInfo ui: [String: String], userReadableGroupComment urgc: String, userReadableComment urc: String) {
			locKey = k
			env = e
			filename = f
			index = i
			comment = c
			userInfo = ui
			userReadableGroupComment = urgc
			userReadableComment = urc
		}
		
		static func parse(attributedComment: String) -> (comment: String, userInfo: [String: String]) {
			let (str, optionalUserInfo) = attributedComment.splitUserInfo()
			guard let userInfo = optionalUserInfo else {
				return (comment: attributedComment, userInfo: [:])
			}
			return (comment: str, userInfo: userInfo)
		}
		
		public var fullComment: String {
			return comment.byPrepending(userInfo: userInfo)
		}
		
		public var hashValue: Int {
			return locKey.hashValue &+ env.hashValue &+ filename.hashValue
		}
	}
	
	/* ***********************************************************
	   MARK: - LineValue Enum
	           Either a mapping or a dictionary of language/value.
	   *********************************************************** */
	
	public enum LineValue {
		case mapping(happnCSVLocKeyMapping)
		case entries([String /* Language */: String /* Value */])
		
		public var mapping: happnCSVLocKeyMapping? {
			switch self {
			case .mapping(let mapping): return mapping
			default:                    return nil
			}
		}
		
		public var entries: [String: String]? {
			switch self {
			case .entries(let entries): return entries
			default:                    return nil
			}
		}
		
		public func entryForLanguage(_ language: String) -> String? {
			guard let entries = entries else {return nil}
			return entries[language]
		}
	}
	
	/* *******************
	   MARK: - Filter Enum
	   ******************* */
	
	public enum Filter {
		case string(String)
		case env(String)
		case stateTodoloc, stateHardCodedValues, stateMappedValid, stateMappedInvalid
		
		public init?(string: String) {
			guard let first = string.first else {return nil}
			let substring = String(string.dropFirst())
			
			switch first {
			case "t":
				switch substring {
				case "t":  self = .stateTodoloc
				case "v":  self = .stateHardCodedValues
				case "mv": self = .stateMappedValid
				case "mi": self = .stateMappedInvalid
				default: return nil
				}
				
			case "s": self = .string(substring)
			case "e": self = .env(substring)
				
			default: return nil
			}
		}
		
		public func toString() -> String {
			switch self {
			case .string(let str):      return "s" + str
			case .env(let env):         return "e" + env
			case .stateTodoloc:         return "tt"
			case .stateHardCodedValues: return "tv"
			case .stateMappedValid:     return "tmv"
			case .stateMappedInvalid:   return "tmi"
			}
		}
		
		public var isStringFilter: Bool {
			guard case .string = self else {return false}
			return true
		}
		
		public var isEnvFilter: Bool {
			guard case .env = self else {return false}
			return true
		}
		
		public var isStateFilter: Bool {
			return !isStringFilter && !isEnvFilter
		}
	}
	
	/* ********************
	   MARK: - Initializers
	   ******************** */
	
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
		
		let warning = "todo: get rid of line below. it is kept currently for retrocompatibility with previous format which used to save metadata alongside the data"
		let (startOffset, decodedMetadata) = filecontent.infoForSplitUserInfo()
		
		let parser = CSVParser(source: filecontent, startOffset: startOffset, separator: csvSep, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw defaultError
		}
		
		var languages = [String]()
		var entries = [LineKey: LineValue]()
		
		/* Retrieving languages from header */
		for h in parser.fieldNames {
			if h != happnCSVLocFile.PRIVATE_KEY_HEADER_NAME && h != happnCSVLocFile.PRIVATE_ENV_HEADER_NAME && h != happnCSVLocFile.PRIVATE_FILENAME_HEADER_NAME &&
				h != happnCSVLocFile.PRIVATE_COMMENT_HEADER_NAME && h != happnCSVLocFile.PRIVATE_MAPPINGS_HEADER_NAME && h != happnCSVLocFile.FILENAME_HEADER_NAME &&
				h != happnCSVLocFile.COMMENT_HEADER_NAME {
				languages.append(h)
			}
		}
		
		var i = 0
		var groupComment = ""
		for row in parsedRows {
			/* We drop empty rows. */
			guard !row.reduce(true, { result, keyval in result && keyval.1 == "" }) else {continue}
			
			guard
				let locKey              = row[happnCSVLocFile.PRIVATE_KEY_HEADER_NAME],
				let env                 = row[happnCSVLocFile.PRIVATE_ENV_HEADER_NAME],
				let filename            = row[happnCSVLocFile.PRIVATE_FILENAME_HEADER_NAME],
				let rawComment          = row[happnCSVLocFile.PRIVATE_COMMENT_HEADER_NAME],
				let userReadableComment = row[happnCSVLocFile.COMMENT_HEADER_NAME]
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
				(comment, userInfo) = LineKey.parse(attributedComment: rawComment.replacingOccurrences(
					of: "__", with: "", options: NSString.CompareOptions.anchored
				).replacingOccurrences(
					of: "__", with: "", options: [NSString.CompareOptions.anchored, NSString.CompareOptions.backwards]
				))
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
			
			if let mappingStr = row[happnCSVLocFile.PRIVATE_MAPPINGS_HEADER_NAME], let mapping = happnCSVLocKeyMapping(stringRepresentation: mappingStr) {
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
		self.init(languages: languages, entries: entries, metadata: metadata ?? decodedMetadata ?? [:], csvSeparator: csvSep)
	}
	
	/* *** Init *** */
	init(languages l: [String], entries e: [LineKey: LineValue], metadata md: Any?, csvSeparator csvSep: String) {
		if csvSep.utf16.count != 1 {NSException(name: NSExceptionName(rawValue: "Invalid Separator"), reason: "Cannot use \"\(csvSep)\" as a CSV separator", userInfo: nil).raise()}
		csvSeparator = csvSep
		languages = l
		entries = e
		metadata = md as? [String: String] ?? [:]
	}
	
	/* *******************************************
	   MARK: - Manual Modification of CSV Loc File
	   ******************************************* */
	
	func hasEntryKey(_ key: LineKey) -> Bool {
		return (entries[key] != nil)
	}
	
	public func entryKeys(matchingFilters filters: [Filter]) -> [LineKey] {
		let stringFilters = filters.flatMap{ filter -> String? in
			if case .string(let str) = filter, !str.isEmpty {return str}
			return nil
		}
		let envFilters = filters.flatMap{ filter -> String? in
			if case .env(let env) = filter {return env}
			return nil
		}
		let stateFilters = filters.filter{ $0.isStateFilter }
		
		guard !envFilters.isEmpty && !stateFilters.isEmpty else {
			return []
		}
		
		return entryKeys.filter{ lineKey -> Bool in
			/* Filter env */
			guard envFilters.contains(lineKey.env) else {return false}
			
			/* Filter state */
			/* TODO: State filters... */
			
			/* Search filter */
			if !stringFilters.isEmpty {
				for stringFilter in stringFilters {
					let stringComponents = stringFilter.components(separatedBy: ",")
					let keyFilter: String?
					let contentFilter: String
					if let filter = stringComponents.last, stringComponents.count > 1 {
						keyFilter = filter.isEmpty ? nil : filter
						contentFilter = stringComponents[0..<stringComponents.count-2].joined(separator: ",")
					} else {
						keyFilter = nil
						contentFilter = stringFilter
					}
					var keyOk = true
					if let keyFilter = keyFilter {
						keyOk = false
						for k in [lineKey.locKey, lineKey.filename] {
							if k.range(of: keyFilter, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil {
								keyOk = true
								break
							}
						}
					}
					guard keyOk else {return false}
					guard !contentFilter.isEmpty else {return true}
					for l in self.languages {
						let str = editorDisplayedValueForKey(lineKey, withLanguage: l)
						if str.range(of: contentFilter, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil {
							return true
						}
					}
				}
				return false
			}
			return true
		}
	}
	
	public func lineValueForKey(_ key: LineKey) -> LineValue? {
		return entries[key]
	}
	
	func exportedValueForKey(_ key: LineKey, withLanguage language: String) -> String? {
		let v = editorDisplayedValueForKey(key, withLanguage: language).replacingOccurrences(of: "\n", with: "\\n")
		return (v != "---" ? v : nil)
	}
	
	enum ValueResolvingError : Error {
		case keyNotFound
		case noValue
	}
	
	public func editorDisplayedValueForKey(_ key: LineKey, withLanguage language: String) -> String {
		do {
			return try resolvedValueForKey(key, withLanguage: language)
		} catch _ as ValueResolvingError {
			return "!¡!TODOLOC!¡!"
		} catch let error as MappingResolvingError {
			switch error {
			case .invalidMapping, .mappedToMappedKey: return "!¡!TODOLOC_INVALIDMAPPING!¡!"
			case .keyNotFound:                        return "!¡!TODOLOC_MAPPINGKEYNOTFOUND!¡!"
			}
		} catch {
			return "!¡!TODOLOC_INTERNALLOCALIZERERROR!¡!"
		}
	}
	
	func resolvedValueForKey(_ key: LineKey, withLanguage language: String) throws -> String {
		guard let v = entries[key] else {throw ValueResolvingError.keyNotFound}
		switch v {
		case .entries(let entries):
			guard let r = entries[language] else {throw ValueResolvingError.noValue}
			return r
			
		case .mapping(let mapping):
			return try mapping.apply(forLanguage: language, entries: entries)
		}
	}
	
	/** Converts the given value for the given key to a hard-coded value. The
	previous mapping for the given key is then dropped (obviously).
	
	If the key was not present in the file, nothing is done.
	
	- returns: `true` if the value of the key was indeed a mapping and has been
	converted, `false` if nothing had to be done (value was already hard-coded or
	not present). */
	public func convertKeyToHardCoded(_ key: LineKey) -> Bool {
		guard case .mapping? = entries[key] else {
			return false
		}
		
		var values = [String: String]()
		for l in languages {
			values[l] = editorDisplayedValueForKey(key, withLanguage: l)
		}
		
		entries[key] = .entries(values)
		return true
	}
	
	/** Sets the given value for the given key and language.
	
	- important: If the key had a mapping, the mapping is **dropped**.
	
	- returns: `true` if the key had to be added to the list of entries, `false`
	if the key was already present and was only modified. */
	public func setValue(_ val: String, forKey key: LineKey, withLanguage language: String) -> Bool {
		let created: Bool
		var entriesForKey: [String: String]
		if case .entries(let e)? = entries[key] {created = false;               entriesForKey = e}
		else                                    {created = entries[key] == nil; entriesForKey = [:]}
		entriesForKey[language] = val
		entries[key] = .entries(entriesForKey)
		return created
	}
	
	/** Sets the given mapping for the given key.
	
	- important: All of the non-mapped values will be dropped for the given key.
	
	- returns: `true` if the key had to be added to the list of entries, `false`
	if the key was already present and was only modified. */
	func setValue(_ val: happnCSVLocKeyMapping, forKey key: LineKey) -> Bool {
		let created = (entries[key] == nil)
		entries[key] = .mapping(val)
		return created
	}
	
	/** Sets the given value for the given key.
	
	- returns: `true` if the key had to be added to the list of entries, `false`
	if the key was already present and was only modified. */
	public func setValue(_ val: LineValue, forKey key: LineKey) -> Bool {
		let created = (entries[key] == nil)
		entries[key] = val
		return created
	}
	
	public func stringMetadataValueForKey(_ key: String) -> String? {
		return metadata[key]
	}
	
	public func intMetadataValueForKey(_ key: String) -> Int? {
		guard let strVal = metadata[key] else {return nil}
		return Int(strVal)
	}
	
	public func filtersMetadataValueForKey(_ key: String) -> [Filter]? {
		guard let dataVal = metadata[key]?.data(using: .utf8), let filtersStr = (try? JSONSerialization.jsonObject(with: dataVal, options: [])) as? [String] else {return nil}
		return filtersStr.flatMap{ Filter(string: $0) }
	}
	
	public func setMetadataValue(_ value: String, forKey key: String) {
		metadata[key] = value
	}
	
	public func setMetadataValue(_ value: Int, forKey key: String) {
		metadata[key] = String(value)
	}
	
	public func setMetadataValue(_ value: [Filter], forKey key: String) throws {
		try setMetadataValue(value.map{ $0.toString() }, forKey: key)
	}
	
	public func setMetadataValue(_ value: Any, forKey key: String) throws {
		guard let str = String(data: try JSONSerialization.data(withJSONObject: value, options: []), encoding: .utf8) else {
			throw NSError(domain: "happnCSVLocFile set filters metadata value", code: 1, userInfo: nil)
		}
		metadata[key] = str
	}
	
	public func removeMetadata(forKey key: String) {
		metadata.removeValue(forKey: key)
	}
	
	public func serializedMetadata() -> Data {
		return Data("".byPrepending(userInfo: metadata).utf8)
	}
	
	/** Unserialize the given metadata. Should be used when initing an instance
	of `happnCSVLocFile`. */
	public static func unserializedMetadata(from serializedMetadata: Data) -> Any? {
		guard let strSerializedMetadata = String(data: serializedMetadata, encoding: .utf8) else {return nil}
		
		let (string, decodedMetadata) = strSerializedMetadata.splitUserInfo()
		if !string.isEmpty {
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got stray data in serialized metadata. Ignoring.", log: $0, type: .info) }}
			else                        {NSLog("Got stray data in serialized metadata. Ignoring.")}
		}
		
		return decodedMetadata
	}
	
	/* *********************************
	   MARK: - Streamable Implementation
	   ********************************* */
	
	public func write<Target : TextOutputStream>(to target: inout Target) {
		target.write(
			happnCSVLocFile.PRIVATE_KEY_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
			happnCSVLocFile.PRIVATE_ENV_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
			happnCSVLocFile.PRIVATE_FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
			happnCSVLocFile.PRIVATE_COMMENT_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) + csvSeparator +
			happnCSVLocFile.PRIVATE_MAPPINGS_HEADER_NAME.csvCellValueWithSeparator(csvSeparator)
		)
		target.write(
			csvSeparator + happnCSVLocFile.FILENAME_HEADER_NAME.csvCellValueWithSeparator(csvSeparator) +
			csvSeparator + happnCSVLocFile.COMMENT_HEADER_NAME.csvCellValueWithSeparator(csvSeparator)
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
	
	/* **************************
	   MARK: - Private & Internal
	   ************************** */
	
	private static let PRIVATE_KEY_HEADER_NAME = "__Key"
	private static let PRIVATE_ENV_HEADER_NAME = "__Env"
	private static let PRIVATE_FILENAME_HEADER_NAME = "__Filename"
	private static let PRIVATE_COMMENT_HEADER_NAME = "__Comments"
	private static let PRIVATE_MAPPINGS_HEADER_NAME = "__Mappings"
	private static let FILENAME_HEADER_NAME = "File"
	private static let COMMENT_HEADER_NAME = "Comments"
	
	func getLanguageAgnosticFilenameAndAddLanguageToList(_ filename: String, withMapping languageMapping: [String: String]) -> (String, String) {
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
	
	func getKeyFrom(_ refKey: LineKey, useNonEmptyCommentIfOneEmptyTheOtherNot: Bool, withListOfKeys keys: inout [LineKey]) -> LineKey {
		if let idx = keys.index(of: refKey) {
			if keys[idx].comment != refKey.comment {
				if useNonEmptyCommentIfOneEmptyTheOtherNot && (keys[idx].comment.isEmpty || refKey.comment.isEmpty) {
					/* We use the non-empty comment because one of the two comments
					 * compared is empty; the other not (both are different and one
					 * of them is empty) */
					if keys[idx].comment.isEmpty {
						let newKey = LineKey(
							locKey: keys[idx].locKey, env: keys[idx].env, filename: keys[idx].filename,
							index: keys[idx].index, comment: refKey.comment, userInfo: refKey.userInfo /* We might need a more delicate merging handling for the userInfo... */,
							userReadableGroupComment: refKey.userReadableGroupComment,
							userReadableComment: refKey.userReadableComment
						)
						keys[idx] = newKey
					}
				} else {
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got different comment for same loc key \"%@\" (file %@): \"%@\" and \"%@\"", log: $0, type: .info, refKey.locKey, refKey.filename, keys[idx].comment, refKey.comment) }}
					else                        {NSLog("Got different comment for same loc key \"%@\" (file %@): \"%@\" and \"%@\"", refKey.locKey, refKey.filename, keys[idx].comment, refKey.comment)}
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

public func ==(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	return k1.locKey == k2.locKey && k1.env == k2.env && k1.filename == k2.filename
}

public func <=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	if k1.index    < k2.index    {return true}
	if k1.index    > k2.index    {return false}
	return k1.locKey <= k2.locKey
}

public func >=(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	if k1.index    > k2.index    {return true}
	if k1.index    < k2.index    {return false}
	return k1.locKey >= k2.locKey
}

public func <(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      > k2.env      {return true}
	if k1.env      < k2.env      {return false}
	if k1.filename < k2.filename {return true}
	if k1.filename > k2.filename {return false}
	if k1.index    < k2.index    {return true}
	if k1.index    > k2.index    {return false}
	return k1.locKey < k2.locKey
}

public func >(k1: happnCSVLocFile.LineKey, k2: happnCSVLocFile.LineKey) -> Bool {
	if k1.env      < k2.env      {return true}
	if k1.env      > k2.env      {return false}
	if k1.filename > k2.filename {return true}
	if k1.filename < k2.filename {return false}
	if k1.index    > k2.index    {return true}
	if k1.index    < k2.index    {return false}
	return k1.locKey > k2.locKey
}

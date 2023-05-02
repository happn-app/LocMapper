/*
 * StdRefLocFile.swift
 * LocMapper
 *
 * Created by François Lamboley on 7/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(os)
import os.log
#endif

import Logging



public class StdRefLocFile {
	
	typealias Key = String
	typealias Value = [TaggedString]
	public typealias Language = String
	
	private(set) var languages: [Language]
	private(set) var entries: [Key: [Language: Value]]
	
	public convenience init(fromURL url: URL, languages: [Language], csvSeparator: String = ",") throws {
		var encoding = String.Encoding.utf8
		let filecontent = try String(contentsOf: url, usedEncoding: &encoding)
		try self.init(filecontent: filecontent, languages: languages, csvSeparator: csvSeparator)
	}
	
	init(filecontent: String, languages sourceLanguages: [Language], csvSeparator: String = ",") throws {
		let error = NSError(domain: "StdRefLocFile", code: 1, userInfo: nil)
		let parser = CSVParser(source: filecontent, startOffset: filecontent.startIndex, separator: csvSeparator, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw error
		}
		
		var entriesBuilding = [Key: [Language: Value]]()
		for row in parsedRows {
			guard let keyStr = row["KEY"], !keyStr.isEmpty else {continue}
			let taggedKey = TaggedString(string: keyStr)
			var values = entriesBuilding[taggedKey.value] ?? [:]
			for language in sourceLanguages {values[language, default: []].append(TaggedString(value: row[language] ?? "", tags: taggedKey.tags))}
			entriesBuilding[taggedKey.value] = values
		}
		languages = sourceLanguages
		entries = entriesBuilding
	}
	
	public init(token: String, projectId: String, lokaliseToReflocLanguageName: [String: String], keyType: String, excludedTags: Set<String> = Set(), logPrefix: String?) throws {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let baseURL = URL(string: "https://api.lokalise.co/api2/")!
		let tagMapping = [
			"male_other": "gm",
			"female_other": "gf",
			"male_me": "g{₋}m",
			"female_me": "g{₋}f",
			"variable_string": "r",
			"variable_number": "r##"
		]
		
		if let p = logPrefix {print(p + "Downloading translations from Lokalise...")}
		
		var keys = [LokaliseKey]()
		
		var page = 0
		var currentKeysList: LokaliseKeysList
		repeat {
			/* It’s _not_ a bug, first page is indeed 1… */
			page += 1
			
			/* Setting “disable_references” to 0 actually resolves the key references…
			 * https://docs.lokalise.com/en/articles/1400528-key-referencing */
			let queryItems = [
				URLQueryItem(name: "limit", value: "500"),
				URLQueryItem(name: "page", value: String(page)),
				URLQueryItem(name: "disable_references", value: "0"),
				URLQueryItem(name: "include_translations", value: "1")
			]
			var request = URLRequest(baseURL: baseURL, relativePath: "projects/\(projectId)/keys", httpMethod: "GET", queryItems: queryItems)!
			request.addValue(token, forHTTPHeaderField: "X-Api-Token")
			guard let jsonData = URLSession.shared.fetchData(request: request) else {
				throw NSError(domain: "StdRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot download translations; stopping now"])
			}
			
			currentKeysList = try decoder.decode(LokaliseKeysList.self, from: jsonData)
			keys.append(contentsOf: currentKeysList.keys)
		} while currentKeysList.keys.count > 0
		
		var entriesBuilding = [Key: [Language: Value]]()
		for key in keys {
			let tags = key.tags ?? []
			guard tags.first(where: { excludedTags.contains($0) }) == nil else {
				/* We found a translation that is excluded because of its tag. */
				continue
			}
			guard let keyName = key.keyName[keyType] else {
#if canImport(os)
				Conf.oslog.flatMap{ os_log("Got key from Lokalise with no name for type %{public}@. Skipping...", log: $0, type: .info, keyType) }
#endif
				Conf.logger?.info("Got key from Lokalise with no name for type \(keyType). Skipping...")
				continue
			}
			
			/* Processing key from Lokalise */
			let keyComponents = keyName.components(separatedBy: " - ")
			if keyComponents.count > 2 {
#if canImport(os)
				Conf.oslog.flatMap{ os_log("Got key from Lokalise with more than 2 components. Assuming last one is tags; joining firsts. Components: %@", log: $0, type: .info, keyComponents) }
#endif
				Conf.logger?.info("Got key from Lokalise with more than 2 components. Assuming last one is tags; joining firsts. Components: \(keyComponents)")
			}
			let stdRefLocKey = keyComponents[0..<max(1, keyComponents.endIndex-1)].joined(separator: " - ")
			
			/* Processing tags from Lokalise */
			let processedTags = tags.compactMap{ tag -> String? in
				guard tag.hasPrefix("lcm:") else {return nil}
				let tag = String(tag.dropFirst(4))
				return tagMapping[tag] ?? tag
			}
			
			/* Processing value from Lokalise */
			for translation in key.translations {
				guard let refLocLanguage = lokaliseToReflocLanguageName[translation.languageIso] else {
#if canImport(os)
					Conf.oslog.flatMap{ os_log("Got translation from Lokalise with unknown iso language %{public}@. Skipping...", log: $0, type: .info, translation.languageIso) }
#endif
					Conf.logger?.info("Got translation from Lokalise with unknown iso language \(translation.languageIso). Skipping...")
					continue
				}
				if key.isPlural {
					let plural = try decoder.decode(LokalisePlural.self, from: Data(translation.translation.utf8))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.convertUniversalPlaceholdersToPrintf(StdRefLocFile.valueOrEmptyIfVoid(plural.zero)  ?? "---"), tags: processedTags + ["p0"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.convertUniversalPlaceholdersToPrintf(StdRefLocFile.valueOrEmptyIfVoid(plural.one)   ?? "---"), tags: processedTags + ["p1"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.convertUniversalPlaceholdersToPrintf(StdRefLocFile.valueOrEmptyIfVoid(plural.two)   ?? "---"), tags: processedTags + ["p2"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.convertUniversalPlaceholdersToPrintf(StdRefLocFile.valueOrEmptyIfVoid(plural.few)   ?? "---"), tags: processedTags + ["pf"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.convertUniversalPlaceholdersToPrintf(StdRefLocFile.valueOrEmptyIfVoid(plural.many)  ?? "---"), tags: processedTags + ["pm"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.convertUniversalPlaceholdersToPrintf(StdRefLocFile.valueOrEmptyIfVoid(plural.other) ?? "---"), tags: processedTags + ["px"]))
				} else {
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.convertUniversalPlaceholdersToPrintf(translation.translation), tags: processedTags))
				}
			}
		}
		
		languages = Array(lokaliseToReflocLanguageName.values)
		entries = entriesBuilding
	}
	
	public init(xibRefLoc: XibRefLocFile) {
		languages = xibRefLoc.languages
		
		var entriesBuilding = [Key: [Language: Value]]()
		for (xibLocKey, xibLocValues) in xibRefLoc.entries {
			entriesBuilding[xibLocKey] = HappnXib2Std.taggedValues(from: xibLocValues)
		}
		entries = entriesBuilding
	}
	
	/* Syntaxic coloration says third capture group in second regex should be with a + instead of a *, but old export for “[%1$s:]” did replace the placeholder to “%1$s”… */
	static let universalPlaceholderConversionReplacements = [
		(try! NSRegularExpression(pattern: #"\[%([0-9]*)\$([a-zA-Z0-9.#*@+' -]+)\]"#,                   options: []), #"%$1\$$2"#),
		(try! NSRegularExpression(pattern: #"\[%([0-9]*)\$([a-zA-Z0-9.#*@+' -]+):([a-zA-Z0-9_.-]*)\]"#, options: []), #"%$1\$$2"#)
	]
	
	private static func convertUniversalPlaceholdersToPrintf(_ str: String) -> String {
		var ret = str
		for (r, v) in universalPlaceholderConversionReplacements {
			ret = r.stringByReplacingMatches(in: ret, options: [], range: NSRange(ret.startIndex..<ret.endIndex, in: ret), withTemplate: v)
		}
		return ret
	}
	
	private static func valueOrEmptyIfVoid(_ v: String?) -> String? {
		if v == "[VOID]" {return ""}
		return v
	}
	
}

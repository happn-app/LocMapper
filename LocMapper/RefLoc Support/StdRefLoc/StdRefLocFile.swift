/*
 * StdRefLocFile.swift
 * LocMapper
 *
 * Created by François Lamboley on 7/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

#if !canImport(os) && canImport(DummyLinuxOSLog)
	import DummyLinuxOSLog
#endif



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
		let parser = CSVParser(source: filecontent, startOffset: 0, separator: csvSeparator, hasHeader: true, fieldNames: nil)
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
	
	public init(token: String, projectId: String, lokaliseToReflocLanguageName: [String: String], excludedTags: Set<String> = Set(), logPrefix: String?) throws {
		let baseURL = URL(string: "https://api.lokalise.co/api/")!
		let baseQueryItems = [
			URLQueryItem(name: "api_token", value: token),
			URLQueryItem(name: "id", value: projectId)
		]
		let tagMapping = [
			"male_other": "gm",
			"female_other": "gf",
			"male_me": "g{₋}m",
			"female_me": "g{₋}f",
			"variable_string": "r",
			"variable_number": "r##"
		]
		
		if let p = logPrefix {print(p + "Downloading translations from Lokalise...")}
		let queryItems = baseQueryItems + [URLQueryItem(name: "plural_format", value: "json_string"), URLQueryItem(name: "placeholder_format", value: "printf")]
		let request = URLRequest(baseURL: baseURL, relativePath: "string/list", httpMethod: "POST", queryItems: queryItems, queryInBody: true)!
		guard let json = URLSession.shared.fetchJSONAndCheckResponse(request: request)?["strings"] as? [String: Any?] else {throw NSError(domain: "StdRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot download translations; stopping now"])}
		
		var languagesBuilding = [String]()
		var entriesBuilding = [Key: [Language: Value]]()
		for (lokaliseLanguage, refLocLanguage) in lokaliseToReflocLanguageName {
			guard let lokaliseTranslations = json[lokaliseLanguage] as? [[String: Any?]] else {
				if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Did not get translations from Lokalise for language %{public}@", log: $0, type: .info, lokaliseLanguage) }}
				else                        {NSLog("Did not get translations from Lokalise for language %@", lokaliseLanguage)}
				continue
			}
			
			languagesBuilding.append(refLocLanguage)
			
			for lokaliseTranslation in lokaliseTranslations {
				guard
					let lokaliseTranslationKey = lokaliseTranslation["key"] as? String,
					let lokaliseTranslationTags = lokaliseTranslation["tags"] as? [String],
					let lokaliseTranslationValue = lokaliseTranslation["translation"] as? String
				else {
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Did not get translation value, key or tags from Lokalise for language %{public}@. Translation: %@", log: $0, type: .info, lokaliseLanguage, lokaliseTranslation) }}
					else                        {NSLog("Did not get translation value, key or tags from Lokalise for language %@. Translation: %@", lokaliseLanguage, lokaliseTranslation)}
					continue
				}
				
				guard lokaliseTranslationTags.first(where: { excludedTags.contains($0) }) == nil else {
					/* We found a translation that is excluded because of its tag. */
					continue
				}
				
				/* Processing key from Lokalise */
				let keyComponents = lokaliseTranslationKey.components(separatedBy: " - ")
				if keyComponents.count > 2 {
					if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Got key from Lokalise with more than 2 components. Assuming last one is tags; joining firsts. Components: %@", log: $0, type: .info, keyComponents) }}
					else                        {NSLog("Got key from Lokalise with more than 2 components. Assuming last one is tags; joining firsts. Components: %@", keyComponents)}
				}
				let stdRefLocKey = keyComponents[0..<max(1, keyComponents.endIndex-1)].joined(separator: " - ")
				
				/* Processing tags from Lokalise */
				let tags = lokaliseTranslationTags.compactMap{ tag -> String? in
					guard tag.hasPrefix("lcm:") else {return nil}
					let tag = String(tag.dropFirst(4))
					return tagMapping[tag] ?? tag
				}
				
				/* Processing value from Lokalise */
				if lokaliseTranslation["plural_key"] as? String == "1" {
					guard let pluralTranslation = (try? JSONSerialization.jsonObject(with: Data(lokaliseTranslationValue.utf8), options: [])) as? [String: String] else {
						if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Did not get valid JSON for plural translation value %@", log: $0, type: .info, lokaliseTranslationValue) }}
						else                        {NSLog("Did not get valid JSON for plural translation value %@", lokaliseTranslationValue)}
						continue
					}
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.valueOrEmptyIfVoid(pluralTranslation["zero"])  ?? "---", tags: tags + ["p0"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.valueOrEmptyIfVoid(pluralTranslation["one"])   ?? "---", tags: tags + ["p1"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.valueOrEmptyIfVoid(pluralTranslation["two"])   ?? "---", tags: tags + ["p2"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.valueOrEmptyIfVoid(pluralTranslation["few"])   ?? "---", tags: tags + ["pf"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.valueOrEmptyIfVoid(pluralTranslation["many"])  ?? "---", tags: tags + ["pm"]))
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: StdRefLocFile.valueOrEmptyIfVoid(pluralTranslation["other"]) ?? "---", tags: tags + ["px"]))
				} else {
					entriesBuilding[stdRefLocKey, default: [:]][refLocLanguage, default: []].append(TaggedString(value: lokaliseTranslationValue, tags: tags))
				}
			}
		}
		
		languages = languagesBuilding
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
	
	private static func valueOrEmptyIfVoid(_ v: String?) -> String? {
		if v == "[VOID]" {return ""}
		return v
	}
	
	private static func valueOrEmptyIfVoid(_ v: String) -> String {
		if v == "[VOID]" {return ""}
		return v
	}
	
}

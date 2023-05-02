/*
 * XibRefLocFile.swift
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



public class XibRefLocFile {
	
	typealias Key = String
	typealias Value = String
	public typealias Language = String
	
	private(set) var languages: [Language]
	private(set) var entries: [Key: [Language: Value]]
	
	public convenience init(fromURL url: URL, languages: [Language], csvSeparator: String = ",") throws {
		var encoding = String.Encoding.utf8
		let filecontent = try String(contentsOf: url, usedEncoding: &encoding)
		try self.init(filecontent: filecontent, languages: languages, csvSeparator: csvSeparator)
	}
	
	init(filecontent: String, languages sourceLanguages: [Language], csvSeparator: String = ",") throws {
		let error = NSError(domain: "XibRefLocFile", code: 1, userInfo: nil)
		let parser = CSVParser(source: filecontent, startOffset: filecontent.startIndex, separator: csvSeparator, hasHeader: true, fieldNames: nil)
		guard let parsedRows = parser.arrayOfParsedRows() else {
			throw error
		}
		
		var entriesBuilding = [Key: [Language: Value]]()
		for row in parsedRows {
			guard let key = row["KEY"], !key.isEmpty else {continue}
			if entriesBuilding[key] != nil {
#if canImport(os)
				Conf.oslog.flatMap{ os_log("Found duplicated key %@ when parsing reference translation loc file. The latest one wins.", log: $0, type: .info, key) }
#endif
				Conf.logger?.warning("Found duplicated key \(key) when parsing reference translation loc file. The latest one wins.")
			}
			
			var values = [Language: Value]()
			for language in sourceLanguages {values[language] = row[language] ?? ""}
			entriesBuilding[key] = values
		}
		
		languages = sourceLanguages
		entries = entriesBuilding
	}
	
	public init(stdRefLoc: StdRefLocFile) throws {
		var entriesBuilding = [Key: [Language: Value]]()
		for (key, taggedValuesPerLanguage) in stdRefLoc.entries {
			var values = [Language: Value]()
			for (language, taggedValues) in taggedValuesPerLanguage {
				values[language] = try Std2Xib.untaggedValue(from: taggedValues, with: language)
			}
			entriesBuilding[key] = values
		}
		
		languages = stdRefLoc.languages
		entries = entriesBuilding
	}
	
	public func exportToLokalise(token: String, projectId: String, reflocToLokaliseLanguageName: [String: String], takeSnapshot: Bool, logPrefix: String?) throws {
		let batchSize = 7
		
		let baseURL = URL(string: "https://api.lokalise.co/api/")!
		let baseQueryItems = [
			URLQueryItem(name: "api_token", value: token),
			URLQueryItem(name: "id", value: projectId)
		]
		
		/* Let's construct the data we send to Lokalise before doing anything on Lokalise! (This step can fail.) */
		if let p = logPrefix {print(p + "Converting Xib Ref Loc to Lokalise Ref Loc...")}
		let lokaliseEntries = try entries.mapValues{ try HappnXib2Lokalise.lokaliseValues(from: $0) }
		
		if let p = logPrefix {print(p + "Computing JSON data to send to Lokalise...")}
		var currentTranslations = [[String: Any]]()
		var translationsPayloads = [String]()
		var totalTranslations = 0
		let tagMapping = [
			"gm": ["lcm:male_other", "gender"],
			"gf": ["lcm:female_other", "gender"],
			"g{₋}m": ["lcm:male_me", "gender"],
			"g{₋}f": ["lcm:female_me", "gender"],
			"r": ["lcm:variable_string"],
			"r##": ["lcm:variable_number"]
		]
		
		func addCurrentTranslationsToPayloads() throws {
			guard currentTranslations.count > 0 else {return}
			let td = try JSONSerialization.data(withJSONObject: currentTranslations, options: [])
			guard let ts = String(data: td, encoding: .utf8) else {throw NSError(domain: "LocFile+XibRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create string from JSON encoded data to send to Lokalise"])}
			translationsPayloads.append(ts)
			currentTranslations.removeAll()
		}
		
		for k in lokaliseEntries.keys.sorted() {
			let v = lokaliseEntries[k]!
			
			var currentTranslationsBuilding = [String: [String: Any]]()
			for (language, taggedValues) in v {
				guard let lokaliseLanguage = reflocToLokaliseLanguageName[language] else {continue}
				for taggedValue in taggedValues {
					var curT: [String: Any]
					let tags = Set(taggedValue.tags.flatMap{ tagMapping[$0] ?? [$0] })
					let key = k + (tags.count > 0 ? " - " + tags.joined(separator: ", ") : "")
					
					if let t = currentTranslationsBuilding[key] {curT = t}
					else {
						curT = [
							"key": key,
							"platform_mask": 16,
							"hidden": 0,
							"tags": ["locmapper"] + taggedValue.tags.flatMap{ tag -> [String] in
								if let mTag = tagMapping[tag] {return mTag}
								return ["lcm:" + tag]
							}
						]
					}
					
					var curV: Any
					switch taggedValue.value {
						case .value(let v): curV = (v.isEmpty || v == "---" ? "[VOID]" : v)
						case .plural(let p):
							var plural = [String: String]()
							if let z = p.zero  {plural["zero"]  = z}
							if let z = p.one   {plural["one"]   = z}
							if let z = p.two   {plural["two"]   = z}
							if let z = p.few   {plural["few"]   = z}
							if let z = p.many  {plural["many"]  = z}
							if let z = p.other {plural["other"] = z}
							curT["plural"] = key
							curV = plural
					}
					var curTranslations = curT["translations"] as! [String: Any]? ?? [:]
					curTranslations[lokaliseLanguage] = curV
					curT["translations"] = curTranslations
					
					currentTranslationsBuilding[key] = curT
				}
			}
			currentTranslations.append(contentsOf: currentTranslationsBuilding.values.filter{ t -> Bool in /* The filter remove all empty (contains only "[VOID]") translations */
				return (t["translations"] as! [String: Any]).values.contains{ v in
					switch v {
						case let s as String: return s != "[VOID]"
						case let d as [String: String]: return d.values.contains{ $0 != "[VOID]" }
						default: fatalError("Invalid trad")
					}
				}
			})
			totalTranslations += currentTranslationsBuilding.count
			if currentTranslations.count >= batchSize {try addCurrentTranslationsToPayloads()}
		}
		try addCurrentTranslationsToPayloads()
		
		/* Taking a snapshot if asked */
		if takeSnapshot {
			if let p = logPrefix {print(p + "Creating snapshot on Lokalise...")}
			
			let dateFormatter = ISO8601DateFormatter()
			dateFormatter.formatOptions = [.withFullDate, .withFullTime]
			
			let queryItems = baseQueryItems + [URLQueryItem(name: "title", value: dateFormatter.string(from: Date()) + " — LocMapper Snapshot")]
			let request = URLRequest(baseURL: baseURL, relativePath: "project/snapshot", httpMethod: "POST", queryItems: queryItems, queryInBody: true)!
			
			guard URLSession.shared.fetchJSONAndCheckResponse(request: request) != nil else {throw NSError(domain: "LocFile+XibRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create snapshot"])}
		}
		
		/* Dropping all translations. */
		do {
			if let p = logPrefix {print(p + "Dropping all translations on Lokalise...")}
			let request = URLRequest(baseURL: baseURL, relativePath: "project/empty", httpMethod: "POST", queryItems: baseQueryItems, queryInBody: true)!
			guard URLSession.shared.fetchJSONAndCheckResponse(request: request) != nil else {throw NSError(domain: "LocFile+XibRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot empty the project"])}
		}
		
		/* Uploading new translations. */
		do {
			var c = 0
			if let p = logPrefix {print(p + "Uploading new translations to Lokalise...")}
			for t in translationsPayloads {
				c += batchSize
				let queryItems = baseQueryItems + [URLQueryItem(name: "data", value: t)]
				let request = URLRequest(baseURL: baseURL, relativePath: "string/set", httpMethod: "POST", queryItems: queryItems, queryInBody: true)!
				guard URLSession.shared.fetchJSONAndCheckResponse(request: request) != nil else {throw NSError(domain: "LocFile+XibRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot upload some translations; stopping now"])}
				if let p = logPrefix {print(p + "   Uploaded at least \(min(c, totalTranslations))/\(totalTranslations)")}
			}
		}
		
		if let p = logPrefix {print(p + "Done")}
	}
	
}

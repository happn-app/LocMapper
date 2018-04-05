/*
 * LocFile+StdRefLoc.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log



extension LocFile {
	
	static let stdReferenceTranslationsFilename = "StandardReferencesTranslations.csv"
	static let stdReferenceTranslationsGroupComment = "••••••••••••••••••••••••••••••••••••• START OF STD REF TRADS — DO NOT MODIFY •••••••••••••••••••••••••••••••••••••"
	static let stdReferenceTranslationsUserReadableComment = "STD REF TRAD. DO NOT MODIFY."
	
	public func mergeRefLocsWithStdRefLocFile(_ stdRefLocFile: StdRefLocFile) {
		let newUntaggedKeys = stdRefLocFile.entries.map{ $0.key }
		
		/* Remove all previous StdRefLoc entries whose untagged keys match any
		 * untagged keys in the new entries */
		for key in entries.keys {
			guard key.env == "StdRefLoc" else {continue}
			let (untaggedKey, _) = key.locKey.splitAppendedTags()
			guard newUntaggedKeys.contains(untaggedKey) else {continue}
			entries.removeValue(forKey: key)
		}
		
		/* Adding languages in reference translations. But not removing languages
		 * not in reference translations! */
		for l in stdRefLocFile.languages {
			if !languages.contains(l) {
				languages.append(l)
			}
		}
		
		/* Import new RefLoc entries */
		var isFirst = entryKeys.contains{ $0.env == "StdRefLoc" }
		for (refKey, refVals) in stdRefLocFile.entries {
			for (language, taggedValues) in refVals {
				for taggedValue in taggedValues {
					let key = LineKey(locKey: refKey.byAppending(tags: taggedValue.tags), env: "StdRefLoc", filename: LocFile.stdReferenceTranslationsFilename, index: isFirst ? 0 : 1, comment: "", userInfo: [:], userReadableGroupComment: isFirst ? LocFile.stdReferenceTranslationsGroupComment : "", userReadableComment: LocFile.stdReferenceTranslationsUserReadableComment)
					var values = entries[key]?.entries ?? [:]
					values[language] = taggedValue.value
					entries[key] = .entries(values)
				}
			}
			isFirst = false
		}
	}
	
	public func exportStdRefLoc(to path: String, csvSeparator: String) {
		do {
			var stream = try FileHandleOutputStream(forPath: path)
			
			/* Printing header */
			print("KEY".csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)
			for l in languages {print(csvSeparator + l.csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)}
			print("", to: &stream)
			
			/* Printing values */
			for k in entryKeys.sorted() {
				guard k.env == "StdRefLoc" else {continue}
				print(k.locKey.csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)
				for l in languages {print(csvSeparator + (exportedValueForKey(k, withLanguage: l) ?? "---").csvCellValueWithSeparator(csvSeparator), terminator: "", to: &stream)}
				print("", to: &stream)
			}
		} catch {
			if #available(OSX 10.12, *) {di.log.flatMap{ os_log("Cannot write file to path %@, got error %@", log: $0, type: .error, path, String(describing: error)) }}
			else                        {NSLog("Cannot write file to path %@, got error %@", path, String(describing: error))}
		}
	}
	
	public func exportStdRefLocToLokalise(token: String, projectId: String, reflocToLokaliseLanguageName: [String: String], takeSnapshot: Bool, logPrefix: String?) throws {
		let batchSize = 25
		
		let baseURL = URL(string: "https://api.lokalise.co/api/")!
		let baseQueryItems = [
			URLQueryItem(name: "api_token", value: token),
			URLQueryItem(name: "id", value: projectId)
		]
		
		/* Let's construct the data we send to Lokalise before doing anything on
		 * Lokalise! (This step can fail.) */
		if let p = logPrefix {print(p + "Computing JSON data to send to Lokalise...")}
		var translationsForLokalise = [String]()
		var t = [[String: Any]]()
		for k in entryKeys.sorted() {
			guard k.env == "StdRefLoc" else {continue}
			var curT = [String: Any]()
			curT["key"] = k.locKey
			curT["platform_mask"] = 16
			curT["hidden"] = 0
			curT["tags"] = ["locmapper:uploaded_from_stdrefloc"]
			var curV = [String: String]()
			for l in languages {
				guard let lokaliseLanguage = reflocToLokaliseLanguageName[l] else {continue}
				curV[lokaliseLanguage] = exportedValueForKey(k, withLanguage: l) ?? "[VOID]"
			}
			curT["translations"] = curV
			t.append(curT)
			if t.count >= batchSize {
				let td = try JSONSerialization.data(withJSONObject: t, options: [])
				guard let ts = String(data: td, encoding: .utf8) else {throw NSError(domain: "LocFile+StdRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create string from JSON encoded data to send to Lokalise"])}
				translationsForLokalise.append(ts)
				t.removeAll()
			}
		}
		
		/* Taking a snapshot if asked */
		if takeSnapshot {
			if let p = logPrefix {print(p + "Creating snapshot...")}
			
			let dateFormatter = ISO8601DateFormatter()
			dateFormatter.formatOptions = [.withFullDate, .withFullTime]
			
			let queryItems = baseQueryItems + [URLQueryItem(name: "title", value: dateFormatter.string(from: Date()) + " — LocMapper Snapshot")]
			let request = URLRequest(baseURL: baseURL, relativePath: "project/snapshot", httpMethod: "POST", queryItems: queryItems, queryInBody: true)!
			
			guard URLSession.shared.fetchJSONAndCheckResponse(request: request) != nil else {throw NSError(domain: "LocFile+StdRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create snapshot"])}
		}
		
		/* Dropping all translations */
		do {
			if let p = logPrefix {print(p + "Dropping all translations on lokalise...")}
			let request = URLRequest(baseURL: baseURL, relativePath: "project/empty", httpMethod: "POST", queryItems: baseQueryItems, queryInBody: true)!
			guard URLSession.shared.fetchJSONAndCheckResponse(request: request) != nil else {throw NSError(domain: "LocFile+StdRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot empty the project"])}
		}
		
		/* Uploading new translations */
		do {
			var c = 0
			let total = entryKeys.count
			if let p = logPrefix {print(p + "Uploading new translations to lokalise...")}
			for t in translationsForLokalise {
				c += batchSize
				let queryItems = baseQueryItems + [URLQueryItem(name: "data", value: t)]
				let request = URLRequest(baseURL: baseURL, relativePath: "string/set", httpMethod: "POST", queryItems: queryItems, queryInBody: true)!
				guard URLSession.shared.fetchJSONAndCheckResponse(request: request) != nil else {throw NSError(domain: "LocFile+StdRefLoc", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot upload some translations; stopping now"])}
				if let p = logPrefix {print(p + "   Uploaded \(min(c, total))/\(total)")}
			}
		}
		
		if let p = logPrefix {print(p + "Done")}
	}
	
}

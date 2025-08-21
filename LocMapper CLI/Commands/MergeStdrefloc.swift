/*
Copyright 2020 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation

import ArgumentParser

import LocMapper



struct MergeStdrefloc : ParsableCommand {
	
	static let configuration = CommandConfiguration(
		commandName: "merge_stdrefloc",
		abstract: "Get ref loc from a given source and merge them in an lcm file, optionally converting them into the XibRefLoc format before merge."
	)
	
	@OptionGroup var csvOptions: CSVOptions
	@OptionGroup var logOptions: LoggingOptions
	
	@Option
	var mergeStyle = LocFile.MergeStyle.add
	
	/* Only for Lokalize, at least for now. */
	@Option
	var excludedTags = [String]()
	
	@Flag(inversion: .prefixedNo)
	var convertToXibrefloc: Bool = true /* Yes, I’m bitter, and I promote my format! The choice that would make the most sense would be no here… */
	
	/* Either these three options must be set… */
	@Option
	var lokalizeReadToken: String?
	@Option
	var lokalizeProjectID: String?
	@Option(help: "This is the type of the project as seen by Lokalise. Possible values are (at least now): ios, web, android, other")
	var lokalizeProjectType: String?
	/* … or this one must be. */
	@Option
	var fileToMerge: String?
	
	@Argument
	var mergedFilePath: String
	
	/* What this contains depends on whether the source is lokalize or a ref loc file.
	 * For Lokalize it’s a language mapping, for a ref loc file it’s a list of languages. */
	@Argument
	var languageArgs = [String]()
	
	func run() throws {
		logOptions.bootstrapLogger()
		
		let csvSeparator = csvOptions.csvSeparator
		let excludedTags = Set(parseObsoleteOptionList(self.excludedTags) ?? [])
		guard !languageArgs.isEmpty else {
			/* Whatever the language args contains, it cannot be empty. */
			throw ValidationError("The languages cannot be left empty")
		}
		
		let sourceError = ValidationError("Either the three Lokalize args or the file to merge path (the std ref loc to merge) must be set")
		
		print("Merging Lokalise Trads as StdRefLoc in LocFile...")
		let stdRefLoc: StdRefLocFile
		if let lokalizeReadToken, let lokalizeProjectID, let lokalizeProjectType {
			guard fileToMerge == nil else {throw sourceError}
			print("   Creating StdRefLoc from Lokalise...")
			stdRefLoc = try StdRefLocFile(token: lokalizeReadToken, projectId: lokalizeProjectID, lokaliseToReflocLanguageName: dictionaryOptionFromArray(languageArgs), keyType: lokalizeProjectType, excludedTags: excludedTags, logPrefix: "      ")
		} else if let fileToMerge {
			guard lokalizeReadToken == nil, lokalizeProjectID == nil, lokalizeProjectType == nil else {throw sourceError}
			print("   Reading StdRefLoc from file...")
			stdRefLoc = try StdRefLocFile(fromURL: URL(fileURLWithPath: fileToMerge), languages: languageArgs, csvSeparator: csvSeparator)
		} else {
			throw sourceError
		}
		
		print("   Reading source LocFile...")
		let locFile = try LocFile(fromPath: mergedFilePath, withCSVSeparator: csvSeparator)
		if convertToXibrefloc {
			print("   Converting StdRefLoc to XibRefLoc...")
			let xibRefLoc = try XibRefLocFile(stdRefLoc: stdRefLoc)
			
			print("   Merging XibRefLoc...")
			locFile.mergeRefLocsWithXibRefLocFile(xibRefLoc, mergeStyle: mergeStyle)
		} else {
			print("   Merging StdRefLoc...")
			locFile.mergeRefLocsWithStdRefLocFile(stdRefLoc, mergeStyle: mergeStyle)
		}
		
		print("   Writing merged file...")
		var stream = try FileHandleOutputStream(forPath: mergedFilePath)
		print(locFile, terminator: "", to: &stream)
		print("Done")
	}
	
}

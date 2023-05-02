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



struct MergeLokaliseTradsAsStdrefloc : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "merge_lokalise_trads_as_stdrefloc",
		abstract: "Fetch ref loc from lokalise and merge them in an lcm file, converted into the StdRefLoc format."
	)
	
	@OptionGroup() var csvOptions: CSVOptions
	@OptionGroup() var logOptions: LoggingOptions
	
	@Option
	var mergeStyle = LocFile.MergeStyle.add
	
	@Option
	var excludedTags = [String]()
	
	@Argument
	var lokalizeReadToken: String
	
	@Argument
	var lokalizeProjectID: String
	
	@Argument(help: "This is the type of the project as seen by Lokalise. Possible values are (at least now): ios, web, android, other")
	var projectType: String
	
	@Argument
	var mergedFilePath: String
	
	@Argument
	var lokalizeToRefLocLanguageNameMapping = [String]()
	
	func run() throws {
		logOptions.bootstrapLogger()
		
		let csvSeparator = csvOptions.csvSeparator
		let excludedTags = Set(parseObsoleteOptionList(self.excludedTags) ?? [])
		let lokalizeToRefLocLanguageName = try dictionaryOptionFromArray(lokalizeToRefLocLanguageNameMapping)
		
		print("Merging Lokalise Trads as StdRefLoc in LocFile...")
		print("   Creating StdRefLoc from Lokalise...")
		let stdRefLoc = try StdRefLocFile(token: lokalizeReadToken, projectId: lokalizeProjectID, lokaliseToReflocLanguageName: lokalizeToRefLocLanguageName, keyType: projectType, excludedTags: excludedTags, logPrefix: "      ")
		
		print("   Parsing source and merging StdRefLoc...")
		let locFile = try LocFile(fromPath: mergedFilePath, withCSVSeparator: csvSeparator)
		locFile.mergeRefLocsWithStdRefLocFile(stdRefLoc, mergeStyle: mergeStyle)
		
		print("   Writing merged file...")
		var stream = try FileHandleOutputStream(forPath: mergedFilePath)
		print(locFile, terminator: "", to: &stream)
		print("Done")
	}
	
}

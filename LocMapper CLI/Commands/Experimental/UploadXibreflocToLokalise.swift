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



struct UploadXibreflocToLokalise : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "upload_xibrefloc_to_lokalise",
		abstract: "Upload a Xib Ref Loc file to lokalise.",
		discussion: """
			DROPS EVERYTHING IN THE PROJECT (but does a snapshot first).
			The translations will be marked for platform “Other.”
			"""
	)
	
	@OptionGroup() var csvOptions: CSVOptions
	@OptionGroup() var logOptions: LoggingOptions
	
	@Argument()
	var lokalizeReadAndWriteToken: String
	
	@Argument()
	var lokalizeProjectID: String
	
	@Argument()
	var inputFile: String
	
	@Argument()
	var refLocToLokalizeLanguageNameMapping: [String]
	
	func run() throws {
		logOptions.bootstrapLogger()
		
		let csvSeparator = csvOptions.csvSeparator
		let refLocToLokalizeLanguageName = try dictionaryOptionFromArray(refLocToLokalizeLanguageNameMapping)
		
		print("Uploading Xib Ref Loc to Localize project \(lokalizeProjectID)...")
		print("   Parsing source...")
		let xibLoc = try XibRefLocFile(fromURL: URL(fileURLWithPath: inputFile, isDirectory: false), languages: Array(refLocToLokalizeLanguageName.keys), csvSeparator: csvSeparator)
		
		print("   Exporting Loc File to Lokalise...")
		try xibLoc.exportToLokalise(token: lokalizeReadAndWriteToken, projectId: lokalizeProjectID, reflocToLokaliseLanguageName: refLocToLokalizeLanguageName, takeSnapshot: true, logPrefix: "      ")
		print("Done")
	}
	
}

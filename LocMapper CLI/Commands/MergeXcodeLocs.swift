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



struct MergeXcodeLocs : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "merge_xcode_locs", /* Default name (if let unspecified) would be "merge-xcode-locs", but previous versions had underscores, not dashes. */
		abstract: "Merge the strings from an Xcode project in a locmapper file.",
		discussion: """
			Excludes strings whose path match any item in the any exclude list.
			If an include list is given, also filter paths not matching any item in the include list.
			"""
	)
	
	@OptionGroup()
	var csvOptions: CSVOptions
	
	@Option(help: "List of paths to exclude when reading the project.")
	var excludeList: [String]
	
	@Option(help: "List of paths to only include when reading the project.")
	var includeList: [String]
	
	@Argument()
	var rootFolder: String
	
	@Argument()
	var outputFile: String
	
	@Argument()
	var lprojNameToLanguageNameMapping: [String]
	
	func run() throws {
		let csvSeparator = csvOptions.csvSeparator
		
		let excludeList = parseObsoleteOptionList(self.excludeList)
		let includeList = parseObsoleteOptionList(self.includeList)
		
		let folderNameToLanguageName = try dictionaryOptionFromArray(lprojNameToLanguageNameMapping)
		
		print("Merging from Xcode project...")
		print("   Finding and parsing Xcode locs...")
		let parsedXcodeStringsFiles = try XcodeStringsFile.stringsFilesInProject(rootFolder, excludedPaths: excludeList, includedPaths: includeList)
		print("   Parsing original LocMapper file...")
		let locFile = try LocFile(fromPath: outputFile, withCSVSeparator: csvSeparator)
		print("   Merging...")
		locFile.mergeXcodeStringsFiles(parsedXcodeStringsFiles, folderNameToLanguageName: folderNameToLanguageName)
		print("   Writing merged file...")
		var stream = try FileHandleOutputStream(forPath: outputFile)
		print(locFile, terminator: "", to: &stream)
		print("Done")
	}
	
}

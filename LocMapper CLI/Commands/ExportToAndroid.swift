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



struct ExportToAndroid : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "export_to_android",
		abstract: "Exports the locs from an lcm file in an android project."
	)
	
	@OptionGroup()
	var csvOptions: CSVOptions
	
	@Option()
	var stringsFilenames: [String]
	
	@Argument()
	var inputFile: String
	
	@Argument()
	var rootFolder: String
	
	@Argument()
	var folderNameToLanguageNameMapping: [String]
	
	func run() throws {
		let csvSeparator = csvOptions.csvSeparator
		let folderNameToLanguageName = try dictionaryOptionFromArray(folderNameToLanguageNameMapping)
		
		if !stringsFilenames.isEmpty {
			print("*** WARNING: The strings-filenames option is deprecated for the export_to_android command (it has never been used)")
		}
		
		print("Exporting to android project...")
		print("   Parsing LocMapper file...")
		let csv = try LocFile(fromPath: inputFile, withCSVSeparator: csvSeparator)
		print("   Writing locs to android project...")
		csv.exportToAndroidProjectWithRoot(rootFolder, folderNameToLanguageName: folderNameToLanguageName)
		print("Done")
	}
	
}

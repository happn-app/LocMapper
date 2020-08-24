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



struct MergeAndroidLocs : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "merge_android_locs",
		abstract: "Merge the strings from an android project in a locmapper file."
	)
	
	@OptionGroup()
	var csvOptions: CSVOptions
	
	@Option
	var resFolder = "res"
	
	@Option
	var stringsFilenames = [String]()
	
	@Argument
	var rootFolder: String
	
	@Argument
	var outputFile: String
	
	@Argument
	var folderNameToLanguageNameMapping = [String]()
	
	func run() throws {
		let csvSeparator = csvOptions.csvSeparator
		let stringsFilenames = parseObsoleteOptionList(self.stringsFilenames) ?? ["strings.xml"]
		let folderNameToLanguageName = try dictionaryOptionFromArray(folderNameToLanguageNameMapping)
		
		print("Merging from android project...")
		print("   Parsing android locs...")
		let parsedAndroidLocFiles = try AndroidXMLLocFile.locFilesInProject(rootFolder, resFolder: resFolder, stringsFilenames: stringsFilenames, languageFolderNames: Array(folderNameToLanguageName.keys))
		print("   Parsing original LocMapper file...")
		let locFile = try LocFile(fromPath: outputFile, withCSVSeparator: csvSeparator)
		print("   Merging...")
		locFile.mergeAndroidXMLLocStringsFiles(parsedAndroidLocFiles, folderNameToLanguageName: folderNameToLanguageName)
		print("   Writing merged file...")
		var stream = try FileHandleOutputStream(forPath: outputFile)
		print(locFile, terminator: "", to: &stream)
		print("Done")
	}
	
}

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



struct ExportToXcode : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "export_to_xcode",
		abstract: "Exports the locs from an lcm file in an Xcode project.",
		discussion: """
			Strings files are written as UTF-16 by default. Supported encodings for the --encoding option are utf8 and utf16.
			"""
	)
	
	@OptionGroup
	var csvOptions: CSVOptions
	
	@Option
	var encoding = "utf16"
	
	@Argument
	var inputFile: String
	
	@Argument
	var rootFolder: String
	
	@Argument
	var lprojNameToLanguageNameMapping = [String]()
	
	func run() throws {
		let csvSeparator = csvOptions.csvSeparator
		
		let encoding: String.Encoding
		switch self.encoding.lowercased() {
			case "utf8",  "utf-8":  encoding = .utf8
			case "utf16", "utf-16": encoding = .utf16
			default:
				throw ValidationError("Unsupported encoding \(self.encoding)")
		}
		
		let folderNameToLanguageName = try dictionaryOptionFromArray(lprojNameToLanguageNameMapping)
		
		print("Exporting to Xcode project...")
		print("   Parsing LocMapper file...")
		let locFile = try LocFile(fromPath: inputFile, withCSVSeparator: csvSeparator)
		print("   Writing locs to Xcode project...")
		locFile.exportToXcodeProjectWithRoot(rootFolder, folderNameToLanguageName: folderNameToLanguageName, encoding: encoding)
		print("Done")
	}
	
}

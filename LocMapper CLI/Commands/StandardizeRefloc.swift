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



struct StandardizeRefloc : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "standardize_refloc",
		abstract: "Takes a Xib or Std RefLoc file and “standardizes” it.",
		discussion: """
			All the comments, etc. are removed: only the data is kept; all the metadata is gotten rid of.
			The keys are sorted alphabetically.
			"""
	)
	
	@OptionGroup()
	var csvOptions: CSVOptions
	
	@Argument()
	var inputFile: String
	
	@Argument()
	var outputFile: String
	
	@Argument()
	var languagesNames: [String]
	
	func run() throws {
		let csvSeparator = csvOptions.csvSeparator
		
		guard !languagesNames.isEmpty else {
			throw ValidationError("At least one language is required.")
		}
		
		print("Standardizing Ref Loc...")
		/* We use XibRefLocFile to parse and output the file because this format does not do any transformation on the values it reads and outputs. */
		print("   Parsing source...")
		let f = try XibRefLocFile(fromURL: URL(fileURLWithPath: inputFile, isDirectory: false), languages: languagesNames, csvSeparator: csvSeparator)
		
		print("   Merging in Loc File...")
		let locFile = LocFile()
		locFile.mergeRefLocsWithXibRefLocFile(f, mergeStyle: .add)
		
		print("   Exporting Loc File to Ref Loc...")
		locFile.exportXibRefLoc(to: outputFile, csvSeparator: csvSeparator)
		print("Done")
	}
	
}

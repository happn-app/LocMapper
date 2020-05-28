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



struct ConvertXibreflocToStdrefloc : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "convert_xibrefloc_to_stdrefloc",
		abstract: "Take a XibLoc-styled RefLoc (with tokens for plurals, gender, etc.) and convert it to a more usual format (one key per plural/gender/etc. variations)."
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
		
		print("Converting from Xib Ref Loc to Std Ref Loc...")
		print("   Parsing source...")
		let f = try XibRefLocFile(fromURL: URL(fileURLWithPath: inputFile, isDirectory: false), languages: languagesNames, csvSeparator: csvSeparator)
		print("   Converting to Std Ref Loc...")
		let s = StdRefLocFile(xibRefLoc: f)
		
		print("   Merging in Loc File...")
		let locFile = LocFile()
		locFile.mergeRefLocsWithStdRefLocFile(s, mergeStyle: .add)
		
		print("   Exporting Loc File to Std Ref Loc...")
		locFile.exportStdRefLoc(to: outputFile, csvSeparator: csvSeparator)
		print("Done")
	}
	
}

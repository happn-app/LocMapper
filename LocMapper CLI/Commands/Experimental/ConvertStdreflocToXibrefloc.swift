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



struct ConvertStdreflocToXibrefloc : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		commandName: "convert_stdrefloc_to_xibrefloc",
		abstract: "Does the inverse of convert_xibrefloc_to_stdrefloc."
	)
	
	@OptionGroup() var csvOptions: CSVOptions
	@OptionGroup() var logOptions: LoggingOptions
	
	@Argument()
	var inputFile: String
	
	@Argument()
	var outputFile: String
	
	@Argument()
	var languagesNames: [String]
	
	func run() throws {
		logOptions.bootstrapLogger()
		
		let csvSeparator = csvOptions.csvSeparator
		
		guard !languagesNames.isEmpty else {
			throw ValidationError("At least one language is required.")
		}
		
		print("Converting from Std Ref Loc to Xib Ref Loc...")
		print("   Parsing source...")
		let f = try StdRefLocFile(fromURL: URL(fileURLWithPath: inputFile, isDirectory: false), languages: languagesNames, csvSeparator: csvSeparator)
		print("   Converting to Xib Ref Loc...")
		let s = try XibRefLocFile(stdRefLoc: f)
		
		print("   Merging in Loc File...")
		let locFile = LocFile()
		locFile.mergeRefLocsWithXibRefLocFile(s, mergeStyle: .add)
		
		print("   Exporting Loc File to Xib Ref Loc...")
		locFile.exportXibRefLoc(to: outputFile, csvSeparator: csvSeparator)
		print("Done")
	}
	
}

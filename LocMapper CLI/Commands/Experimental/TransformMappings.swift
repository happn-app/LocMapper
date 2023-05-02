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



struct TransformMappings : ParsableCommand {
	
	static var configuration = CommandConfiguration(commandName: "transform_mappings")
	
	@OptionGroup() var csvOptions: CSVOptions
	@OptionGroup() var logOptions: LoggingOptions
	
	@Option()
	var keysMappingFile: String?
	
	@Argument()
	var transformedFilePath: String
	
	func run() throws {
		logOptions.bootstrapLogger()
		
		let csvSeparator = csvOptions.csvSeparator
		
		var transforms = [LocFile.MappingTransformation]()
		if let mappingFile = keysMappingFile {
			transforms.append(.applyMappingOnKeys(.fromCSVFile(URL(fileURLWithPath: mappingFile, isDirectory: false))))
		}
		
		print("Transforming mappings in LocFile...")
		print("   Parsing source...")
		let locFile = try LocFile(fromPath: transformedFilePath, withCSVSeparator: csvSeparator)
		
		print("   Applying transforms...")
		try locFile.apply(mappingTransformations: transforms, csvSeparator: csvSeparator)
		
		print("   Writing transformed file...")
		var stream = try FileHandleOutputStream(forPath: transformedFilePath)
		print(locFile, terminator: "", to: &stream)
		print("Done")
	}
	
}

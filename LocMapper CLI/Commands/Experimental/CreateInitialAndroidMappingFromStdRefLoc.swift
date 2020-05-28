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



struct CreateInitialAndroidMappingFromStdRefLoc : ParsableCommand {
	
	static var configuration = CommandConfiguration(commandName: "create_initial_android_mapping_from_std_ref_loc")
	
	@OptionGroup()
	var csvOptions: CSVOptions
	
	@Argument()
	var transformedFilePath: String
	
	func run() throws {
		let csvSeparator = csvOptions.csvSeparator
		
		print("Creating initial android mappings in LocFile...")
		print("   Parsing source...")
		let locFile = try LocFile(fromPath: transformedFilePath, withCSVSeparator: csvSeparator)
		
		print("   Creating mappings...")
		locFile.createInitialHappnAndroidMappingForStdRefLoc()
		
		print("   Writing transformed file...")
		var stream = try FileHandleOutputStream(forPath: transformedFilePath)
		print(locFile, terminator: "", to: &stream)
		print("Done")
	}

}

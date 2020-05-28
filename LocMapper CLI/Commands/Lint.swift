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



struct Lint : ParsableCommand {
	
	@OptionGroup()
	var csvOptions: CSVOptions
	
	@Option(default: false)
	var detectUnusedRefloc: Bool
	
	@Argument()
	var inputFile: String
	
	func run() throws {
		let csvSeparator = csvOptions.csvSeparator
		
		func keyToStr(_ k: LocFile.LineKey, withFilename: Bool = true) -> String {
			return "<" + k.env + (withFilename ? " / " + k.filename : "") + " / " + k.locKey + ">"
		}
		
		guard FileManager.default.fileExists(atPath: inputFile) else {
			throw ValidationError("No file found at path \(inputFile)")
		}
		let locFile = try LocFile(fromPath: inputFile, withCSVSeparator: csvSeparator)
		for report in locFile.lint(detectUnusedRefLoc: detectUnusedRefloc) {
			switch report {
			case .unlocalizedFilename(let filename):             print("warning: found key(s) whose filename \"\(filename)\" is not localized", to: &stderrStream)
			case .invalidMapping(let key):                       print("warning: found invalid mapping for key \(keyToStr(key))", to: &stderrStream)
			case .unusedRefLoc(let key):                         print("warning: found unused RefLoc key \(keyToStr(key, withFilename: false))", to: &stderrStream)
			case .unmappedVariant(let base, let key):            print("warning: found unmapped key \(keyToStr(key, withFilename: false)) (variant of mapped base key \(base.locKey))", to: &stderrStream)
			case .multipleKeyVersionsMapped(let mapped):         print("warning: found multiple versions of same key mapped: \(mapped.map{ keyToStr($0, withFilename: false) }.joined(separator: ", "))", to: &stderrStream)
			case .notLatestKeyVersion(let actual, let expected): print("warning: found key not mapped at its latest version (got \(keyToStr(actual, withFilename: false)), expected \(keyToStr(expected, withFilename: false)))", to: &stderrStream)
			}
		}
	}
	
}

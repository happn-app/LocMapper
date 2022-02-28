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



/**
 Parses an option list like locmapper did before using Apple’s ArgumentParser.
 
 If the given array only have one element and contains a comma,
 we assume the user has used the obsolete list option format
 and we split the only argument using the comma separator.
 
 It is thus impossible when using this method to get an array containing one element that contains a comma.
 We take the risk for now (the previous situation was worse), and might remove this function altogether later. */
func parseObsoleteOptionList(_ array: [String]) -> [String]? {
	guard !array.isEmpty else {return nil}
	guard let e = array.first, array.count == 1, e.contains(",") else {
		return array
	}
	return e.split(separator: ",").map(String.init)
}


func dictionaryOptionFromArray(_ array: [String], allowEmpty: Bool = false) throws -> [String: String] {
	let keys = stride(from: array.startIndex, to: array.endIndex, by: 2).map{ array[$0] }
	let values = stride(from: array.index(after: array.startIndex), to: array.endIndex, by: 2).map{ array[$0] }
	guard (allowEmpty || !keys.isEmpty) && keys.count == values.count else {
		throw ValidationError("The array argument must not be empty and contain an even number of elements (alternance of keys and values)")
	}
	return Dictionary(zip(keys, values), uniquingKeysWith: { _, new in new })
}


extension LocFile.MergeStyle : ExpressibleByArgument {
	
	public init?(argument: String) {
		switch argument {
			case "add":     self = .add
			case "replace": self = .replace
			default:        return nil
		}
	}
	
}

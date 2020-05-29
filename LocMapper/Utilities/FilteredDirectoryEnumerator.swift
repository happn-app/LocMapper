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



public struct FilteredDirectoryEnumerator : Sequence, IteratorProtocol {
	
	public let rootDirectoryURL: URL
	
	public let includedPaths: [String]?
	public let excludedPaths: [String]?
	
	public let pathPrefixes: [String]?
	public let pathSuffixes: [String]?

	let directoryEnumerator: FileManager.DirectoryEnumerator
	
	public init?(url: URL, includedPaths: [String]? = nil, excludedPaths: [String]? = nil, pathPrefixes: [String]? = nil, pathSuffixes: [String]? = nil, fileManager: FileManager = .default) {
		self.init(path: url.path, includedPaths: includedPaths, excludedPaths: excludedPaths, pathPrefixes: pathPrefixes, pathSuffixes: pathSuffixes, fileManager: fileManager)
	}
	
	public init?(path: String, includedPaths: [String]? = nil, excludedPaths: [String]? = nil, pathPrefixes: [String]? = nil, pathSuffixes: [String]? = nil, fileManager: FileManager = .default) {
		guard let de = fileManager.enumerator(atPath: path) else {
			return nil
		}
		self.init(directoryEnumerator: de, rootDirectoryURL: URL(fileURLWithPath: path, isDirectory: true), includedPaths: includedPaths, excludedPaths: excludedPaths, pathPrefixes: pathPrefixes, pathSuffixes: pathSuffixes)
	}
	
	public init(directoryEnumerator de: FileManager.DirectoryEnumerator, rootDirectoryURL rootURL: URL, includedPaths ip: [String]? = nil, excludedPaths ep: [String]? = nil, pathPrefixes prefixes: [String]? = nil, pathSuffixes suffixes: [String]? = nil) {
		rootDirectoryURL = rootURL
		includedPaths = ip
		excludedPaths = ep
		pathPrefixes = prefixes
		pathSuffixes = suffixes
		directoryEnumerator = de
	}
	
	public mutating func next() -> URL? {
		guard let nextPath = directoryEnumerator.nextObject() as! String? else {
			return nil
		}
		
		if let includedPaths = includedPaths {
			guard includedPaths.contains(where: { nextPath.range(of: $0) != nil }) else {
				return next()
			}
		}
		
		if let excludedPaths = excludedPaths {
			guard !excludedPaths.contains(where: { nextPath.range(of: $0) != nil }) else {
				return next()
			}
		}
		
		if let pathPrefixes = pathPrefixes {
			guard pathPrefixes.contains(where: { nextPath.hasPrefix($0) }) else {
				return next()
			}
		}
		
		if let pathSuffixes = pathSuffixes {
			guard pathSuffixes.contains(where: { nextPath.hasSuffix($0) }) else {
				return next()
			}
		}
		
		return URL(fileURLWithPath: nextPath, relativeTo: rootDirectoryURL)
	}
	
}

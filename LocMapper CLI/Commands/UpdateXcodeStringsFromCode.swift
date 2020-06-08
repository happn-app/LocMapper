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



#if os(macOS)

struct UpdateXcodeStringsFromCode : ParsableCommand {
	
	struct UpdateError : Error {
		
		var message: String
		
	}
	
	static var configuration = CommandConfiguration(
		commandName: "update_xcode_strings_from_code",
		abstract: "Analyse the code in the Xcode project and updates the strings file accordingly.",
		discussion: """
			This command requires ibtool and genstrings. It is available on macOS only.
			
			There are basically two types of strings files in an Xcode project: the ones linked to a storyboard or xib, and the ones you use in the code.
			
			The command will first deal with storyboard/xibs. It will use ibtool to generate the strings from the storyboards and xibs, and then (and this is the clever bit), will merge the generated files into the existing ones if any. The merge will not modify the comments above already existing entries, and will add new entries at the end of the files. For storyboard and xibs, the merge will remove entries that are not present in the new file.
			The storyboards and xibs are expected to be in “Base.lproj” folder.
			
			Then the code is treated. This time, genstrings is used. If you need to process SwiftUI files, pass the --swift-ui option (it is not (yet?) possible to process a part of the project as SwiftUI and the rest as a classic project). You can use defines (or global variables) in your code to specify the table name; pass the equivalence in the arguments of the command. Be careful though, the defines are replaced with a simple string matching; no effort is made to only replace table names (a check is done to replace full words, not parts of words).
			The merge of the strings files for the code is the same as the one for storboards and xibs, but this time no entries are removed from the strings file by default. A message is printed for keys that should be deleted. Use the --delete-missing-keys to automatically delete those.
			"""
	)
	
	@Option(help: "The paths in which the lproj files are contained (for the source localizations; storyboards/xibs are localized wherever). Required if the code is not skipped.")
	var localizablesPath: String?
	
	@Option(help: "List of paths to exclude when reading the project.")
	var excludeList: [String]
	
	@Option(help: "List of paths to only include when reading the project.")
	var includeList: [String]
	
	@Option(help: "A file containing a list of strings files that are not used in the code but are still needed (one path per line, relative to the project’s root).")
	var unusedStringsfilesFilesList: String?
	
	@Option(help: "A file containing a list of storyboards/xibs that are not localized (one path per line, relative to the project’s root).")
	var unlocalizedXibsFilesList: String?
	
	@Option(help: "The languages to update (lproj folder names without the extension). Defaults to “en”.")
	var languages: [String]
	
	@Flag(help: "Enable this option to pass the -SwiftUI option to genstring.")
	var swiftUI: Bool
	
	@Option(default: "utf16")
	var encoding: String
	
	@Flag(help: "Enable this option to automatically delete the keys that are not found in the code but are present in the strings file. For storyboards/xibs, missing keys are always removed.")
	var deleteMissingKeys: Bool
	
	@Flag()
	var skipStoryboardsAndXibs: Bool
	
	@Flag()
	var skipCode: Bool
	
	@Argument()
	var rootFolder: String
	
	@Argument(help: #"Pass “MY_TABLE MyTable” (two arguments) to convert `NSLocalizedString("MyString", tableName: MY_TABLE, comment: "This comment!")` into `NSLocalizedString("MyString", tableName: "MyTable", comment: "This comment!")` for instance."#)
	var tableDefinesToValuesMapping: [String]
	
	func run() throws {
		let languages = parseObsoleteOptionList(self.languages) ?? ["en"]
		
		let encoding: String.Encoding
		switch self.encoding.lowercased() {
		case "utf8",  "utf-8":  encoding = .utf8
		case "utf16", "utf-16": encoding = .utf16
		default:
			throw ValidationError("Unsupported encoding \(self.encoding)")
		}
		
		let excludeList = parseObsoleteOptionList(self.excludeList)
		let includeList = parseObsoleteOptionList(self.includeList)
		
		let tableDefinesToValues = try dictionaryOptionFromArray(tableDefinesToValuesMapping, allowEmpty: true)
		
		guard !skipStoryboardsAndXibs || !skipCode else {
			/* There’s nothing to do! */
			return
		}
		
		guard skipCode || localizablesPath != nil else {
			throw ValidationError("The localizables-path option is required when the code strings update is not skipped.")
		}
		
		let fm = FileManager.default
		let projectRootURL = URL(fileURLWithPath: rootFolder, isDirectory: true)
		let runLockURL = projectRootURL.appendingPathComponent(".locmapper__update_xcode_strings_from_code.lock")
		
		let unlocalizedXibsPaths = try readFilesList(unlocalizedXibsFilesList, relativeTo: projectRootURL, fileManager: fm)
		let unusedStringsfilesPaths = try readFilesList(unusedStringsfilesFilesList, relativeTo: projectRootURL, fileManager: fm)
		
		/* *** Check there is no strings update *** */
		
		guard !fm.fileExists(atPath: runLockURL.path) else {
			throw UpdateError(message: "There seems to be a locmapper strings update already in progress. If you’re sure there is not, manually delete the file at path \(runLockURL.path)")
		}
		fm.createFile(atPath: runLockURL.path, contents: nil, attributes: nil)
		defer {
			if (try? fm.removeItem(at: runLockURL)) == nil {
				print("Cannot remove update lock. Please manually remove file at path \(runLockURL.path)", to: &stderrStream)
			}
		}
		
		/* *** Copy relevant repository files to a temporary location *** */
		
		let projectCloneRootURL = fm.temporaryDirectory.appendingPathComponent(projectRootURL.lastPathComponent + "_" + UUID().uuidString, isDirectory: true)
		print("Copying relevant project files to temporary location \(projectCloneRootURL)")
		
		try fm.createDirectory(at: projectCloneRootURL, withIntermediateDirectories: true, attributes: nil)
		defer {_ = try? fm.removeItem(at: projectCloneRootURL)} /* We don’t really care if the delete fails… */
		
		guard let dirEnumerator = FilteredDirectoryEnumerator(url: projectRootURL, includedPaths: includeList, excludedPaths: excludeList, fileManager: fm) else {
			throw UpdateError(message: "Cannot enumerate files at path \(projectRootURL.path)")
		}
		for sourceURL in dirEnumerator {
			let destinationURL = URL(fileURLWithPath: sourceURL.relativePath, relativeTo: projectCloneRootURL)
			guard let isDir = try sourceURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory else {
				throw UpdateError(message: "Cannot check if path is directory \(sourceURL.path)")
			}
			
			guard !isDir else {continue}
			
			try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
			try fm.copyItem(at: sourceURL, to: destinationURL)
		}
		
		/* *** Finding and treating storyboard and xib files *** */
		if !skipStoryboardsAndXibs {
			print("Treating storyboards and xibs")
			
			guard let dirEnumeratorForStoryboardsAndXibs = FilteredDirectoryEnumerator(url: projectCloneRootURL, pathSuffixes: [".storyboard", ".xib"], fileManager: fm) else {
				throw UpdateError(message: "Cannot enumerate files at path \(projectCloneRootURL.path)")
			}
			for xibURL in dirEnumeratorForStoryboardsAndXibs {
				let parentFolderName = xibURL.deletingLastPathComponent().lastPathComponent
				guard parentFolderName == "Base.lproj" else {
					if !isURL(xibURL, containedInPathsList: unlocalizedXibsPaths, rootURL: projectCloneRootURL) {
						print("*** WARNING: File “\(xibURL.relativePath)” does not seem to be localized.", to: &stderrStream)
					}
					continue
				}
				
				let baseDirURL = xibURL.deletingLastPathComponent()/*Remove xib name*/.deletingLastPathComponent()/*Remove Base.lproj*/
				let xibName = xibURL.deletingPathExtension().lastPathComponent
				for language in languages {
					let tempDestinationStringsURL = baseDirURL.appendingPathComponent(language + ".lproj").appendingPathComponent(xibName + ".strings")
					let destinationStringsURL = URL(fileURLWithPath: tempDestinationStringsURL.relativePath, relativeTo: projectRootURL)
					/* First let’s read the original strings file */
					let originalParsedStringsFile: XcodeStringsFile?
					if fm.fileExists(atPath: tempDestinationStringsURL.path) {
						guard let stringsFile = try? XcodeStringsFile(fromPath: tempDestinationStringsURL.relativePath, relativeToProjectPath: projectCloneRootURL.path) else {
							print("***** ERROR: Cannot read strings file at path “\(tempDestinationStringsURL.relativePath)”. Skipping this file.", to: &stderrStream)
							continue
						}
						originalParsedStringsFile = stringsFile
					} else {
						originalParsedStringsFile = nil
					}
					/* Then create a new strings file with ibtool. We do not even create
					 * it at the same location as it is not mandatory. */
					let temporaryStringsFileURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".strings")
					defer {_ = try? fm.removeItem(at: temporaryStringsFileURL)} /* We don’t care if the delete fails */
					let exitCode = finishedProcess(launchPath: "/usr/bin/ibtool", arguments: ["--export-strings-file", temporaryStringsFileURL.path, xibURL.path])
					guard exitCode == 0 else {
						print("***** ERROR: ibtool failed producing strings file for “\(xibURL.relativePath)” (language was \(language)). Skipping this file.", to: &stderrStream)
						continue
					}
					/* Now reading the newly produced strings file. */
					guard let newParsedStringsFile = try? XcodeStringsFile(fromPath: temporaryStringsFileURL.path, relativeToProjectPath: "/") else {
						print("***** ERROR: Cannot read strings file generated by ibtool for “\(xibURL.relativePath)” (language was \(language)). Skipping this file.", to: &stderrStream)
						continue
					}
					/* Now we merge the two strings files (if we have a previous one). */
					var obsoleteKeys: [String]? = nil
					let mergedStringsFile = XcodeStringsFile(merging: newParsedStringsFile, in: originalParsedStringsFile, obsoleteKeys: &obsoleteKeys, filepath: destinationStringsURL.path)
					
					/* Then we write the merged strings file at the expected destination. */
					try writeXcodeStringsFile(mergedStringsFile, at: destinationStringsURL, encoding: encoding, fileManager: fm)
				}
			}
		}
		
		/* *** Finding and treating storyboard and xib files *** */
		if !skipCode, let localizablesPath = localizablesPath {
			print("Treating code")
			
			guard let dirEnumeratorForCode = FilteredDirectoryEnumerator(url: projectCloneRootURL, pathSuffixes: [".swift", ".m", ".mm", ".c", ".cpp"], fileManager: fm) else {
				throw UpdateError(message: "Cannot enumerate files at path \(projectCloneRootURL.path)")
			}
			/* First let’s patch the code (in the clone). */
			let regexesAndValues = try tableDefinesToValues.map{ keyVal -> (NSRegularExpression, String) in
				let (tableDefine, tableValue) = keyVal
				let tableRegex = try NSRegularExpression(pattern: #"\b\#(NSRegularExpression.escapedPattern(for: tableDefine))\b"#, options: [])
				return (tableRegex, tableValue)
			}
			var codeFilePaths = [String]()
			for codeURL in dirEnumeratorForCode {
				let objcMark = (Set(arrayLiteral: "m", "mm").contains(codeURL.pathExtension) ? "@" : "")
				var code = try String(contentsOf: codeURL)
				for (regex, value) in regexesAndValues {
					code = regex.stringByReplacingMatches(in: code, options: [], range: NSRange(code.startIndex..<code.endIndex, in: code), withTemplate: objcMark + "\"" + NSRegularExpression.escapedTemplate(for: value) + "\"")
				}
				try Data(code.utf8).write(to: codeURL)
				codeFilePaths.append(codeURL.path)
			}
			/* Then we run genstrings in a temporary folder */
			let temporaryGenstringsDestinationFolderURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
			try fm.createDirectory(at: temporaryGenstringsDestinationFolderURL, withIntermediateDirectories: true, attributes: nil)
			defer {_ = try? fm.removeItem(at: temporaryGenstringsDestinationFolderURL)} /* We don’t care if the delete fails */
			/* We process the code files in bulk, but limited to the arbitrary
			 * limit 250 files (so that there are no more than 256 arguments to
			 * genstrings). The 256 limit is arbitrary. We should be able to use
			 * ARG_MAX, but the value for this parameter is ridiculously high and
			 * it won’t work (we have reached the limit at a lower value). */
			let size = 250
			for start in stride(from: codeFilePaths.startIndex, to: codeFilePaths.endIndex, by: size) {
				let subarray = codeFilePaths[start..<min(start + size, codeFilePaths.endIndex)]
				let code = finishedProcess(launchPath: "/usr/bin/genstrings", arguments: (swiftUI ? ["-SwiftUI"] : []) + ["-q", "-o", temporaryGenstringsDestinationFolderURL.path] + subarray)
				guard code == 0 else {
					throw UpdateError(message: "genstrings failed; not treating code locs")
				}
			}
			/* Let’s parse all the strings from genstrings. */
			guard let dirEnumeratorForGenstringsStringsfiles = FilteredDirectoryEnumerator(url: temporaryGenstringsDestinationFolderURL, pathSuffixes: [".strings"], fileManager: fm) else {
				throw UpdateError(message: "Cannot enumerate files at path \(temporaryGenstringsDestinationFolderURL.path)")
			}
			var genstringsStringsfiles = [String: XcodeStringsFile]()
			for stringsfile in dirEnumeratorForGenstringsStringsfiles {
				do {
					genstringsStringsfiles[stringsfile.relativePath] = try XcodeStringsFile(fromPath: stringsfile.path, relativeToProjectPath: "/")
				} catch {
					print("*** WARNING: genstrings generated a strings file (\(stringsfile.relativePath)) whose parsing failed. Ignoring this file. Error was \(error)", to: &stderrStream)
				}
			}
			/* Merge the strings we got from genstrings and the ones we already had. */
			for language in languages {
				let lprojURL = URL(fileURLWithPath: localizablesPath, relativeTo: projectCloneRootURL).appendingPathComponent(language + ".lproj", isDirectory: true)
				try fm.createDirectory(at: lprojURL, withIntermediateDirectories: true, attributes: nil)
				guard let dirEnumerator = FilteredDirectoryEnumerator(url: lprojURL, pathSuffixes: [".strings"], fileManager: fm) else {
					print("*** WARNING: Cannot enumerate files at path \(lprojURL.relativePath); ignoring files in this folder.", to: &stderrStream)
					continue
				}
				var foundStringsfile = Set<String>()
				for stringsfile in dirEnumerator {
					let stringsfileURLRelativeToProject = lprojURL.appendingPathComponent(stringsfile.relativePath)
					foundStringsfile.insert(stringsfile.relativePath)
					
					guard let newStringsfile = genstringsStringsfiles[stringsfile.relativePath] else {
						if !isURL(stringsfileURLRelativeToProject, containedInPathsList: unusedStringsfilesPaths, rootURL: projectCloneRootURL) {
							print("*** WARNING: File “\(stringsfileURLRelativeToProject.relativePath)” does not seem to be used in the project.", to: &stderrStream)
						}
						continue
					}
					
					let parsedStringsfile: XcodeStringsFile
					do {
						parsedStringsfile = try XcodeStringsFile(fromPath: stringsfile.path, relativeToProjectPath: "/")
					} catch {
						print("*** WARNING: Found strings file (\(stringsfileURLRelativeToProject.relativePath)) in project which cannot be parsed. Error was \(error)", to: &stderrStream)
						continue
					}
					
					var obsoleteKeys: [String]? = (deleteMissingKeys ? nil : [])
					let mergedStringsfile = XcodeStringsFile(merging: newStringsfile, in: parsedStringsfile, obsoleteKeys: &obsoleteKeys, filepath: stringsfileURLRelativeToProject.relativePath)
					try writeXcodeStringsFile(mergedStringsfile, at: URL(fileURLWithPath: stringsfileURLRelativeToProject.relativePath, relativeTo: projectRootURL), encoding: encoding, fileManager: fm)
					for obsoleteKey in (obsoleteKeys ?? []) {
						print("*** WARNING: Found seemingly obsolete key “\(obsoleteKey)” in file (\(stringsfileURLRelativeToProject.relativePath)).", to: &stderrStream)
					}
				}
				for (stringsfileName, parsedFile) in genstringsStringsfiles.filter({ !foundStringsfile.contains($0.key) }) {
					/* Writing new strings file (was not already in the project) */
					try writeXcodeStringsFile(parsedFile, at: URL(fileURLWithPath: lprojURL.relativePath, relativeTo: projectRootURL).appendingPathComponent(stringsfileName), encoding: encoding, fileManager: fm)
				}
			}
		}
	}
	
	private func readFilesList(_ path: String?, relativeTo rootURL: URL, fileManager fm: FileManager) throws -> [String] {
		guard let url = path.flatMap({ URL(fileURLWithPath: $0, relativeTo: rootURL) }) else {
			return []
		}
		
		var res = [String]()
		let content = try String(contentsOf: url)
		content.enumerateLines{ line, stop in
			guard !line.hasPrefix("#") else {return}
			res.append(line)
		}
		return res
	}
	
	private func isURL(_ url: URL, containedInPathsList pathsList: [String], rootURL: URL) -> Bool {
		return pathsList.contains{ url == URL(fileURLWithPath: $0, relativeTo: rootURL) }
	}
	
	private func writeXcodeStringsFile(_ stringsFile: XcodeStringsFile, at url: URL, encoding: String.Encoding, fileManager fm: FileManager) throws {
		try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
		
		var stringsText = ""
		print(stringsFile, terminator: "", to: &stringsText)
		
		guard let data = stringsText.data(using: encoding, allowLossyConversion: false) else {
			throw UpdateError(message: "Cannot convert strings file to required encoding")
		}
		
		try data.write(to: url)
	}
	
	private func finishedProcess(launchPath: String, arguments: [String]) -> Int32 {
		let outputPipe = Pipe()
		let errorPipe = Pipe()
		
		let p = Process()
		p.launchPath = launchPath
		p.arguments = arguments
		p.standardInput = nil
		p.standardOutput = outputPipe
		p.standardError = errorPipe
		
		p.launch()
		p.waitUntilExit()
		
		print(data2str(outputPipe.fileHandleForReading.readDataToEndOfFile()), terminator: "")
		print(data2str(errorPipe.fileHandleForReading.readDataToEndOfFile()), terminator: "", to: &stderrStream)
		return p.terminationStatus
	}
	
	private func data2str(_ data: Data) -> String {
		if let str = String(data: data, encoding: .utf8) {
			return str
		}
		return data.reduce("", { $0 + String(format: "%02x", $1) })
	}
	
}

#endif

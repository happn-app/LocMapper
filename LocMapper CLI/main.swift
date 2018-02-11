/*
 * main.swift
 * LocMapper CLI
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

import LocMapper



func usage<TargetStream: TextOutputStream>(program_name: String, stream: inout TargetStream) {
	print("""
	Usage: \(program_name) command [args ...]
	
	Commands are:
	   version
	      Shows the current version of the tool
	
	   merge_xcode_locs [--csv_separator=separator] [--exclude-list=excluded_path,...] [--include-list=included_path,...] root_folder output_file.lcm folder_language_name human_language_name [folder_language_name human_language_name ...]
	      Merges (or creates if output does not exists) all the .strings files in the
	      project in output_file.lcm.
	      Excludes strings whose path match any item in the any exclude list.
	      If an include list is given, also filter paths not matching any item in the
	      include list.
	
		export_to_xcode [--encoding=encoding] [--csv_separator=separator] input_file.lcm root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]
	      Exports locs from the given input lcm in the Xcode project at the root_folder path.
	      Strings files are written as UTF-16 by default. Supported encoding for the --encoding option are utf8 and utf16.
	
	   merge_android_locs [--csv_separator=separator] [--res-folder=res_folder] [--strings-filenames=name,...] root_folder output_file.lcm folder_language_name human_language_name [folder_language_name human_language_name ...]
	      Merges (or creates if output does not exists) the given strings files in output_file.lcm.
	
	   export_to_android [--csv_separator=separator] [--strings-filenames=name,...] input_file.lcm root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]
	      Exports locs from the given input lcm in the Android project at the root_folder path.
	
	For all the actions, the default CSV separator is a comma (\",\"). The CSV separator must be a one-char-only string.
	""", to: &stream)
}

/* Returns the arg at the given index, or prints "Syntax error: error_message"
 * and the usage, then exits with syntax error if there is not enough arguments
 * given to the program */
func argAtIndexOrExit(_ i: Int, error_message: String) -> String {
	guard CommandLine.arguments.count > i else {
		print("Syntax error: \(error_message)", to: &stderrStream)
		usage(program_name: CommandLine.arguments[0], stream: &stderrStream)
		exit(1)
	}
	
	return CommandLine.arguments[i]
}

func getFolderToHumanLanguageNamesFromIndex(_ i: Int) -> [String: String] {
	var folder_name_to_language_name = [String: String]()
	
	var i = i
	while i < CommandLine.arguments.count {
		let folder_name = argAtIndexOrExit(i, error_message: "INTERNAL ERROR"); i += 1
		let language_name = argAtIndexOrExit(i, error_message: "Language name is required for a given folder name"); i += 1
		guard folder_name_to_language_name[folder_name] == nil else {
			print("Syntax error: Folder name \(folder_name) defined more than once", to: &stderrStream)
			usage(program_name: CommandLine.arguments[0], stream: &stderrStream)
			exit(1)
		}
		folder_name_to_language_name[folder_name] = language_name
	}
	
	guard folder_name_to_language_name.count > 0 else {
		print("Syntax error: Expected at least one language. Got none.", to: &stderrStream)
		usage(program_name: CommandLine.arguments[0], stream: &stderrStream)
		exit(1)
	}
	
	return folder_name_to_language_name
}

/* Takes the current arg position in input and a dictionary of long args names
 * with the corresponding action to execute when the long arg is found.
 * Returns the new arg position when all long args have been found. */
func getLongArgs(argIdx: Int, longArgs: [String: (String) -> Void]) -> Int {
	var i = argIdx
	
	func stringByDeletingPrefixIfPresent(_ prefix: String, from string: String) -> String? {
		if string.hasPrefix(prefix) {
			return String(string.dropFirst(prefix.count))
		}
		
		return nil
	}
	
	
	longArgLoop: while true {
		let arg = argAtIndexOrExit(i, error_message: "Syntax error"); i += 1
		
		for (longArg, action) in longArgs {
			if let no_prefix = stringByDeletingPrefixIfPresent("--\(longArg)=", from: arg) {
				action(no_prefix)
				continue longArgLoop
			}
		}
		
		if arg != "--" {i -= 1}
		break
	}
	
	return i
}


let basePathForTests = "/Users/frizlab/Documents/Projects"
//let basePathForTests = "/Users/frizlab/Work/Doing/FTW and Co"

let folderNameToLanguageNameForTests = [
	"en.lproj": " English", "fr.lproj": "Français — French", "de.lproj": "Deutsch — German",
	"it.lproj": "Italiano — Italian", "es.lproj": "Español — Spanish", "pt.lproj": "Português brasileiro — Portuguese (Brasil)",
	"pt-PT.lproj": "Português europeu — Portuguese (Portugal)", "tr.lproj": "Türkçe — Turkish",
	"zh-Hant.lproj": "中文(香港) — Chinese (Traditional)", "th.lproj": "ภาษาไทย — Thai", "ja.lproj": "日本語 — Japanese",
	"pl.lproj": "Polszczyzna — Polish", "hu.lproj": "Magyar — Hungarian", "ru.lproj": "Русский язык — Russian",
	"he.lproj": "עברית — Hebrew", "ko.lproj": "한국어 — Korean"
]
let androidLanguageFolderNamesForTests = [
	"values": " English"/*, "values-fr": "Français — French", "values-de": "Deutsch — German",
	"values-it": "Italiano — Italian", "values-es": "Español — Spanish", "values-pt-rBR": "Português brasileiro — Portuguese (Brasil)",
	"values-pt": "Português europeu — Portuguese (Portugal)", "values-tr": "Türkçe — Turkish",
	"values-zh": "中文(香港) — Chinese (Traditional)", "values-th": "ภาษาไทย — Thai", "values-ja": "日本語 — Japanese",
	"values-pl": "Polszczyzna — Polish" , "values-hu": "Magyar — Hungarian", "values-ru": "Русский язык — Russian",*/
	/*"values-he": "עברית — Hebrew", "values-ko": "한국어 — Korean"*/
]

var csvSeparator = ","
switch argAtIndexOrExit(1, error_message: "Command is required") {
	/* Version */
	case "version":
		let hdl = dlopen(nil, 0)
		defer {if let hdl = hdl {dlclose(hdl)}}
		if let versionNumber = hdl.flatMap({ dlsym($0, "locmapperVersionNumber") })?.assumingMemoryBound(to: Double.self).pointee {
			print("locmapper version \(Int(versionNumber))")
			exit(0)
		} else {
			print("Cannot get version number", to: &stderrStream)
			exit(2)
		}
	
	/* Merge Xcode Locs */
	case "merge_xcode_locs":
		var i = 2
		
		var included_paths: [String]?
		var excluded_paths = [String]()
		i = getLongArgs(argIdx: i, longArgs: [
			"exclude-list":  {(value: String) in excluded_paths = value.components(separatedBy: ",")},
			"include-list":  {(value: String) in included_paths = value.components(separatedBy: ",")},
			"csv_separator": {(value: String) in csvSeparator = value}]
		)
		
		let root_folder = argAtIndexOrExit(i, error_message: "Root folder is required"); i += 1
		let output = argAtIndexOrExit(i, error_message: "Output is required"); i += 1
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Merging from Xcode project...")
		do {
			print("   Finding and parsing Xcode locs...")
			let parsedXcodeStringsFiles = try XcodeStringsFile.stringsFilesInProject(root_folder, excluded_paths: excluded_paths, included_paths: included_paths)
			print("   Parsing original LocMapper file...")
			let locFile = try LocFile(fromPath: output, withCSVSeparator: csvSeparator)
			print("   Merging...")
			locFile.mergeXcodeStringsFiles(parsedXcodeStringsFiles, folderNameToLanguageName: folder_name_to_language_name)
			print("   Writing merged file...")
			var stream = try FileHandleOutputStream(forPath: output)
			print(locFile, terminator: "", to: &stream)
			print("Done")
		} catch let error as NSError {
			print("Got error while merging: \(error)", to: &stderrStream)
			exit(Int32(error.code))
		}
		exit(0)
	
	/* Export to Xcode */
	case "export_to_xcode":
		var i = 2
		
		var encodingStr = "utf16"
		i = getLongArgs(argIdx: i, longArgs: [
			"encoding": {(value: String) in encodingStr = value},
			"csv_separator": {(value: String) in csvSeparator = value}]
		)
		
		let encoding: String.Encoding
		switch encodingStr.lowercased() {
		case "utf8", "utf-8": encoding = .utf8
		case "utf16", "utf-16": encoding = .utf16
		default:
			print("Unsupported encoding \(encodingStr)", to: &stderrStream)
			exit(1)
		}
		
		let input_path = argAtIndexOrExit(i, error_message: "Input file is required"); i += 1
		let root_folder = argAtIndexOrExit(i, error_message: "Root folder is required"); i += 1
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Exporting to Xcode project...")
		do {
			print("   Parsing LocMapper file...")
			let locFile = try LocFile(fromPath: input_path, withCSVSeparator: csvSeparator)
			print("   Writing locs to Xcode project...")
			locFile.exportToXcodeProjectWithRoot(root_folder, folderNameToLanguageName: folder_name_to_language_name, encoding: encoding)
			print("Done")
		} catch let error as NSError {
			print("Got error while exporting: \(error)", to: &stderrStream)
			exit(Int32(error.code))
		}
		exit(0)
	
	/* Export from Android */
	case "merge_android_locs":
		var i = 2
		
		var res_folder = "res"
		var strings_filenames = [String]()
		i = getLongArgs(argIdx: i, longArgs: [
			"res-folder":        {(value: String) in res_folder = value},
			"strings-filenames": {(value: String) in strings_filenames = value.components(separatedBy: ",")},
			"csv_separator":     {(value: String) in csvSeparator = value}]
		)
		if strings_filenames.count == 0 {strings_filenames.append("strings.xml")}
		
		let root_folder = argAtIndexOrExit(i, error_message: "Root folder is required"); i += 1
		let output = argAtIndexOrExit(i, error_message: "Output is required"); i += 1
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Exporting from Android project...")
		do {
			print("   Parsing Android locs...")
			let parsedAndroidLocFiles = try AndroidXMLLocFile.locFilesInProject(root_folder, resFolder: res_folder, stringsFilenames: strings_filenames, languageFolderNames: Array(folder_name_to_language_name.keys))
			print("   Parsing original LocMapper file...")
			let locFile = try LocFile(fromPath: output, withCSVSeparator: csvSeparator)
			print("   Merging...")
			locFile.mergeAndroidXMLLocStringsFiles(parsedAndroidLocFiles, folderNameToLanguageName: folder_name_to_language_name)
			print("   Writing merged file...")
			var stream = try FileHandleOutputStream(forPath: output)
			print(locFile, terminator: "", to: &stream)
			print("Done")
		} catch let error as NSError {
			print("Got error while exporting: \(error)", to: &stderrStream)
			exit(Int32(error.code))
		}
		exit(0)
	
	/* Import to Android */
	case "export_to_android":
		var i = 2
		
		var strings_filenames = [String]()
		i = getLongArgs(argIdx: i, longArgs: [
			"strings-filenames": {(value: String) in strings_filenames = value.components(separatedBy: ",")},
			"csv_separator":     {(value: String) in csvSeparator = value}]
		)
		if strings_filenames.count == 0 {strings_filenames.append("strings.xml")}
		
		let input_path = argAtIndexOrExit(i, error_message: "Input file (CSV) is required"); i += 1
		let root_folder = argAtIndexOrExit(i, error_message: "Root folder is required"); i += 1
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Exporting to Android project...")
		do {
			print("   Parsing LocMapper file...")
			let csv = try LocFile(fromPath: input_path, withCSVSeparator: csvSeparator)
			print("   Writing locs to Android project...")
			csv.exportToAndroidProjectWithRoot(root_folder, folderNameToLanguageName: folder_name_to_language_name)
			print("Done")
		} catch let error as NSError {
			print("Got error while exporting: \(error)", to: &stderrStream)
			exit(Int32(error.code))
		}
		exit(0)
	
	default:
		print("Unknown command \(CommandLine.arguments[1])", to: &stderrStream)
		usage(program_name: CommandLine.arguments[0], stream: &stderrStream)
		exit(2)
}

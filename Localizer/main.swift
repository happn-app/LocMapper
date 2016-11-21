/*
 * main.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation



func usage<TargetStream: TextOutputStream>(program_name: String, stream: inout TargetStream) {
	print("Usage: \(program_name) command [args ...]", to: &stream)
	print("", to: &stream)
	print("Commands are:", to: &stream)
	print("   export_from_xcode [--csv_separator=separator] [--exclude=excluded_path ...] root_folder output_file.csv folder_language_name human_language_name [folder_language_name human_language_name ...]", to: &stream)
	print("      Exports and merges all the .strings files in the project to output_file.csv, excluding all paths containing any excluded_path", to: &stream)
	print("", to: &stream)
	print("   import_to_xcode [--csv_separator=separator] input_file.csv root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]", to: &stream)
	print("      Imports and merges input_file.csv to the existing .strings in the project", to: &stream)
	print("", to: &stream)
	print("   export_from_android [--csv_separator=separator] [--res-folder=res_folder] [--strings-filename=name ...] root_folder output_file.csv folder_language_name human_language_name [folder_language_name human_language_name ...]", to: &stream)
	print("      Exports and merges the localization files of the android project to output_file.csv", to: &stream)
	print("", to: &stream)
	print("   import_to_android [--csv_separator=separator] [--res-folder=res_folder] [--strings-filename=name ...] input_file.csv root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]", to: &stream)
	print("      Imports and merges input_file.csv to the existing strings files of the android project", to: &stream)
	print("", to: &stream)
	print("For all the actions, the default CSV separator is a comma (\",\"). The CSV separator must be a one-char-only string.", to: &stream)
}

/* Returns the arg at the given index, or prints "Syntax error: error_message"
 * and the usage, then exits with syntax error if there is not enough arguments
 * given to the program */
func argAtIndexOrExit(_ i: Int, error_message: String) -> String {
	guard CommandLine.arguments.count > i else {
		print("Syntax error: \(error_message)", to: &mx_stderr)
		usage(program_name: CommandLine.arguments[0], stream: &mx_stderr)
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
			print("Syntax error: Folder name \(folder_name) defined more than once", to: &mx_stderr)
			usage(program_name: CommandLine.arguments[0], stream: &mx_stderr)
			exit(1)
		}
		folder_name_to_language_name[folder_name] = language_name
	}
	
	guard folder_name_to_language_name.count > 0 else {
		print("Syntax error: Expected at least one language. Got none.", to: &mx_stderr)
		usage(program_name: CommandLine.arguments[0], stream: &mx_stderr)
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
			return string[string.index(string.startIndex, offsetBy: prefix.characters.count)..<string.endIndex]
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
	"values": " English", "values-fr": "Français — French", "values-de": "Deutsch — German",
	"values-it": "Italiano — Italian", "values-es": "Español — Spanish", "values-pt-rBR": "Português brasileiro — Portuguese (Brasil)",
	"values-pt": "Português europeu — Portuguese (Portugal)", "values-tr": "Türkçe — Turkish",
	"values-zh": "中文(香港) — Chinese (Traditional)", "values-th": "ภาษาไทย — Thai", "values-ja": "日本語 — Japanese",
	"values-pl": "Polszczyzna — Polish" /*, "values-hu": "Magyar — Hungarian", "values-ru": "Русский язык — Russian",
	"values-he": "עברית — Hebrew", "values-ko": "한국어 — Korean"*/
]

var csvSeparator = ","
switch argAtIndexOrExit(1, error_message: "Command is required") {
	/* Export from Xcode */
	case "export_from_xcode":
		var i = 2
		
		var excluded_paths = [String]()
		i = getLongArgs(argIdx: i, longArgs: [
			"exclude":       {(value: String) in excluded_paths.append(value)},
			"csv_separator": {(value: String) in csvSeparator = value}]
		)
		
		let root_folder = argAtIndexOrExit(i, error_message: "Root folder is required"); i += 1
		var output = argAtIndexOrExit(i, error_message: "Output is required"); i += 1
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Exporting from Xcode project...")
		do {
			let parsed_strings_files = try XcodeStringsFile.stringsFilesInProject(root_folder, excluded_paths: excluded_paths)
			let csv = try happnCSVLocFile(fromPath: output, withCSVSeparator: csvSeparator)
			csv.mergeXcodeStringsFiles(parsed_strings_files, folderNameToLanguageName: folder_name_to_language_name)
			var csvText = ""
			print(csv, terminator: "", to: &csvText)
			try writeText(csvText, toFile: output, usingEncoding: String.Encoding.utf8)
		} catch let error as NSError {
			print("Got error while exporting: \(error)")
			exit(Int32(error.code))
		}
		exit(0)
	
	/* Import to Xcode */
	case "import_to_xcode":
		var i = 2
		
		i = getLongArgs(argIdx: i, longArgs: ["csv_separator": {(value: String) in csvSeparator = value}])
		
		let input_path = argAtIndexOrExit(i, error_message: "Input file is required"); i += 1
		let root_folder = argAtIndexOrExit(i, error_message: "Root folder is required"); i += 1
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Importing to Xcode project...")
		do {
			let csv = try happnCSVLocFile(fromPath: input_path, withCSVSeparator: csvSeparator)
			csv.exportToXcodeProjectWithRoot(root_folder, folderNameToLanguageName: folder_name_to_language_name)
		} catch let error as NSError {
			print("Got error while importing: \(error)")
			exit(Int32(error.code))
		}
		exit(0)
	
	/* Export from Android */
	case "export_from_android":
		var i = 2
		
		var res_folder = "res"
		var strings_filenames = [String]()
		i = getLongArgs(argIdx: i, longArgs: [
			"res-folder":       {(value: String) in res_folder = value},
			"strings-filename": {(value: String) in strings_filenames.append(value)},
			"csv_separator":    {(value: String) in csvSeparator = value}]
		)
		if strings_filenames.count == 0 {strings_filenames.append("strings.xml")}
		
		let root_folder = argAtIndexOrExit(i, error_message: "Root folder is required"); i += 1
		let output = argAtIndexOrExit(i, error_message: "Output is required"); i += 1
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Exporting from Android project...")
		do {
			let parsed_loc_files = try AndroidXMLLocFile.locFilesInProject(root_folder, resFolder: res_folder, stringsFilenames: strings_filenames, languageFolderNames: Array(folder_name_to_language_name.keys))
			let csv = try happnCSVLocFile(fromPath: output, withCSVSeparator: csvSeparator)
			csv.mergeAndroidXMLLocStringsFiles(parsed_loc_files, folderNameToLanguageName: folder_name_to_language_name)
			var csvText = ""
			print(csv, terminator: "", to: &csvText)
			try writeText(csvText, toFile: output, usingEncoding: String.Encoding.utf8)
		} catch let error as NSError {
			print("Got error while exporting: \(error)")
			exit(Int32(error.code))
		}
		exit(0)
	
	/* Import to Android */
	case "import_to_android":
		var i = 2
		
		var res_folder = "res"
		var strings_filenames = [String]()
		i = getLongArgs(argIdx: i, longArgs: [
			"res-folder":       {(value: String) in res_folder = value},
			"strings-filename": {(value: String) in strings_filenames.append(value)},
			"csv_separator":    {(value: String) in csvSeparator = value}]
		)
		if strings_filenames.count == 0 {strings_filenames.append("strings.xml")}
		
		let input_path = argAtIndexOrExit(i, error_message: "Input file (CSV) is required"); i += 1
		let root_folder = argAtIndexOrExit(i, error_message: "Root folder is required"); i += 1
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Importing to Android project...")
		do {
			let csv = try happnCSVLocFile(fromPath: input_path, withCSVSeparator: csvSeparator)
			csv.exportToAndroidProjectWithRoot(root_folder, folderNameToLanguageName: folder_name_to_language_name)
		} catch let error as NSError {
			print("Got error while importing: \(error)")
			exit(Int32(error.code))
		}
		exit(0)
	
	/* Convenient command for debug purposes */
	case "test_xcode_export":
		guard let parsed_strings_files = try? XcodeStringsFile.stringsFilesInProject("\(basePathForTests)/happn/", excluded_paths: ["Dependencies/", ".git/"]) else {
			print("Error reading Xcode strings files", to: &mx_stderr)
			exit(255)
		}
		guard let csv = try? happnCSVLocFile(fromPath: "\(basePathForTests)/ loc.csv", withCSVSeparator: ",") else {
			print("Error reading CSV Loc file", to: &mx_stderr)
			exit(255)
		}
		csv.mergeXcodeStringsFiles(parsed_strings_files, folderNameToLanguageName: folderNameToLanguageNameForTests)
		print("CSV: ")
		print(csv, terminator: "")
		var csvText = ""
		print(csv, terminator: "", to: &csvText)
		_ = try? writeText(csvText, toFile: "\(basePathForTests)/ loc.csv", usingEncoding: String.Encoding.utf8)
		exit(0)
	
	/* Convenient command for debug purposes */
	case "test_xcode_import":
		guard let csv = try? happnCSVLocFile(fromPath: "\(basePathForTests)/ loc.csv", withCSVSeparator: ",") else {
			print("Error reading CSV Loc file", to: &mx_stderr)
			exit(255)
		}
		csv.exportToXcodeProjectWithRoot("\(basePathForTests)/happn/", folderNameToLanguageName: folderNameToLanguageNameForTests)
		exit(0)
	
	/* Convenient command for debug purposes */
	case "test_android_export":
		guard let parsed_strings_files = try? AndroidXMLLocFile.locFilesInProject("\(basePathForTests)/HappnAndroid/", resFolder: "happn/src/main/res", stringsFilenames: ["strings.xml"], languageFolderNames: Array(androidLanguageFolderNamesForTests.keys).sorted()) else {
			print("Error reading Android strings files", to: &mx_stderr)
			exit(255)
		}
		guard let csv = try? happnCSVLocFile(fromPath: "\(basePathForTests)/ loc.csv", withCSVSeparator: ",") else {
			print("Error reading CSV Loc file", to: &mx_stderr)
			exit(255)
		}
		csv.mergeAndroidXMLLocStringsFiles(parsed_strings_files, folderNameToLanguageName: androidLanguageFolderNamesForTests)
		print("CSV: ")
		print(csv, terminator: "")
		var csvText = ""
		print(csv, terminator: "", to: &csvText)
		_ = try? writeText(csvText, toFile: "\(basePathForTests)/ loc.csv", usingEncoding: String.Encoding.utf8)
		exit(0)
	
	/* Convenient command for debug purposes */
	case "test_android_import":
		guard let csv = try? happnCSVLocFile(fromPath: "\(basePathForTests)/ loc android ref.happnloc", withCSVSeparator: ",") else {
			print("Error reading CSV Loc file", to: &mx_stderr)
			exit(255)
		}
		csv.exportToAndroidProjectWithRoot("\(basePathForTests)/HappnAndroid/happn/src/main/res/", folderNameToLanguageName: androidLanguageFolderNamesForTests)
		exit(0)
	
	default:
		print("Unknown command \(CommandLine.arguments[1])", to: &mx_stderr)
		usage(program_name: CommandLine.arguments[0], stream: &mx_stderr)
		exit(2)
}

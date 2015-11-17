/*
 * main.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

func usage<TargetStream: OutputStreamType>(program_name: String, inout stream: TargetStream) {
	print("Usage: \(program_name) command [args ...]", toStream: &stream)
	print("", toStream: &stream)
	print("Commands are:", toStream: &stream)
	print("   export_from_xcode [--csv_separator=separator] [--exclude=excluded_path ...] root_folder output_file.csv folder_language_name human_language_name [folder_language_name human_language_name ...]", toStream: &stream)
	print("      Exports and merges all the .strings files in the project to output_file.csv, excluding all paths containing any excluded_path", toStream: &stream)
	print("", toStream: &stream)
	print("   import_to_xcode [--csv_separator=separator] input_file.csv root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]", toStream: &stream)
	print("      Imports and merges input_file.csv to the existing .strings in the project", toStream: &stream)
	print("", toStream: &stream)
	print("   export_from_android [--csv_separator=separator] [--res-folder=res_folder] [--strings-filename=name ...] root_folder output_file.csv folder_language_name human_language_name [folder_language_name human_language_name ...]", toStream: &stream)
	print("      Exports and merges the localization files of the android project to output_file.csv", toStream: &stream)
	print("", toStream: &stream)
	print("   import_to_android [--csv_separator=separator] [--res-folder=res_folder] [--strings-filename=name ...] input_file.csv root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]", toStream: &stream)
	print("      Imports and merges input_file.csv to the existing strings files of the android project", toStream: &stream)
	print("", toStream: &stream)
	print("For all the actions, the default CSV separator is a comma (\",\"). The CSV separator must be a one-char-only string.", toStream: &stream)
}

/* Returns the arg at the given index, or prints "Syntax error: error_message"
 * and the usage, then exits with syntax error if there is not enough arguments
 * given to the program */
func argAtIndexOrExit(i: Int, error_message: String) -> String {
	guard Process.arguments.count > i else {
		print("Syntax error: \(error_message)", toStream: &mx_stderr)
		usage(Process.arguments[0], stream: &mx_stderr)
		exit(1)
	}
	
	return Process.arguments[i]
}

func getFolderToHumanLanguageNamesFromIndex(var i: Int) -> [String: String] {
	var folder_name_to_language_name = [String: String]()
	
	while i < Process.arguments.count {
		let folder_name = argAtIndexOrExit(i++, error_message: "INTERNAL ERROR")
		let language_name = argAtIndexOrExit(i++, error_message: "Language name is required for a given folder name")
		guard folder_name_to_language_name[folder_name] == nil else {
			print("Syntax error: Folder name \(folder_name) defined more than once", toStream: &mx_stderr)
			usage(Process.arguments[0], stream: &mx_stderr)
			exit(1)
		}
		folder_name_to_language_name[folder_name] = language_name
	}
	
	guard folder_name_to_language_name.count > 0 else {
		print("Syntax error: Expected at least one language. Got none.", toStream: &mx_stderr)
		usage(Process.arguments[0], stream: &mx_stderr)
		exit(1)
	}
	
	return folder_name_to_language_name
}

/* Takes the current arg position in input and a dictionary of long args names
 * with the corresponding action to execute when the long arg is found.
 * Returns the new arg position when all long args have been found. */
func getLongArgs(argIdx: Int, longArgs: [String: (String) -> Void]) -> Int {
	var i = argIdx
	
	func stringByDeletingPrefixIfPresent(prefix: String, from string: String) -> String? {
		if string.hasPrefix(prefix) {
			var start_idx = string.startIndex
			for _ in 0..<prefix.characters.count {start_idx = start_idx.successor()} /* There doesn't seem to be any easier way to do this... */
			return string[start_idx..<string.endIndex]
		}
		
		return nil
	}
	
	
	longArgLoop: while true {
		let arg = argAtIndexOrExit(i++, error_message: "Syntax error")
		
		for (longArg, action) in longArgs {
			if let no_prefix = stringByDeletingPrefixIfPresent("--\(longArg)=", from: arg) {
				action(no_prefix)
				continue longArgLoop
			}
		}
		
		if arg != "--" {--i}
		break
	}
	
	return i
}

func writeText(text: String, toFile filePath: String, usingEncoding encoding: NSStringEncoding) throws {
	if let data = text.dataUsingEncoding(encoding, allowLossyConversion: false) {
		if NSFileManager.defaultManager().fileExistsAtPath(filePath) {
			try NSFileManager.defaultManager().removeItemAtPath(filePath)
		}
		if !NSFileManager.defaultManager().createFileAtPath(filePath, contents: nil, attributes: nil) {
			throw NSError(domain: "LocalizerErrDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot file at path \(filePath)"])
		}
		if let output_stream = NSFileHandle(forWritingAtPath: filePath) {
			output_stream.writeData(data)
			return
		} else {
			throw NSError(domain: "LocalizerErrDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open file at path \(filePath) for writing"])
		}
	} else {
		throw NSError(domain: "LocalizerErrDomain", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot convert text to expected encoding"])
	}
}

var csvSeparator = ","
switch argAtIndexOrExit(1, error_message: "Command is required") {
	/* Export from Xcode */
	case "export_from_xcode":
		var i = 2
		
		var excluded_paths = [String]()
		i = getLongArgs(i, longArgs: [
			"exclude":       {(value: String) in excluded_paths.append(value)},
			"csv_separator": {(value: String) in csvSeparator = value}]
		)
		
		let root_folder = argAtIndexOrExit(i++, error_message: "Root folder is required")
		var output = argAtIndexOrExit(i++, error_message: "Output is required")
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		print("Exporting from Xcode project...")
		
		var err: NSError?
		var got_error = true
		do {
			let parsed_strings_files = try XcodeStringsFile.stringsFilesInProject(root_folder, excluded_paths: excluded_paths)
			do {
				let csv = try happnCSVLocFile(fromPath: output, withCSVSeparator: csvSeparator)
				csv.mergeXcodeStringsFiles(parsed_strings_files, folderNameToLanguageName: folder_name_to_language_name)
				var csvText = ""
				print(csv, terminator: "", toStream: &csvText)
				do {
					try writeText(csvText, toFile: output, usingEncoding: NSUTF8StringEncoding)
					got_error = false
				} catch var error as NSError {
					err = error
				}
			} catch var error as NSError {
				err = error
			}
		} catch var error as NSError {
			err = error
		}
		if got_error {
			print("Got error while exporting: \(err)")
			exit(err != nil ? Int32(err!.code) : 255)
		} else {
			exit(0)
		}
	
	/* Import to Xcode */
	case "import_to_xcode":
		var i = 2
		
		i = getLongArgs(i, longArgs: ["csv_separator": {(value: String) in csvSeparator = value}])
		
		let input_path = argAtIndexOrExit(i++, error_message: "Input file is required")
		let root_folder = argAtIndexOrExit(i++, error_message: "Root folder is required")
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Importing to Xcode project...")
		var err: NSError?;
		do {
			let csv = try happnCSVLocFile(fromPath: input_path, withCSVSeparator: csvSeparator)
			csv.exportToXcodeProjectWithRoot(root_folder, folderNameToLanguageName: folder_name_to_language_name)
		} catch var error as NSError {
			err = error
		}
	
	/* Export from Android */
	case "export_from_android":
		var i = 2
		
		var res_folder = "res"
		var strings_filenames = [String]()
		i = getLongArgs(i, longArgs: [
			"res-folder":       {(value: String) in res_folder = value},
			"strings-filename": {(value: String) in strings_filenames.append(value)},
			"csv_separator":    {(value: String) in csvSeparator = value}]
		)
		if strings_filenames.count == 0 {strings_filenames.append("strings.xml")}
		
		let root_folder = argAtIndexOrExit(i++, error_message: "Root folder is required")
		let output = argAtIndexOrExit(i++, error_message: "Output is required")
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		print("Exporting from Android project...")
		
		var err: NSError?
		var got_error = true
		do {
			let parsed_loc_files = try AndroidXMLLocFile.locFilesInProject(root_folder, resFolder: res_folder, stringsFilenames: strings_filenames, languageFolderNames: Array(folder_name_to_language_name.keys))
			do {
				let csv = try happnCSVLocFile(fromPath: output, withCSVSeparator: csvSeparator)
				csv.mergeAndroidXMLLocStringsFiles(parsed_loc_files, folderNameToLanguageName: folder_name_to_language_name)
				var csvText = ""
				print(csv, terminator: "", toStream: &csvText)
				do {
					try writeText(csvText, toFile: output, usingEncoding: NSUTF8StringEncoding)
					got_error = false
				} catch var error as NSError {
					err = error
				}
			} catch var error as NSError {
				err = error
			}
		} catch var error as NSError {
			err = error
		}
		if got_error {
			print("Got error while exporting: \(err)")
			exit(err != nil ? Int32(err!.code) : 255)
		} else {
			exit(0)
		}
	
	/* Import to Android */
	case "import_to_android":
		var i = 2
		
		var res_folder = "res"
		var strings_filenames = [String]()
		i = getLongArgs(i, longArgs: [
			"res-folder":       {(value: String) in res_folder = value},
			"strings-filename": {(value: String) in strings_filenames.append(value)},
			"csv_separator":    {(value: String) in csvSeparator = value}]
		)
		if strings_filenames.count == 0 {strings_filenames.append("strings.xml")}
		
		let input_path = argAtIndexOrExit(i++, error_message: "Input file (CSV) is required")
		let root_folder = argAtIndexOrExit(i++, error_message: "Root folder is required")
		let folder_name_to_language_name = getFolderToHumanLanguageNamesFromIndex(i)
		
		print("Importing to Android project...")
		var err: NSError?;
		do {
			let csv = try happnCSVLocFile(fromPath: input_path, withCSVSeparator: csvSeparator)
			csv.exportToAndroidProjectWithRoot(root_folder, folderNameToLanguageName: folder_name_to_language_name)
		} catch var error as NSError {
			err = error
		}
	
	/* Convenient command for debug purposes */
	case "test_xcode_export":
		var err: NSError?;
		do {
			let parsed_strings_files = try XcodeStringsFile.stringsFilesInProject("/Users/frizlab/Documents/Projects/Happn/", excluded_paths: ["Dependencies/", ".git/"])
			do {
				let csv = try happnCSVLocFile(fromPath: "/Users/frizlab/Documents/Projects/ loc.csv", withCSVSeparator: ",")
				csv.mergeXcodeStringsFiles(parsed_strings_files, folderNameToLanguageName: ["en.lproj": "English", "fr.lproj": "Français", "de.lproj": "Deutsch", "es.lproj": "Español", "it.lproj": "Italiano", "pt.lproj": "Português"])
				var csvText = ""
				print(csv, terminator: "", toStream: &csvText)
				do {
					try writeText(csvText, toFile: "/Users/frizlab/Documents/Projects/ loc.csv", usingEncoding: NSUTF8StringEncoding)
				} catch var error as NSError {
					err = error
				}
//				println("CSV: ")
//				print(csv)
			} catch var error as NSError {
				err = error
			}
		} catch var error as NSError {
			err = error
		}
	
	/* Convenient command for debug purposes */
	case "test_xcode_import":
		var err: NSError?;
		do {
			let csv = try happnCSVLocFile(fromPath: "/Users/frizlab/Documents/Projects/ loc.csv", withCSVSeparator: ",")
			csv.exportToXcodeProjectWithRoot("/Users/frizlab/Documents/Projects/Happn/", folderNameToLanguageName: [
				"en.lproj": "English", "fr.lproj": "Français — French", "de.lproj": "Deutsch — German",
				"it.lproj": "Italiano — Italian", "es.lproj": "Español — Spanish", "pt.lproj": "Português brasileiro — Portuguese (Brasil)",
				"pt-PT.lproj": "Português europeu — Portuguese (Portugal)", "tr.lproj": "Türkçe — Turkish",
				"zh-Hant.lproj": "中文(香港) — Chinese (Traditional)", "th.lproj": "ภาษาไทย — Thai", "ja.lproj": "日本語 — Japanese",
				"pl.lproj": "Polszczyzna — Polish", "hu.lproj": "Magyar — Hungarian", "ru.lproj": "Русский язык — Russian",
				"he.lproj": "עברית — Hebrew", "ko.lproj": "한국어 — Korean"
			])
		} catch var error as NSError {
			err = error
		}
	
	/* Convenient command for debug purposes */
	case "test_android_export":
		var err: NSError?;
		do {
			let parsed_loc_files = try AndroidXMLLocFile.locFilesInProject("/Users/frizlab/Documents/Projects/HappnAndroid/", resFolder: "happn-android/Happn/src/main/res", stringsFilenames: ["strings.xml"], languageFolderNames: ["values", "values-de", "values-es", "values-fr"])
			do {
				let csv = try happnCSVLocFile(fromPath: "/Users/frizlab/Documents/Projects/ loc.csv", withCSVSeparator: ",")
				csv.mergeAndroidXMLLocStringsFiles(parsed_loc_files, folderNameToLanguageName: ["values": "English", "values-fr": "Français", "values-de": "Deutsch", "values-es": "Español", "values-it": "Italiano", "values-pt": "Português"])
				var csvText = ""
				print(csv, terminator: "", toStream: &csvText)
				do {
					try writeText(csvText, toFile: "/Users/frizlab/Documents/Projects/ loc.csv", usingEncoding: NSUTF8StringEncoding)
				} catch var error as NSError {
					err = error
				}
//				println("CSV: ")
//				print(csv)
			} catch var error as NSError {
				err = error
			}
		} catch var error as NSError {
			err = error
		}
	
	/* Convenient command for debug purposes */
	case "test_android_import":
		var err: NSError?;
		do {
			let csv = try happnCSVLocFile(fromPath: "/Users/frizlab/Documents/Projects/ loc.csv", withCSVSeparator: ",")
			csv.exportToAndroidProjectWithRoot("/Users/frizlab/Documents/Projects/HappnAndroid/", folderNameToLanguageName: ["values": "English", "values-fr": "Français", "values-de": "Deutsch", "values-es": "Español"/*, "values-it": "Italiano", "values-pt": "Português"*/])
		} catch var error as NSError {
			err = error
		}
	
	default:
		print("Unknown command \(Process.arguments[1])", toStream: &mx_stderr)
		usage(Process.arguments[0], stream: &mx_stderr)
		exit(2)
}

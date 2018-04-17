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
	
	   merge_lokalise_trads_as_stdrefloc [--csv_separator=separator] lokalise_r_token lokalise_project_id merged_file.lcm refloc_language_name lokalise_language_name [refloc_language_name lokalise_language_name ...]
	      Fetch ref loc from lokalise and merge in given lcm file, converting into the StdRefLoc format.
	
	   merge_lokalise_trads_as_xibrefloc [--csv_separator=separator] lokalise_r_token lokalise_project_id merged_file.lcm refloc_language_name lokalise_language_name [refloc_language_name lokalise_language_name ...]
	      Fetch ref loc from lokalise and merge in given lcm file, converting into the XibRefLoc format.
	
	   standardize_refloc [--csv_separator=separator] input_file.csv output_file.csv language1 [language2 ...]
	      Standardize a Xib or Std RefLoc file and “standardize” it. This removes comments, etc.
	      Only the data is kept; all the metadata is gotten rid of. The keys are sorted alphabetically.
	
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
		let language_name = argAtIndexOrExit(i, error_message: "Language name is required for given folder name \(folder_name)"); i += 1
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


var i = 2
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
	
case "merge_lokalise_trads_as_stdrefloc":
	i = getLongArgs(argIdx: i, longArgs: [
		"csv_separator": {(value: String) in csvSeparator = value}]
	)
	let token = argAtIndexOrExit(i, error_message: "Lokalise token is required"); i += 1
	let project_id = argAtIndexOrExit(i, error_message: "Lokalise project id is required"); i += 1
	let merged_path = argAtIndexOrExit(i, error_message: "Input file is required"); i += 1
	let refloc_to_lokalise_language_name = getFolderToHumanLanguageNamesFromIndex(i)
	print("Merging Lokalise Trads as StdRefLoc in LocFile...")
	do {
		print("   Parsing source...")
		let locFile = try LocFile(fromPath: merged_path, withCSVSeparator: csvSeparator)
		
		/** TODO: The Merge **/
		
		print("   Writing merged file...")
		var stream = try FileHandleOutputStream(forPath: merged_path)
		print(locFile, terminator: "", to: &stream)
		print("Done")
	} catch {
		print("Got error while converting: \(error)", to: &stderrStream)
		exit(Int32((error as NSError).code))
	}
	
case "merge_lokalise_trads_as_xibrefloc":
	i = getLongArgs(argIdx: i, longArgs: [
		"csv_separator": {(value: String) in csvSeparator = value}]
	)
	let token = argAtIndexOrExit(i, error_message: "Lokalise token is required"); i += 1
	let project_id = argAtIndexOrExit(i, error_message: "Lokalise project id is required"); i += 1
	let merged_path = argAtIndexOrExit(i, error_message: "Input file is required"); i += 1
	let refloc_to_lokalise_language_name = getFolderToHumanLanguageNamesFromIndex(i)
	print("Merging Lokalise Trads as XibRefLoc in LocFile...")
	do {
		print("   Parsing source...")
		let locFile = try LocFile(fromPath: merged_path, withCSVSeparator: csvSeparator)
		
		/** TODO: The Merge **/
		
		print("   Writing merged file...")
		var stream = try FileHandleOutputStream(forPath: merged_path)
		print(locFile, terminator: "", to: &stream)
		print("Done")
	} catch {
		print("Got error while converting: \(error)", to: &stderrStream)
		exit(Int32((error as NSError).code))
	}
	
case "standardize_refloc":
	i = getLongArgs(argIdx: i, longArgs: [
		"csv_separator": {(value: String) in csvSeparator = value}]
	)
	var languages = [String]()
	let input_path = argAtIndexOrExit(i, error_message: "Input file is required"); i += 1
	let output_path = argAtIndexOrExit(i, error_message: "Output file is required"); i += 1
	repeat {
		languages.append(argAtIndexOrExit(i, error_message: "At least one language is required")); i += 1
	} while i < CommandLine.arguments.count
	
	print("Standardizing Ref Loc...")
	do {
		/* We use XibRefLocFile to parse and output the file because this format
		 * does not do any transformation on the values it reads and outputs. */
		print("   Parsing source...")
		let f = try XibRefLocFile(fromURL: URL(fileURLWithPath: input_path, isDirectory: false), languages: languages, csvSeparator: csvSeparator)
		
		print("   Merging in Loc File...")
		let locFile = LocFile()
		locFile.mergeRefLocsWithXibRefLocFile(f)
		
		print("   Exporting Loc File to Ref Loc...")
		locFile.exportXibRefLoc(to: output_path, csvSeparator: csvSeparator)
		print("Done")
	} catch {
		print("Got error while converting: \(error)", to: &stderrStream)
		exit(Int32((error as NSError).code))
	}
	
	exit(0)
	
case "convert_xibrefloc_to_stdrefloc":
	/* Original doc (removed from help because the command should not be used...):
	 *    convert_xibrefloc_to_stdrefloc [--csv_separator=separator] input_file.csv output_file.csv language1 [language2 ...]
	 *       Take a XibLoc-styled RefLoc (with tokens for plurals, gender, etc.) and convert it to a more
	 *       usual format (one key per plural/gender/etc. variations). */
	i = getLongArgs(argIdx: i, longArgs: [
		"csv_separator": {(value: String) in csvSeparator = value}]
	)
	var languages = [String]()
	let input_path = argAtIndexOrExit(i, error_message: "Input file is required"); i += 1
	let output_path = argAtIndexOrExit(i, error_message: "Output file is required"); i += 1
	repeat {
		languages.append(argAtIndexOrExit(i, error_message: "At least one language is required")); i += 1
	} while i < CommandLine.arguments.count
	
	print("Converting from Xib Ref Loc to Std Ref Loc...")
	do {
		print("   Parsing source...")
		let f = try XibRefLocFile(fromURL: URL(fileURLWithPath: input_path, isDirectory: false), languages: languages, csvSeparator: csvSeparator)
		print("   Converting to Std Ref Loc...")
		let s = StdRefLocFile(xibRefLoc: f)
		
		print("   Merging in Loc File...")
		let locFile = LocFile()
		locFile.mergeRefLocsWithStdRefLocFile(s)
		
		print("   Exporting Loc File to Std Ref Loc...")
		locFile.exportStdRefLoc(to: output_path, csvSeparator: csvSeparator)
		print("Done")
	} catch {
		print("Got error while converting: \(error)", to: &stderrStream)
		exit(Int32((error as NSError).code))
	}
	
	exit(0)
	
case "convert_stdrefloc_to_xibrefloc":
	/* Original doc (removed from help because the command should not be used...):
	 *    convert_stdrefloc_to_xibrefloc [--csv_separator=separator] input_file.csv output_file.csv language1 [language2 ...]
	 *       Does the inverse of convert_xibrefloc_to_stdrefloc. */
	i = getLongArgs(argIdx: i, longArgs: [
		"csv_separator": {(value: String) in csvSeparator = value}]
	)
	var languages = [String]()
	let input_path = argAtIndexOrExit(i, error_message: "Input file is required"); i += 1
	let output_path = argAtIndexOrExit(i, error_message: "Output file is required"); i += 1
	repeat {
		languages.append(argAtIndexOrExit(i, error_message: "At least one language is required")); i += 1
	} while i < CommandLine.arguments.count
	
	print("Converting from Std Ref Loc to Xib Ref Loc...")
	do {
		print("   Parsing source...")
		let f = try StdRefLocFile(fromURL: URL(fileURLWithPath: input_path, isDirectory: false), languages: languages, csvSeparator: csvSeparator)
		print("   Converting to Xib Ref Loc...")
		let s = try XibRefLocFile(stdRefLoc: f)
		
		print("   Merging in Loc File...")
		let locFile = LocFile()
		locFile.mergeRefLocsWithXibRefLocFile(s)
		
		print("   Exporting Loc File to Xib Ref Loc...")
		locFile.exportXibRefLoc(to: output_path, csvSeparator: csvSeparator)
		print("Done")
	} catch {
		print("Got error while converting: \(error)", to: &stderrStream)
		exit(Int32((error as NSError).code))
	}
	
	exit(0)
	
case "upload_xibrefloc_to_lokalise":
	/* Original doc (removed from help because the command should not be used...):
	 *    upload_xibrefloc_to_lokalise [--csv_separator=separator] lokalise_rw_token lokalise_project_id input_file.csv refloc_language_name lokalise_language_name [refloc_language_name lokalise_language_name ...]
	 *       Upload an Xib Ref Loc file to lokalise. DROPS EVERYTHING IN THE PROJECT (but does a snapshot first).
	 *       The translations will be marked for platform “Other.”*/
	i = getLongArgs(argIdx: i, longArgs: [
		"csv_separator": {(value: String) in csvSeparator = value}]
	)
	let token = argAtIndexOrExit(i, error_message: "Lokalise token is required"); i += 1
	let project_id = argAtIndexOrExit(i, error_message: "Lokalise project id is required"); i += 1
	let input_path = argAtIndexOrExit(i, error_message: "Input file is required"); i += 1
	let refloc_to_lokalise_language_name = getFolderToHumanLanguageNamesFromIndex(i)
	
	print("Uploading Xib Ref Loc to Localize project \(project_id)...")
	do {
		print("   Parsing source...")
		let xibLoc = try XibRefLocFile(fromURL: URL(fileURLWithPath: input_path, isDirectory: false), languages: Array(refloc_to_lokalise_language_name.keys), csvSeparator: csvSeparator)
		
		print("   Exporting Loc File to Lokalise...")
		try xibLoc.exportToLokalise(token: token, projectId: project_id, reflocToLokaliseLanguageName: refloc_to_lokalise_language_name, takeSnapshot: true, logPrefix: "      ")
		print("Done")
	} catch {
		print("Got error while uploading: \(error)", to: &stderrStream)
		exit(Int32((error as NSError).code))
	}
	
default:
	print("Unknown command \(CommandLine.arguments[1])", to: &stderrStream)
	usage(program_name: CommandLine.arguments[0], stream: &stderrStream)
	exit(2)
}

/*
 * main.swift
 * Localizer
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

func usage<TargetStream : OutputStreamType>(program_name: String, inout stream: TargetStream) {
	println("Usage: \(program_name) command [args ...]", &stream)
	println("", &stream)
	println("Commands are:", &stream)
	println("   export_xcode root_folder [--exclude=excluded_path ...] output_file.csv folder_language_name human_language_name [folder_language_name human_language_name ...]", &stream)
	println("      Exports all the .strings files in the project to output_file.csv, excluding all paths containing any excluded_path", &stream)
	println("", &stream)
	println("   import_xcode input_file.csv root_folder folder_language_name human_language_name [folder_language_name human_language_name ...]", &stream)
	println("      Imports and merge input_file.csv to the existing .strings in the project", &stream)
	println("", &stream)
	println("   export_android output_file.csv file_name language_name [file_name language_name ...]", &stream)
	println("      Exports the given files to output_file.csv", &stream)
	println("", &stream)
	println("   import_android input_file.csv file_name language_name [file_name language_name ...]", &stream)
	println("      Imports and merge output_file.csv in the given files", &stream)
}

/* Returns the arg at the given index, or prints "Syntax error: error_message"
 * and the usage, then exits with syntax error if there is not enough arguments
 * given to the program */
func argAtIndexOrExit(i: Int, error_message: String) -> String {
	if Process.arguments.count <= i {
		println("Syntax error: \(error_message)", &mx_stderr)
		usage(Process.arguments[0], &mx_stderr)
		exit(1)
	}
	
	return Process.arguments[i]
}

switch argAtIndexOrExit(1, "Command is required") {
	case "export_xcode":
		var i = 2
		let root_folder = argAtIndexOrExit(i++, "Root folder is required")
		var next_arg = argAtIndexOrExit(i++, "Output is required")
		var excluded_paths = [String]()
		while next_arg.hasPrefix("--exclude=") {
			var start_idx = next_arg.startIndex
			for _ in 0..<10 {start_idx = start_idx.successor()} /* There doesn't seem to be any easier way to do this... */
			excluded_paths.append(next_arg[start_idx..<next_arg.endIndex])
			next_arg = argAtIndexOrExit(i++, "Output is required")
		}
		let output = next_arg
		var folder_name_to_language_name = [String: String]()
		while i < Process.arguments.count {
			let folder_name = argAtIndexOrExit(i++, "INTERNAL ERROR")
			let language_name = argAtIndexOrExit(i++, "Language name is required for a given folder name")
			if folder_name_to_language_name[folder_name] != nil {
				println("Syntax error: Folder name \(folder_name) defined more than once", &mx_stderr)
				usage(Process.arguments[0], &mx_stderr)
				exit(1)
			}
			folder_name_to_language_name[folder_name] = language_name
		}
		if folder_name_to_language_name.count == 0 {
			println("Syntax error: Expected at least one language. Got none.", &mx_stderr)
			usage(Process.arguments[0], &mx_stderr)
			exit(1)
		}
		println("Exporting from Xcode project...")
		
		if !NSFileManager.defaultManager().changeCurrentDirectoryPath(root_folder) {
			println("Cannot change current directly to path \(root_folder). Cancelling export.")
			exit(2)
		}
		if let e = NSFileManager.defaultManager().enumeratorAtPath(root_folder) {
			var parsed_strings_files = [XcodeStringsFile]()
			while let cur_file = e.nextObject() as? String {
				if cur_file.hasSuffix(".strings") {
					var is_excluded = false
					for excluded in excluded_paths {
						if cur_file.rangeOfString(excluded) != nil {
							is_excluded = true
							break
						}
					}
					if !is_excluded {
						/* We have a non-excluded strings file. Let's parse it. */
						var err: NSError?
						let xcodeStringsFileQ = XcodeStringsFile(fromPath: cur_file, error: &err)
						if let xcodeStringsFile = xcodeStringsFileQ {
							parsed_strings_files.append(xcodeStringsFile)
						} else {
							println("*** Warning: Got error while parsing strings file \(cur_file): \(err)")
						}
					}
				}
			}
			let csv = happnCSVLocFile(filepath: output, stringsFiles: parsed_strings_files, folderNameToLanguageName: folder_name_to_language_name)
			println("CSV:")
			print(csv)
			println("All Done")
		} else {
			println("Cannot list files at path \(root_folder). Cancelling export.")
			exit(2)
		}
	case "import_xcode":
		println("Importing to Xcode project...")
	default:
		println("Unknown command \(Process.arguments[1])", &mx_stderr)
		usage(Process.arguments[0], &mx_stderr)
		exit(2)
}

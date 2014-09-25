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
	println("   export_xcode root_folder [--exlude=excluded_path ...] output_file.csv folder_language_name human_language_name [folder_language_name human_language_name ...]", &stream)
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


if Process.arguments.count < 2 {
	println("Syntax error", &mx_stderr)
	usage(Process.arguments[0], &mx_stderr)
	exit(1)
}

switch Process.arguments[1] {
	case "export_xcode":
		println("Exporting from Xcode project")
	case "import_xcode":
		println("Importing to Xcode project")
	default:
		println("Unknown command \(Process.arguments[1])", &mx_stderr)
		usage(Process.arguments[0], &mx_stderr)
		exit(2)
}

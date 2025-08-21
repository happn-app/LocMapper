/*
 * main.swift
 * LocMapper CLI
 *
 * Created by François Lamboley on 2014-09-25.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

import ArgumentParser

import LocMapper



struct LocMapperCLI : ParsableCommand {
	
	static let version = "41" /* Do not remove this token, it is used by a script: __VERSION_LINE_TOKEN__ */
	
	/**
	 This _only_ works in a debug build on macOS. */
	static var dynVersion: String? {
		let hdl = dlopen(nil, 0)
		defer {if let hdl = hdl {dlclose(hdl)}}
		guard let versionNumber = hdl.flatMap({ dlsym($0, "locmapperVersionNumber") })?.assumingMemoryBound(to: Double.self).pointee else {
			return nil
		}
		return "\(Int(versionNumber))"
	}
	
#if os(macOS)
	static let platformSpecificCommands: [ParsableCommand.Type] = [UpdateXcodeStringsFromCode.self]
#else
	static let platformSpecificCommands: [ParsableCommand.Type] = []
#endif
	
	static let configuration = CommandConfiguration(
		commandName: "locmapper",
		abstract: "A utility for working w/ LocMapper (*.lcm) files.",
		version: dynVersion ?? version,
		subcommands: [
			/* The two subcommands below should be deleted. */
			Help.self, Version.self,
			
			MergeXcodeLocs.self,   ExportToXcode.self,
			MergeAndroidLocs.self, ExportToAndroid.self,
			
			MergeStdrefloc.self,
			
			Lint.self,
			StandardizeRefloc.self,
			
			Experimental.self
		]
		+ platformSpecificCommands
	)
	
	@OptionGroup var csvOptions: CSVOptions
	@OptionGroup var logOptions: LoggingOptions
	
}


LocMapperCLI.main()

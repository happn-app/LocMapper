/*
 * main.swift
 * LocMapper CLI
 *
 * Created by François Lamboley on 9/25/14.
 * Copyright (c) 2014 happn. All rights reserved.
 */

import Foundation

import ArgumentParser

import LocMapper



struct LocMapperCLI : ParsableCommand {
	
	static var version: String? {
		#warning("TODO: Version on Linux!")
		let hdl = dlopen(nil, 0)
		defer {if let hdl = hdl {dlclose(hdl)}}
		guard let versionNumber = hdl.flatMap({ dlsym($0, "locmapperVersionNumber") })?.assumingMemoryBound(to: Double.self).pointee else {
			return nil
		}
		return "\(Int(versionNumber))"
	}
	
	static var configuration = CommandConfiguration(
		commandName: "locmapper",
		abstract: "A utility for working w/ LocMapper files.",
		version: version ?? "",
		subcommands: [
			/* The two subcommands below should be deleted. */
			Help.self, Version.self
		]
	)
	
}

LocMapperCLI.main()

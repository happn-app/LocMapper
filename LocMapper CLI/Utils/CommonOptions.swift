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
#if canImport(os)
import os.log
#endif

import ArgumentParser
import Logging
import CLTLogger

import LocMapper



/* This option is available in all the subcommands (except the obsolete help and version ones).
 * It is apparently not possible to define an option in the main command and have it inherited by subcommands (AFAICT),
 *  _but_ having an option group defined in theh main command **and** the subcommands seems to do the trick!
 *
 * After thinking a bit about it, it kind of makes sense, though I’m not fully convinced
 *  (I don’t really like it this way but do not really see a better way either…).
 *
 * After digging a bit more, I found this https://github.com/apple/swift-argument-parser/issues/144#issuecomment-628684159 which seems to confirm my suspicions.
 *
 * The git behavior is (AFAICT) not possible to define w/ ArgumentParser though:
 *  “git commit” has a global “-C” option to change the repository path to use for its operations, and a local “-C” option for something else…
 *
 * Tested, it is impossible AFAICT (as of now at least):
 *  I tried setting up an option group and defining a subcommand that uses the option group _and_ another option with the same name.
 * The other option is ignored, sadly.
 *
 * Submitted an issue (though we don’t need it here): https://github.com/apple/swift-argument-parser/issues/169 */
struct CSVOptions : ParsableArguments {
	
	@Option(help: "The CSV separator (lcm files are CSVs).")
	var csvSeparator = ","
	
}


struct LoggingOptions : ParsableArguments {
	
	@Option(help: "Force using OSLog instead of logging with CLTLogger.")
	var forceOSLog: Bool = false
	
	@Option(help: "Log from log level debug instead of info. Only makes sense when logging with CLTLogger")
	var verbose: Bool = false
	
	func bootstrapLogger() {
		LoggingSystem.bootstrap({ [verbose] id, metadataProvider in
			/* Note: CLTLoggers do not have IDs, so we do not use the id parameter of the handler. */
			var ret = CLTLogger(metadataProvider: metadataProvider)
			ret.logLevel = (verbose ? .debug : .info)
			return ret
		}, metadataProvider: nil)
#if canImport(os)
		if forceOSLog {
			LocMapperConfig.oslog = .init(subsystem: "com.happn.LocMapper", category: "")
			LocMapperConfig.logger = nil
		} else {
			LocMapperConfig.oslog = nil
			LocMapperConfig.logger = Logger(label: "com.happn.LocMapper")
		}
#else
		LocMapperConfig.logger = Logger(label: "com.happn.LocMapper")
#endif
	}
	
}

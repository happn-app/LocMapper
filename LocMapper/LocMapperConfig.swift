/*
 * LocMapperConfig.swift
 * LocMapper
 *
 * Created by François Lamboley on 1/22/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

import Logging



public struct LocMapperConfig {

	#if canImport(os)
	public static var oslog: OSLog? = .default
	#endif
	public static var logger: Logging.Logger? = {
		#if canImport(os)
		return nil
		#else
		return Logger(label: "com.happn.LocMapper")
		#endif
	}()
	
	/** This struct is simply a container for static configuration properties. */
	private init() {}
	
}

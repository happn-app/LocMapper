/*
 * LocMapperConfig.swift
 * LocMapper
 *
 * Created by François Lamboley on 2018-01-22.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
import os.log
#endif

import GlobalConfModule
import Logging



public extension ConfKeys {
	/* LocMapper conf namespace declaration. */
	struct LocMapper {}
	var locMapper: LocMapper {LocMapper()}
}


extension ConfKeys.LocMapper {

#if canImport(OSLog)
	#declareConfKey("oslog",  OSLog?         .self, defaultValue: OSLog(subsystem: "me.frizlab.LocMapper", category: "Main"))
	#declareConfKey("logger", Logging.Logger?.self, defaultValue: nil)
#else
	#declareConfKey("logger", Logging.Logger?.self, defaultValue: .init(label: "me.frizlab.LocMapper"))
#endif
	
}


extension Conf {
	
#if canImport(os)
	#declareConfAccessor(\.locMapper.oslog,  OSLog?         .self)
#endif
	#declareConfAccessor(\.locMapper.logger, Logging.Logger?.self)
	
}

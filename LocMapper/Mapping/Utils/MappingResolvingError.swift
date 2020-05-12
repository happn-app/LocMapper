/*
 * MappingResolvingError.swift
 * LocMapper
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



enum MappingResolvingError : Error {
	
	case invalidMapping
	
	/** Mapping to a non-existing key. */
	case keyNotFound
	/** Mapping to an existing key which has no value for the given language. */
	case noValueForLanguage
	/** When mapping points to a mapped key we throw this error. We do this to
	avoid infinite recursions. */
	case mappedToMappedKey
	
	/** Self-explanatory; used tokens for XibLoc that are not valid. */
	case invalidXibLocTokens
	
	/** One of the mapping component/transformer needs to know the language to
	apply its transformation (e.g. plural pick transformer), but the given
	language is unknown. */
	case unknownLanguage
	
}

/*
 * MappingResolvingError.swift
 * Localizer
 *
 * Created by François Lamboley on 2/3/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



enum MappingResolvingError : Error {
	case invalidMapping
	case mappedToMappedKey /* When mapping points to a mapped key. This is invalid to avoid infinite recursions... */
	
	case keyNotFound
	case languageNotFound
}

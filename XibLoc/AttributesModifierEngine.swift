/*
 * AttributesModifierEngine.swift
 * XibLoc
 *
 * Created by François Lamboley on 04/11/2017.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



protocol AttributesModifierEngine {
	
	associatedtype SourceType
	associatedtype ReturnType
	
	/** The number of characters returned by the method **must** be equal to the
	number of character in the input method. */
	func apply(on value: SourceType) -> ReturnType
	
}

struct AnyAttributesModifierEngine<SourceType, ReturnType> : AttributesModifierEngine {
	
	let apply: (SourceType) -> ReturnType
	
	init<EngineType : AttributesModifierEngine>(engine: EngineType) where EngineType.SourceType == SourceType, EngineType.ReturnType == ReturnType {
		apply = engine.apply
	}
	
	init(handlerEngine: @escaping (SourceType) -> ReturnType) {
		apply = handlerEngine
	}
	
	func apply(on value: SourceType) -> ReturnType {
		return apply(value)
	}
	
}

extension AnyAttributesModifierEngine where SourceType == ReturnType {
	
	static func identity() -> AnyAttributesModifierEngine<SourceType, ReturnType> {
		return AnyAttributesModifierEngine<SourceType, ReturnType>(handlerEngine: { $0 })
	}
	
}

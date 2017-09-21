/*
 * SimpleReplacementEngine.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



protocol SimpleReplacementEngine {
	
	associatedtype SourceType
	associatedtype ReturnType

	func apply(on value: SourceType) -> ReturnType
	
}

struct AnySimpleReplacementEngine<SourceType, ReturnType> : SimpleReplacementEngine {
	
	let apply: (SourceType) -> ReturnType
	
	init<EngineType : SimpleReplacementEngine>(engine: EngineType) where EngineType.SourceType == SourceType, EngineType.ReturnType == ReturnType {
		apply = engine.apply
	}
	
	init(handlerEngine: @escaping (SourceType) -> ReturnType) {
		apply = handlerEngine
	}
	
	init(constant: ReturnType) {
		apply = { _ in constant }
	}
	
	func apply(on value: SourceType) -> ReturnType {
		return apply(value)
	}
	
}

extension AnySimpleReplacementEngine where SourceType == ReturnType {
	
	static func identity() -> AnySimpleReplacementEngine<SourceType, ReturnType> {
		return AnySimpleReplacementEngine<SourceType, ReturnType>(handlerEngine: { $0 })
	}
	
}

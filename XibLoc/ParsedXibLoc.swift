/*
 * ParsedXibLoc.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct ParsedXibLoc<SourceType, SourceTypeHelper : XibLoc.SourceTypeHelper> where SourceTypeHelper.SourceType == SourceType {
	
	/* Would prefer embedded in Replacement, but makes Swift crash :( (Xcode 9.1/9B55) */
	enum ReplacementValue {
		
		case simpleSourceTypeReplacement(OneWordTokens)
		case orderedReplacement(MultipleWordsTokens, value: Int)
		case pluralGroup(MultipleWordsTokens, value: Int)
		
		case attributesModification(OneWordTokens)
		case simpleReturnTypeReplacement(OneWordTokens)
		
		case dictionaryReplacement(id: String, value: String?)
		
		var isAttributesModifiation: Bool {
			switch self {
			case .attributesModification: return true
			default:                      return false
			}
		}
		
	}
	
	struct Replacement {
		
		var range: Range<String.Index>
		let value: ReplacementValue
		
		var removedLeftTokenDistance: String.IndexDistance
		var removedRightTokenDistance: String.IndexDistance
		var containerRange: Range<String.Index> /* Always contains “range”. Equals “range” for OneWordTokens. */
		
		var children: [Replacement]
		
		func print(from string: String, prefix: String = "") {
			Swift.print("\(prefix)REPLACEMENT START")
			Swift.print("\(prefix)container: \(string[containerRange])")
			Swift.print("\(prefix)range: \(string[range])")
			Swift.print("\(prefix)removed left  token distance: \(removedLeftTokenDistance)")
			Swift.print("\(prefix)removed right token distance: \(removedRightTokenDistance)")
			Swift.print("\(prefix)children (\(children.count))")
			for c in children {c.print(from: string, prefix: prefix + "   ")}
			Swift.print("\(prefix)REPLACEMENT END")
		}
		
	}
	
	/* We _may_ want to migrate these three variables to a private let... Some
	 * client _might_ need those however, so let's keep them accessible (TBD). */
	let replacements: [Replacement]
	let untokenizedSource: SourceType
	let untokenizedStringSource: String
	
	let sourceTypeHelperType: SourceTypeHelper.Type
	
	init<DestinationType>(source: SourceType, parserHelper: SourceTypeHelper.Type, forXibLocResolvingInfo xibLocResolvingInfo: XibLocResolvingInfo<SourceType, DestinationType>) {
		self.init(source: source, parserHelper: parserHelper, escapeToken: xibLocResolvingInfo.escapeToken, simpleSourceTypeReplacements: Array(xibLocResolvingInfo.simpleSourceTypeReplacements.keys), orderedReplacements: Array(xibLocResolvingInfo.orderedReplacements.keys), pluralGroups: Array(xibLocResolvingInfo.pluralGroups.keys), attributesModifications: Array(xibLocResolvingInfo.attributesModifications.keys), simpleReturnTypeReplacements: Array(xibLocResolvingInfo.simpleReturnTypeReplacements.keys), hasDictionaryReplacements: xibLocResolvingInfo.dictionaryReplacements != nil, defaultPluralityDefinition: xibLocResolvingInfo.defaultPluralityDefinition)
	}
	
	init(source: SourceType, parserHelper: SourceTypeHelper.Type, escapeToken: String?, simpleSourceTypeReplacements: [OneWordTokens], orderedReplacements: [MultipleWordsTokens], pluralGroups: [MultipleWordsTokens], attributesModifications: [OneWordTokens], simpleReturnTypeReplacements: [OneWordTokens], hasDictionaryReplacements: Bool, defaultPluralityDefinition: PluralityDefinition) {
		var source = source
		var stringSource = parserHelper.stringRepresentation(of: source)
		var pluralityDefinitions = ParsedXibLoc<SourceType, SourceTypeHelper>.preprocessForPluralityDefinitionOverrides(source: &source, stringSource: &stringSource, parserHelper: parserHelper, defaultPluralityDefinition: defaultPluralityDefinition)
		while pluralityDefinitions.count <= pluralGroups.count {pluralityDefinitions.append(defaultPluralityDefinition)} /* TODO: Check if really <= instead of < (original ObjC code was <= but it feels weird) */
		
		self.init(source: source, stringSource: stringSource, parserHelper: parserHelper, escapeToken: escapeToken, simpleSourceTypeReplacements: simpleSourceTypeReplacements, orderedReplacements: orderedReplacements, pluralGroups: pluralGroups, attributesModifications: attributesModifications, simpleReturnTypeReplacements: simpleReturnTypeReplacements, hasDictionaryReplacements: hasDictionaryReplacements, pluralityDefinitions: pluralityDefinitions)
	}
	
	private init(source: SourceType, stringSource: String, parserHelper: SourceTypeHelper.Type, escapeToken: String?, simpleSourceTypeReplacements: [OneWordTokens], orderedReplacements: [MultipleWordsTokens], pluralGroups: [MultipleWordsTokens], attributesModifications: [OneWordTokens], simpleReturnTypeReplacements: [OneWordTokens], hasDictionaryReplacements: Bool, pluralityDefinitions: [PluralityDefinition]) {
		assert(pluralityDefinitions.count > pluralGroups.count)
		assert(!hasDictionaryReplacements, "Not implemented: Creating a ParsedXibLoc with dictionary replacements")
		/* First, let's make sure we are not overlapping tokens for our parsing:
		 *    - If lsep == rsep, reduce to only sep;
		 *    - No char used in any separator (left, right, internal, escape token) must be use in another separator;
		 *    - But the same char can be used multiple time in one separator;
		 *    - If dictionary replacements are active, the following tokens are reserved (and count in the above rules): "@[", "|", ":", "¦", "]"
		 * We'll also make sure none of the tokens are empty. */
		#if !NS_BLOCK_ASSERTIONS // TODO: Find correct pre-processing instruction
			var chars = !hasDictionaryReplacements ? Set<Character>() : Set<Character>(arrayLiteral: "@", "[", "|", ":", "¦", "]")
			
			let processToken = { (token: String) in
				assert(!token.isEmpty)
				let tokenChars = Set(token)
				assert(chars.intersection(tokenChars).isEmpty)
				chars.formUnion(tokenChars)
			}
			
			if let e = escapeToken {processToken(e)}
			
			for w in (simpleSourceTypeReplacements + attributesModifications + simpleReturnTypeReplacements) {
				processToken(w.leftToken)
				if w.leftToken != w.rightToken {processToken(w.rightToken)}
			}
			
			for w in (orderedReplacements + pluralGroups) {
				processToken(w.leftToken)
				processToken(w.interiorToken)
				if w.leftToken != w.rightToken {processToken(w.rightToken)}
			}
		#endif
		
		/* Let's build the replacements. Overlaps are allowed with the following rules:
		 *    - The attributes modifications can overlap between themselves at will;
		 *    - Replacements can be embedded in other replacements (internal ranges for multiple words tokens, default or other values ranges for dictionaries);
		 *    - Replacements cannot overlap attributes modifications or replacements if one is not fully embedded in the other.
		 * Note: Anything can be embedded in a simple replacement, but everything embedded in it will be dropped... (the content is replaced, by definition!) */

		func getOneWordRanges(tokens: [OneWordTokens], replacementTypeBuilder: (_ token: OneWordTokens) -> ReplacementValue, in output: inout [Replacement]) {
			for sep in tokens {
				var pos = stringSource.startIndex
				while let r = ParsedXibLoc<SourceType, SourceTypeHelper>.rangeFrom(leftSeparator: sep.leftToken, rightSeparator: sep.rightToken, escapeToken: escapeToken, baseString: stringSource, currentPositionInString: &pos) {
					let replacementType = replacementTypeBuilder(sep)
					let doUntokenization = replacementType.isAttributesModifiation /* See discussion below about token removal */
					let contentRange = ParsedXibLoc<SourceType, SourceTypeHelper>.contentRange(from: r, in: stringSource, leftSep: sep.leftToken, rightSep: sep.rightToken)
					let replacement = Replacement(range: contentRange, value: replacementType, removedLeftTokenDistance: doUntokenization ? sep.leftToken.count : 0, removedRightTokenDistance: doUntokenization ? sep.rightToken.count : 0, containerRange: r, children: [])
					ParsedXibLoc<SourceType, SourceTypeHelper>.insert(replacement: replacement, in: &output)
				}
			}
		}
		
		func getMultipleWordsRanges(tokens: [MultipleWordsTokens], replacementTypeBuilder: (_ token: MultipleWordsTokens, _ idx: Int) -> ReplacementValue, in output: inout [Replacement]) {
			for sep in tokens {
				var pos = stringSource.startIndex
				while let r = ParsedXibLoc<SourceType, SourceTypeHelper>.rangeFrom(leftSeparator: sep.leftToken, rightSeparator: sep.rightToken, escapeToken: escapeToken, baseString: stringSource, currentPositionInString: &pos) {
					/* Let's get the internal ranges. */
					let contentRange = ParsedXibLoc<SourceType, SourceTypeHelper>.contentRange(from: r, in: stringSource, leftSep: sep.leftToken, rightSep: sep.rightToken)
					var startIndex = contentRange.lowerBound
					let endIndex = contentRange.upperBound
					
					var idx = 0
					while let sepRange = ParsedXibLoc<SourceType, SourceTypeHelper>.range(of: sep.interiorToken, escapeToken: escapeToken, baseString: stringSource, in: startIndex..<endIndex) {
						let internalRange = startIndex..<sepRange.lowerBound
						/* We set both removed left and right token distances to 0 (see discussion below about token removal) */
						let replacement = Replacement(range: internalRange, value: replacementTypeBuilder(sep, idx), removedLeftTokenDistance: 0/*idx == 0 ? sep.leftToken.count : 0*/, removedRightTokenDistance: 0/*sep.interiorToken.count*/, containerRange: r, children: [])
						ParsedXibLoc<SourceType, SourceTypeHelper>.insert(replacement: replacement, in: &output)
						
						idx += 1
						startIndex = sepRange.upperBound
					}
					let internalRange = startIndex..<endIndex
					/* We set both removed left and right token distances to 0 (see discussion below about token removal) */
					let replacement = Replacement(range: internalRange, value: replacementTypeBuilder(sep, idx), removedLeftTokenDistance: 0/*idx == 0 ? sep.leftToken.count : 0*/, removedRightTokenDistance: 0/*sep.rightToken.count*/, containerRange: r, children: [])
					ParsedXibLoc<SourceType, SourceTypeHelper>.insert(replacement: replacement, in: &output)
				}
			}
		}
		
		var replacementsBuilding = [Replacement]()
		
		getOneWordRanges(tokens: simpleSourceTypeReplacements, replacementTypeBuilder: { .simpleSourceTypeReplacement($0) }, in: &replacementsBuilding)
		getOneWordRanges(tokens: simpleReturnTypeReplacements, replacementTypeBuilder: { .simpleReturnTypeReplacement($0) }, in: &replacementsBuilding)
		getOneWordRanges(tokens: attributesModifications, replacementTypeBuilder: { .attributesModification($0) }, in: &replacementsBuilding)
		getMultipleWordsRanges(tokens: pluralGroups, replacementTypeBuilder: { .pluralGroup($0, value: $1) }, in: &replacementsBuilding)
		getMultipleWordsRanges(tokens: orderedReplacements, replacementTypeBuilder: { .orderedReplacement($0, value: $1) }, in: &replacementsBuilding)
		/* TODO: Parse the dictionary replacements. */
		
		/* Let's remove the tokens we want gone from the source string. The escape
		 * token is always removed. We only remove the left and right separator
		 * tokens from the attributes modification; all other tokens are left. The
		 * idea behind the removal of the tokens is to avoid adjusting all the
		 * ranges in the replacements when applying the changes in the source. The
		 * attributes modification change is guaranteed to not modify the range of
		 * anything by contract, so we can pre-compute the ranges before applying
		 * the modification. All other changes will modify the ranges 99% of the
		 * cases, so there are no pre-computations to be done this way. */
		
		var untokenizedSourceBuilding = source
		var untokenizedStringSourceBuilding = stringSource
		ParsedXibLoc<SourceType, SourceTypeHelper>.remove(escapeToken: escapeToken, in: &replacementsBuilding, source: &untokenizedSourceBuilding, stringSource: &untokenizedStringSourceBuilding, parserHelper: parserHelper)
		ParsedXibLoc<SourceType, SourceTypeHelper>.removeTokens(from: &replacementsBuilding, baseIndexPath: IndexPath(), source: &untokenizedSourceBuilding, stringSource: &untokenizedStringSourceBuilding, parserHelper: parserHelper)
//		print("***** RESULTS TIME *****")
//		print("untokenized: \(untokenizedStringSourceBuilding)")
//		for r in replacementsBuilding {r.print(from: untokenizedStringSourceBuilding)}
		
		/* Let's finish the init */
		
		sourceTypeHelperType = parserHelper
		
		replacements = replacementsBuilding
		untokenizedSource = untokenizedSourceBuilding
		untokenizedStringSource = untokenizedStringSourceBuilding
	}
	
	func resolve<ReturnTypeHelper : XibLoc.ReturnTypeHelper>(xibLocResolvingInfo: XibLocResolvingInfo<SourceType, ReturnTypeHelper.ReturnType>, returnTypeHelperType: ReturnTypeHelper.Type) -> ReturnTypeHelper.ReturnType {
		var refString = untokenizedStringSource
		var adjustedReplacements = replacements
		
		/* Applying simple source type replacements */
		var sourceWithSimpleReplacements = untokenizedSource
		ParsedXibLoc<SourceType, SourceTypeHelper>.enumerateReplacementsDepthFirst(adjustedReplacements, handler: { replacement in
			guard case .simpleSourceTypeReplacement(let token) = replacement.value else {return adjustedReplacements}
			guard let newValue = xibLocResolvingInfo.simpleSourceTypeReplacements[token] else {
				NSLog("%@", "Got token \(token) in replacement tree for simple source type replacement, but no value given in xibLocResolvingInfo") /* HCLogES */
				return adjustedReplacements
			}
			
			let stringReplacement = sourceTypeHelperType.replace(strRange: (replacement.containerRange, refString), with: newValue, in: &sourceWithSimpleReplacements)
			let originalRefString = refString
			refString.replaceSubrange(replacement.containerRange, with: stringReplacement)
			ParsedXibLoc<SourceType, SourceTypeHelper>.replace(range: replacement.containerRange, with: replacement.containerRange.lowerBound..<refString.index(replacement.containerRange.lowerBound, offsetBy: stringReplacement.count), in: &adjustedReplacements, originalString: originalRefString)
			return adjustedReplacements
		})
		/* TODO */
		
		/* Converting the source type string to the destination type */
		var result = xibLocResolvingInfo.identityReplacement(sourceWithSimpleReplacements)
		
		/* Applying other replacements */
		ParsedXibLoc<SourceType, SourceTypeHelper>.enumerateReplacementsDepthFirst(adjustedReplacements, handler: { replacement in
			switch replacement.value {
			case .simpleSourceTypeReplacement: (/* nop (done above) */)
			case .attributesModification(let token):
				guard let modifier = xibLocResolvingInfo.attributesModifications[token] else {
					NSLog("%@", "Got token \(token) in replacement tree for attributes modification, but no value given in xibLocResolvingInfo") /* HCLogES */
					return adjustedReplacements
				}
				let warning = """
				todo: currently we slice the result to extract the part where we'll apply the transformation,
				then apply the transformation, then replace with the transformed value. This is expensive.
				The attributes modifier should be able to handle being given a range and apply the transform to this range only
				"""
				modifier(&result, replacement.range, refString)
				/* We cannot do the assert below because the returnTypeHelperType
				 * does not have a method to convert from the return type to a
				 * string. However, if possible, the assert would be correct. */
//				assert(returnTypeHelperType.stringRepresentation(of: result) == refString)
				/* No ranges to adjust in replacements */
				
			case .simpleReturnTypeReplacement(let token):
				guard let newValue = xibLocResolvingInfo.simpleReturnTypeReplacements[token] else {
					NSLog("%@", "Got token \(token) in replacement tree for simple return type replacement, but no value given in xibLocResolvingInfo") /* HCLogES */
					return adjustedReplacements
				}
				
				let stringReplacement = returnTypeHelperType.replace(strRange: (replacement.containerRange, refString), with: newValue, in: &result)
				refString.replaceSubrange(replacement.containerRange, with: stringReplacement)
				
			case .orderedReplacement(let token, value: let value):
				guard let wantedValue = xibLocResolvingInfo.orderedReplacements[token] else {
					NSLog("%@", "Got token \(token) in replacement tree for ordered replacement, but no value given in xibLocResolvingInfo") /* HCLogES */
					return adjustedReplacements
				}
				let warning = "todo: we must handle the case where the given value is too big! in this case we must use the last value available"
				guard value == wantedValue else {return adjustedReplacements}
				
				let content = returnTypeHelperType.slice(strRange: (replacement.range, refString), from: result)
				let stringContent = returnTypeHelperType.replace(strRange: (replacement.containerRange, refString), with: content, in: &result)
				refString.replaceSubrange(replacement.containerRange, with: stringContent)
				
			case .pluralGroup(let token, value: let value):
				let warning = "todo"
				
			case .dictionaryReplacement(id: let id, value: let value):
				let warning = "todo"
			}
			return adjustedReplacements
		})
		/* TODO */
		
		return result
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
	static private func enumerateReplacementsDepthFirst(_ replacements: [Replacement], handler: (_ replacement: Replacement) -> [Replacement], baseIndexPath: IndexPath = IndexPath()) {
		let replacementsCount: Int
		var replacements = replacements
		if baseIndexPath.isEmpty {replacementsCount = replacements.count}
		else                     {replacementsCount = ParsedXibLoc<SourceType, SourceTypeHelper>.replacement(at: baseIndexPath, in: replacements).children.count}
		for i in 0..<replacementsCount {
			let currentIndexPath = baseIndexPath.appending(i)
			let replacement = ParsedXibLoc<SourceType, SourceTypeHelper>.replacement(at: currentIndexPath, in: replacements)
			
			enumerateReplacementsDepthFirst(replacements, handler: handler, baseIndexPath: currentIndexPath)
			replacements = handler(replacement)
		}
	}
	
	/* NOT a generic method. Assumes a bunch of stuff on the given arguments. */
	private static func adjustedRange(from range: Range<String.Index>, byReplacing removedRange: Range<String.Index>, with addedRange: Range<String.Index>?, in originalString: String) -> Range<String.Index> {
		let adjustLowerBound = (originalString.distance(from: range.lowerBound, to: removedRange.upperBound) <= 0)
		let adjustUpperBound = (originalString.distance(from: range.upperBound, to: removedRange.upperBound) <= 0)
		let distance = originalString.distance(from: addedRange?.upperBound ?? removedRange.lowerBound, to: removedRange.upperBound)
		
		return Range<String.Index>(uncheckedBounds:
			(lower: !adjustLowerBound ? range.lowerBound : originalString.index(range.lowerBound, offsetBy: -distance),
			 upper: !adjustUpperBound ? range.upperBound : originalString.index(range.upperBound, offsetBy: -distance))
		)
	}
	
	private static func remove(range: Range<String.Index>, in replacements: inout [Replacement], originalString: String) {
		replace(range: range, with: nil, in: &replacements, originalString: originalString)
	}
	
	private static func replace(range: Range<String.Index>, with newRange: Range<String.Index>?, in replacements: inout [Replacement], originalString: String) {
		for (idx, var replacement) in replacements.enumerated() {
			/* We make sure range is contained by the container range of the
			 * replacement, or that both do not overlap. */
			assert(!replacement.containerRange.overlaps(range) || replacement.containerRange.clamped(to: range) == range)
			
			replacement.range = adjustedRange(from: replacement.range, byReplacing: range, with: newRange, in: originalString)
			replacement.containerRange = adjustedRange(from: replacement.containerRange, byReplacing: range, with: newRange, in: originalString)
			
			remove(range: range, in: &replacement.children, originalString: originalString)
			replacements[idx] = replacement
		}
	}
	
	private static func remove(escapeToken: String?, in replacements: inout [Replacement], source: inout SourceType, stringSource: inout String, parserHelper: SourceTypeHelper.Type) {
		guard let escapeToken = escapeToken else {return}
		
		var pos = stringSource.startIndex
		while let r = stringSource.range(of: escapeToken, options: [.literal], range: pos..<stringSource.endIndex) {
			remove(range: r, in: &replacements, originalString: stringSource)
			parserHelper.remove(strRange: (r, stringSource), from: &source)
			stringSource.removeSubrange(r)
			pos = r.lowerBound
			
			if pos >= stringSource.endIndex {break}
			if stringSource[r] == escapeToken {pos = stringSource.index(pos, offsetBy: escapeToken.count)}
		}
	}
	
	private static func replacement(at indexPath: IndexPath, in replacements: [Replacement]) -> Replacement {
		var result: Replacement!
		var replacements = replacements
		for idx in indexPath {
			result = replacements[idx]
			replacements = result.children
		}
		return result
	}
	
	private static func removeTokens(inReplacementAtIndexPath indexPath: IndexPath, from replacements: inout [Replacement], source: inout SourceType, stringSource: inout String, parserHelper: SourceTypeHelper.Type) {
		let replacement1 = replacement(at: indexPath, in: replacements)
		let leftTokenRange = stringSource.index(replacement1.range.lowerBound, offsetBy: -replacement1.removedLeftTokenDistance)..<replacement1.range.lowerBound
		remove(range: leftTokenRange, in: &replacements, originalString: stringSource)
		parserHelper.remove(strRange: (leftTokenRange, stringSource), from: &source)
		stringSource.removeSubrange(leftTokenRange)
		
		let replacement2 = replacement(at: indexPath, in: replacements)
		let rightTokenRange = replacement2.range.upperBound..<stringSource.index(replacement2.range.upperBound, offsetBy: replacement2.removedRightTokenDistance)
		remove(range: rightTokenRange, in: &replacements, originalString: stringSource)
		parserHelper.remove(strRange: (rightTokenRange, stringSource), from: &source)
		stringSource.removeSubrange(rightTokenRange)
		
		removeTokens(from: &replacements, baseIndexPath: indexPath, source: &source, stringSource: &stringSource, parserHelper: parserHelper)
	}
	
	private static func removeTokens(from replacements: inout [Replacement], baseIndexPath: IndexPath, source: inout SourceType, stringSource: inout String, parserHelper: SourceTypeHelper.Type) {
		let replacementsCount: Int
		if baseIndexPath.isEmpty {replacementsCount = replacements.count}
		else                     {replacementsCount = replacement(at: baseIndexPath, in: replacements).children.count}
		for i in 0..<replacementsCount {
			removeTokens(inReplacementAtIndexPath: baseIndexPath.appending(i), from: &replacements, source: &source, stringSource: &stringSource, parserHelper: parserHelper)
		}
	}
	
	/** Inserts the given replacement in the given array of replacements, if
	possible. If a valid insertion cannot be done, returns `false` (otherwise,
	returns `true`).
	Assumes the given replacement and current replacements are valid. */
	@discardableResult
	private static func insert(replacement: Replacement, in currentReplacements: inout [Replacement]) -> Bool {
		for (idx, checkedReplacement) in currentReplacements.enumerated() {
			/* If both checked and inserted replacements have the same container
			 * range, we are inserting a new replacement value for the checked
			 * replacement (eg. inserting the “b” when “a” has been inserted in the
			 * following replacement: “<a:b>”). Let's just check the two ranges do
			 * not overlap (asserted, this is an internal logic error if ranges
			 * overlap). */
			guard replacement.containerRange != checkedReplacement.containerRange else {
				assert(!replacement.range.overlaps(checkedReplacement.range))
				continue
			}
			
			/* If there are no overlaps of the container ranges, or if we have two
			 * attributes modifications, we have an easy case: nothing to do (all
			 * ranges are valid). */
			guard !replacement.value.isAttributesModifiation || !checkedReplacement.value.isAttributesModifiation else {continue}
			guard replacement.containerRange.overlaps(checkedReplacement.containerRange) else {continue}
			
			if checkedReplacement.range.clamped(to: replacement.containerRange) == replacement.containerRange {
				/* replacement’s container range is included in checkedReplacement’s range: we must add replacement as a child of checkedReplacement */
				var checkedReplacement = checkedReplacement
				guard insert(replacement: replacement, in: &checkedReplacement.children) else {return false}
				currentReplacements[idx] = checkedReplacement
				return true
			} else if replacement.range.clamped(to: checkedReplacement.containerRange) == checkedReplacement.containerRange {
				/* checkedReplacement’s container range is included in replacement’s range: we must add checkedReplacement as a child of replacement */
				var replacement = replacement
				guard insert(replacement: checkedReplacement, in: &replacement.children) else {return false}
				currentReplacements[idx] = replacement
				return true
			} else {
				return false
			}
		}
		
		currentReplacements.append(replacement)
		return true
	}
	
	private static func preprocessForPluralityDefinitionOverrides(source: inout SourceType, stringSource: inout String, parserHelper: SourceTypeHelper.Type, defaultPluralityDefinition: PluralityDefinition) -> [PluralityDefinition] {
		guard stringSource.hasPrefix("||") else {return []}
		
		let startIdx = stringSource.startIndex
		
		/* We might have plurality overrides. Let's check. */
		guard !stringSource.hasPrefix("|||") else {
			/* We don't. But we must remove one leading "|". */
			parserHelper.remove(strRange: (..<stringSource.index(after: startIdx), stringSource), from: &source)
			stringSource.removeFirst()
			return []
		}
		
		let pluralityStringStartIdx = stringSource.index(startIdx, offsetBy: 2)
		
		/* We do have plurality override(s)! Is it valid? */
		guard let pluralityEndIdx = stringSource.range(of: "||", options: [.literal], range: pluralityStringStartIdx..<stringSource.endIndex)?.lowerBound else {
			/* Nope. It is not. */
			NSLog("%@", "Got invalid plurality override in string \(source)") /* We used to use HCLogES */
			return []
		}
		
		/* A valid plurality overrides part was found. Let's parse them! */
		let pluralityOverrideStr = stringSource[pluralityStringStartIdx..<pluralityEndIdx]
		let pluralityDefinitions = pluralityOverrideStr.components(separatedBy: "|").map{ $0 == "_" ? defaultPluralityDefinition : PluralityDefinition(string: $0) }
		
		/* Let's remove the plurality definition from the string. */
		let nonPluralityStringStartIdx = stringSource.index(pluralityEndIdx, offsetBy: 2)
		parserHelper.remove(strRange: (..<nonPluralityStringStartIdx, stringSource), from: &source)
		stringSource.removeSubrange(startIdx..<nonPluralityStringStartIdx)

		return pluralityDefinitions
	}
	
	private static func contentRange(from range: Range<String.Index>, in source: String, leftSep: String, rightSep: String) -> Range<String.Index> {
		assert(source.distance(from: range.lowerBound, to: range.upperBound) >= leftSep.count + rightSep.count)
		return Range<String.Index>(uncheckedBounds: (lower: source.index(range.lowerBound, offsetBy: leftSep.count), upper: source.index(range.upperBound, offsetBy: -rightSep.count)))
	}
	
	private static func rangeFrom(leftSeparator: String, rightSeparator: String, escapeToken: String?, baseString: String, currentPositionInString: inout String.Index) -> Range<String.Index>? {
		guard let leftSeparatorRange = range(of: leftSeparator, escapeToken: escapeToken, baseString: baseString, in: currentPositionInString..<baseString.endIndex) else {
			currentPositionInString = baseString.endIndex
			return nil
		}
		currentPositionInString = leftSeparatorRange.upperBound
		
		guard let rightSeparatorRange = range(of: rightSeparator, escapeToken: escapeToken, baseString: baseString, in: currentPositionInString..<baseString.endIndex) else {
			/* Invalid string: The left token was found, but the right is not. */
			NSLog("%@", "Invalid baseString \"\(baseString)\": left token “\(leftSeparator)” was found, but right one “\(rightSeparator)” was not. Ignoring.") /* HCLogES */
			currentPositionInString = baseString.endIndex
			return nil
		}
		currentPositionInString = rightSeparatorRange.upperBound
		
		return leftSeparatorRange.lowerBound..<rightSeparatorRange.upperBound
	}
	
	private static func range(of separator: String, escapeToken: String?, baseString: String, in range: Range<String.Index>) -> Range<String.Index>? {
		var escaped: Bool
		var ret: Range<String.Index>
		
		var startIndex = range.lowerBound
		let endIndex = range.upperBound
		
		repeat {
			guard let rl = baseString.range(of: separator, options: [.literal], range: startIndex..<endIndex) else {
				return nil
			}
			startIndex = rl.upperBound
			escaped = isTokenInRange(rl, fromString: baseString, escapedWithToken: escapeToken)
			
			ret = rl
		} while escaped
		
		return ret
	}
	
	private static func isTokenInRange(_ range: Range<String.Index>, fromString baseString: String, escapedWithToken token: String?) -> Bool {
		guard let escapeToken = token, !escapeToken.isEmpty else {return false}
		
		var wasMatch = true
		var nMatches = 0
		var curPos = range.lowerBound
		while curPos >= escapeToken.endIndex && wasMatch {
			curPos = baseString.index(curPos, offsetBy: -escapeToken.count)
			wasMatch = (baseString[curPos..<baseString.index(curPos, offsetBy: escapeToken.count)] == escapeToken)
			if wasMatch {nMatches += 1}
		}
		return (nMatches % 2) == 1
	}
	
}

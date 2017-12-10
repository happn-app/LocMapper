/*
 * ParsedXibLoc.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/26/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



struct ParsedXibLoc<SourceType, ParserHelper : XibLoc.ParserHelper> where ParserHelper.SourceType == SourceType {
	
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
		
		var leftTokenDistance: String.IndexDistance
		var rightTokenDistance: String.IndexDistance
		var containerRange: Range<String.Index> /* Always contains “range”. Equals “range” for OneWordTokens. */
		
		var children: [Replacement]
		
		func print(from string: String, prefix: String = "") {
			Swift.print("\(prefix)REPLACEMENT START")
			Swift.print("\(prefix)container: \(string[containerRange])")
			Swift.print("\(prefix)range: \(string[range])")
			Swift.print("\(prefix)left  token distance: \(leftTokenDistance)")
			Swift.print("\(prefix)right token distance: \(rightTokenDistance)")
			Swift.print("\(prefix)children (\(children.count))")
			for c in children {c.print(from: string, prefix: prefix + "   ")}
			Swift.print("\(prefix)REPLACEMENT END")
		}
		
	}
	
	/* We _may_ want to migrate these two variables to a private let... Some
	 * client _might_ need those however, so let's keep them accessible (TBD). */
	let untokenizedSource: SourceType
	let replacements: [Replacement]
	
	init<DestinationType>(source: SourceType, parserHelper: ParserHelper, forXibLocResolvingInfo xibLocResolvingInfo: XibLocResolvingInfo<SourceType, DestinationType>) {
		self.init(source: source, parserHelper: parserHelper, escapeToken: xibLocResolvingInfo.escapeToken, simpleSourceTypeReplacements: Array(xibLocResolvingInfo.simpleSourceTypeReplacements.keys), orderedReplacements: Array(xibLocResolvingInfo.orderedReplacements.keys), pluralGroups: Array(xibLocResolvingInfo.pluralGroups.keys), attributesModifications: Array(xibLocResolvingInfo.attributesModifications.keys), simpleReturnTypeReplacements: Array(xibLocResolvingInfo.simpleReturnTypeReplacements.keys), hasDictionaryReplacements: xibLocResolvingInfo.dictionaryReplacements != nil, defaultPluralityDefinition: xibLocResolvingInfo.defaultPluralityDefinition)
	}
	
	init(source: SourceType, parserHelper: ParserHelper, escapeToken: String?, simpleSourceTypeReplacements: [OneWordTokens], orderedReplacements: [MultipleWordsTokens], pluralGroups: [MultipleWordsTokens], attributesModifications: [OneWordTokens], simpleReturnTypeReplacements: [OneWordTokens], hasDictionaryReplacements: Bool, defaultPluralityDefinition: PluralityDefinition) {
		var source = source
		var stringSource = parserHelper.stringRepresentation(of: source)
		var pluralityDefinitions = ParsedXibLoc<SourceType, ParserHelper>.preprocessForPluralityDefinitionOverrides(source: &source, stringSource: &stringSource, parserHelper: parserHelper, defaultPluralityDefinition: defaultPluralityDefinition)
		while pluralityDefinitions.count <= pluralGroups.count {pluralityDefinitions.append(defaultPluralityDefinition)} /* TODO: Check if really <= instead of < (original ObjC code was <= but it feels weird) */
		
		self.init(source: source, stringSource: stringSource, parserHelper: parserHelper, escapeToken: escapeToken, simpleSourceTypeReplacements: simpleSourceTypeReplacements, orderedReplacements: orderedReplacements, pluralGroups: pluralGroups, attributesModifications: attributesModifications, simpleReturnTypeReplacements: simpleReturnTypeReplacements, hasDictionaryReplacements: hasDictionaryReplacements, pluralityDefinitions: pluralityDefinitions)
	}
	
	private init(source: SourceType, stringSource: String, parserHelper: ParserHelper, escapeToken: String?, simpleSourceTypeReplacements: [OneWordTokens], orderedReplacements: [MultipleWordsTokens], pluralGroups: [MultipleWordsTokens], attributesModifications: [OneWordTokens], simpleReturnTypeReplacements: [OneWordTokens], hasDictionaryReplacements: Bool, pluralityDefinitions: [PluralityDefinition]) {
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
				while let r = ParsedXibLoc<SourceType, ParserHelper>.rangeFrom(leftSeparator: sep.leftToken, rightSeparator: sep.rightToken, escapeToken: escapeToken, baseString: stringSource, currentPositionInString: &pos) {
					let replacement = Replacement(range: r, value: replacementTypeBuilder(sep), leftTokenDistance: sep.leftToken.count, rightTokenDistance: sep.rightToken.count, containerRange: r, children: [])
					ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: replacement, in: &output)
				}
			}
		}
		
		func getMultipleWordsRanges(tokens: [MultipleWordsTokens], replacementTypeBuilder: (_ token: MultipleWordsTokens, _ idx: Int) -> ReplacementValue, in output: inout [Replacement]) {
			for sep in tokens {
				var pos = stringSource.startIndex
				while let r = ParsedXibLoc<SourceType, ParserHelper>.rangeFrom(leftSeparator: sep.leftToken, rightSeparator: sep.rightToken, escapeToken: escapeToken, baseString: stringSource, currentPositionInString: &pos) {
					/* Let's get the internal ranges. */
					let contentRange = ParsedXibLoc<SourceType, ParserHelper>.contentRange(from: r, in: stringSource, leftSep: sep.leftToken, rightSep: sep.rightToken)
					var startIndex = contentRange.lowerBound
					let endIndex = contentRange.upperBound
					
					var idx = 0
					while let sepRange = ParsedXibLoc<SourceType, ParserHelper>.range(of: sep.interiorToken, escapeToken: escapeToken, baseString: stringSource, in: startIndex..<endIndex) {
						let internalRange = startIndex..<sepRange.lowerBound
						let replacement = Replacement(range: internalRange, value: replacementTypeBuilder(sep, idx), leftTokenDistance: idx == 0 ? sep.leftToken.count : 0, rightTokenDistance: sep.interiorToken.count, containerRange: r, children: [])
						ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: replacement, in: &output)
						
						idx += 1
						startIndex = sepRange.upperBound
					}
					let internalRange = startIndex..<endIndex
					let replacement = Replacement(range: internalRange, value: replacementTypeBuilder(sep, idx), leftTokenDistance: idx == 0 ? sep.leftToken.count : 0, rightTokenDistance: sep.rightToken.count, containerRange: r, children: [])
					ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: replacement, in: &output)
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
		
		/* Let's remove the tokens from the source string (only the ranges are needed) */
		
		var untokenizedSourceBuilding = source
		var untokenizedStringSourceBuilding = stringSource
		ParsedXibLoc<SourceType, ParserHelper>.removeTokens(from: replacementsBuilding, adjustedReplacements: &replacementsBuilding, in: &untokenizedSourceBuilding, stringSource: &untokenizedStringSourceBuilding, parserHelper: parserHelper)
		
		replacements = replacementsBuilding
		untokenizedSource = untokenizedSourceBuilding
	}
	
	func resolve<DestinationType>(xibLocResolvingInfo: XibLocResolvingInfo<SourceType, DestinationType>) -> DestinationType {
		return "" as! DestinationType
	}
	
	/* ***************
      MARK: - Private
	   *************** */
	
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
	
	/* NOT a generic method. Assumes a bunch of stuff on the given ranges. */
	private static func adjustedRange(from range: Range<String.Index>, byRemoving removedRange: Range<String.Index>, in originalString: String) -> Range<String.Index> {
		return adjustedRange(from: range, byReplacing: removedRange, with: nil, in: originalString)
	}
	
	private static func remove(range: Range<String.Index>, in replacements: inout [Replacement], originalString: String) {
		for (idx, var replacement) in replacements.enumerated() {
			/* We make sure range is contained by the container range of the
			 * replacement, or that both do not overlap. */
			assert(!replacement.containerRange.overlaps(range) || replacement.containerRange.clamped(to: range) == range)
			
			replacement.range = adjustedRange(from: replacement.range, byRemoving: range, in: originalString)
			replacement.containerRange = adjustedRange(from: replacement.containerRange, byRemoving: range, in: originalString)

			remove(range: range, in: &replacement.children, originalString: originalString)
			replacements[idx] = replacement
		}
	}
	
	private static func removeTokens(from replacements: [Replacement], adjustedReplacements: inout [Replacement], in source: inout SourceType, stringSource: inout String, parserHelper: ParserHelper) {
		for replacement in replacements {
			removeTokens(from: replacement.children, adjustedReplacements: &adjustedReplacements, in: &source, stringSource: &stringSource, parserHelper: parserHelper)
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
	
	private static func preprocessForPluralityDefinitionOverrides(source: inout SourceType, stringSource: inout String, parserHelper: ParserHelper, defaultPluralityDefinition: PluralityDefinition) -> [PluralityDefinition] {
		guard stringSource.hasPrefix("||") else {return []}
		
		let startIdx = stringSource.startIndex
		
		/* We might have plurality overrides. Let's check. */
		guard !stringSource.hasPrefix("|||") else {
			/* We don't. But we must remove one leading "|". */
			stringSource.removeFirst()
			parserHelper.remove(range: ..<stringSource.index(after: startIdx), from: &source)
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
		stringSource.removeSubrange(startIdx..<nonPluralityStringStartIdx)
		parserHelper.remove(range: ..<nonPluralityStringStartIdx, from: &source)
		
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

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
		
		var containerRange: Range<String.Index> /* Always contains “range”. Equals “range” for OneWordTokens. */
		
		var children: [Replacement]
		
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
		
		/* Let's get the ranges of all the special (non-constant) parts of the string. */
		
		func getOneWordRanges(tokens: [OneWordTokens], in output: inout [OneWordTokens: [Range<String.Index>]]) {
			for sep in tokens {
				var pos = stringSource.startIndex
				while let r = ParsedXibLoc<SourceType, ParserHelper>.rangeFrom(leftSeparator: sep.leftToken, rightSeparator: sep.rightToken, escapeToken: escapeToken, baseString: stringSource, currentPositionInString: &pos) {
					output[sep, default: []].append(r)
				}
			}
		}
		
		func getMultipleWordsRanges(tokens: [MultipleWordsTokens], in output: inout [MultipleWordsTokens: [(external: Range<String.Index>, internal: [Range<String.Index>])]]) {
			for sep in tokens {
				var pos = stringSource.startIndex
				while let r = ParsedXibLoc<SourceType, ParserHelper>.rangeFrom(leftSeparator: sep.leftToken, rightSeparator: sep.rightToken, escapeToken: escapeToken, baseString: stringSource, currentPositionInString: &pos) {
					/* Let's get the internal ranges. */
					let contentRange = ParsedXibLoc<SourceType, ParserHelper>.contentRange(from: r, in: stringSource, leftSep: sep.leftToken, rightSep: sep.rightToken)
					var startIndex = contentRange.lowerBound
					let endIndex = contentRange.upperBound
					
					var currentInternalRanges = [Range<String.Index>]()
					while let sepRange = ParsedXibLoc<SourceType, ParserHelper>.range(of: sep.interiorToken, escapeToken: escapeToken, baseString: stringSource, in: startIndex..<endIndex) {
						currentInternalRanges.append(startIndex..<sepRange.lowerBound)
						startIndex = sepRange.upperBound
					}
					currentInternalRanges.append(startIndex..<endIndex)
					output[sep, default: []].append((external: r, internal: currentInternalRanges))
				}
			}
		}
		
		var simpleSourceTypeReplacementsRanges = [OneWordTokens: [Range<String.Index>]]()
		var simpleReturnTypeReplacementsRanges = [OneWordTokens: [Range<String.Index>]]()
		var attributesModificationsRanges = [OneWordTokens: [Range<String.Index>]]()
		var pluralGroupsRanges = [MultipleWordsTokens: [(external: Range<String.Index>, internal: [Range<String.Index>])]]()
		var orderedReplacementsRanges = [MultipleWordsTokens: [(external: Range<String.Index>, internal: [Range<String.Index>])]]()
		
		getOneWordRanges(tokens: simpleSourceTypeReplacements, in: &simpleSourceTypeReplacementsRanges)
		getOneWordRanges(tokens: simpleReturnTypeReplacements, in: &simpleReturnTypeReplacementsRanges)
		getOneWordRanges(tokens: attributesModifications, in: &attributesModificationsRanges)
		getMultipleWordsRanges(tokens: pluralGroups, in: &pluralGroupsRanges)
		getMultipleWordsRanges(tokens: orderedReplacements, in: &orderedReplacementsRanges)
		
		/* For the moment, parsing dictionary replacements is not supported. Here
		 * is below however the structure in which said parsing should be done
		 * when implementing support!
		 * The keys to the dictionary are the ids of the replacements. Must be
		 * equal to the subranges formed by the "id" ranges in the tuple. */
		let dictionaryReplacementsRanges = [String: [(external: Range<String.Index>, id: Range<String.Index>, defaultValue: Range<String.Index>?, otherValues: [String: Range<String.Index>])]]()
		
		/* TODO: Parse dictionary replacements ranges. */
		
		/* Let's check for overlaps and solve the embedded replacements:
		 *    - The attributes modifications can overlap between themselves at will;
		 *    - Replacements can be embedded in other replacements (internal ranges for multiple words tokens, default or other values ranges for dictionaries);
		 *    - Replacements cannot overlap attributes modifications or replacements if one is not fully embedded in the other.
		 * Note: Anything can be embedded in a simple replacement, but everything embedded in it will be dropped... (the content is replaced, by definition!) */
		
		var replacementsBuilding = [Replacement]()
		
		for (token, ranges) in simpleSourceTypeReplacementsRanges {
			for range in ranges {
				var replacement = Replacement(range: range, value: .simpleSourceTypeReplacement(token), containerRange: range, children: [])
				ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: &replacement, in: &replacementsBuilding)
			}
		}
		for (token, ranges) in simpleReturnTypeReplacementsRanges {
			for range in ranges {
				var replacement = Replacement(range: range, value: .simpleReturnTypeReplacement(token), containerRange: range, children: [])
				ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: &replacement, in: &replacementsBuilding)
			}
		}
		for (token, ranges) in attributesModificationsRanges {
			for range in ranges {
				var replacement = Replacement(range: range, value: .attributesModification(token), containerRange: range, children: [])
				ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: &replacement, in: &replacementsBuilding)
			}
		}
		for (token, values) in pluralGroupsRanges {
			for (externalRange, internalRanges) in values {
				for (idx, range) in internalRanges.enumerated() {
					var replacement = Replacement(range: range, value: .pluralGroup(token, value: idx), containerRange: externalRange, children: [])
					ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: &replacement, in: &replacementsBuilding)
				}
			}
		}
		for (token, values) in orderedReplacementsRanges {
			for (externalRange, internalRanges) in values {
				for (idx, range) in internalRanges.enumerated() {
					var replacement = Replacement(range: range, value: .orderedReplacement(token, value: idx), containerRange: externalRange, children: [])
					ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: &replacement, in: &replacementsBuilding)
				}
			}
		}
		for (id, values) in dictionaryReplacementsRanges {
			for (externalRange, _, defaultRange, otherRanges) in values {
				if let defaultRange = defaultRange {
					var replacement = Replacement(range: defaultRange, value: .dictionaryReplacement(id: id, value: nil), containerRange: externalRange, children: [])
					ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: &replacement, in: &replacementsBuilding)
				}
				for (key, range) in otherRanges {
					var replacement = Replacement(range: range, value: .dictionaryReplacement(id: id, value: key), containerRange: externalRange, children: [])
					ParsedXibLoc<SourceType, ParserHelper>.insert(replacement: &replacement, in: &replacementsBuilding)
				}
			}
		}
		
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
		for (idx, var replacement) in replacements.enumerated() {
			removeTokens(from: replacement.children, adjustedReplacements: &adjustedReplacements, in: &source, stringSource: &stringSource, parserHelper: parserHelper)
		}
	}
	
	/** Inserts the given replacement in the given array of replacements, if
	possible. If a valid insertion cannot be done, returns `false` (otherwise,
	returns `true`).
	Assumes the given replacement and current replacements are valid. */
	@discardableResult
	private static func insert(replacement: inout Replacement, in currentReplacements: inout [Replacement]) -> Bool {
		for (idx, var checkedReplacement) in currentReplacements.enumerated() {
			/* If there are no overlaps of the container ranges, or if we have two
			 * attributes modifications, we have an easy case: nothing to do (all
			 * ranges are valid). */
			guard !replacement.value.isAttributesModifiation || !checkedReplacement.value.isAttributesModifiation else {continue}
			guard replacement.containerRange.overlaps(checkedReplacement.containerRange) else {continue}
			
			if checkedReplacement.range.clamped(to: replacement.containerRange) == replacement.containerRange {
				/* replacement’s container range is included in checkedReplacement’s range: we must add replacement as a child of checkedReplacement */
				guard insert(replacement: &replacement, in: &checkedReplacement.children) else {return false}
				currentReplacements[idx] = checkedReplacement
				return true
			} else if replacement.range.clamped(to: checkedReplacement.containerRange) == checkedReplacement.containerRange {
				/* checkedReplacement’s container range is included in replacement’s range: we must add checkedReplacement as a child of replacement */
				guard insert(replacement: &checkedReplacement, in: &replacement.children) else {return false}
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

/*
 * RandomAccessCollection+StableSort.swift
 * XibLoc
 *
 * Created by François Lamboley on 8/27/17.
 * Copyright © 2017 happn. All rights reserved.
 */

import Foundation



extension RandomAccessCollection {
	
	/** Return a sorted collection with a stable sort algorithm.
	
	Retrieved from [StackOverflow](https://stackoverflow.com/a/45585365/1152894)
	
	- Parameter areInIncreasingOrder: Return `nil` when two element are equal.
	- Returns: The sorted collection */
	internal func stableSorted(by areInIncreasingOrder: (_ obj1: Iterator.Element, _ obj2: Iterator.Element) -> Bool?) -> [Iterator.Element] {
		let sorted = enumerated().sorted { (one, another) -> Bool in
			if let result = areInIncreasingOrder(one.element, another.element) {return result}
			else                                                               {return one.offset < another.offset}
		}
		return sorted.map{ $0.element }
	}
}

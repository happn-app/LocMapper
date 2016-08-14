/*
 * happnLocCSVDocOptionsViewController.swift
 * Localizer
 *
 * Created by François Lamboley on 7/31/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa



class TextFieldSelectableTableView : NSTableView {
	override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
		return responder is NSTextField || super.validateProposedFirstResponder(responder, for: event)
	}
}


class happnLocCSVDocOptionsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	
	@IBOutlet var tableView: NSTableView!
	
	var handlerNotifyDocumentModification: (() -> Void)?
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return 1 /* String filter */ + 1 /* Sep */ + envs.count + 1 /* Sep */ + 4
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		switch sectionForRow(row) {
		case .stringFilter:
			return tableView.make(withIdentifier: "StringFilter", owner: self)!
			
		case .separator1:
			return tableView.make(withIdentifier: "Sep", owner: self)!
			
		case .envFilter:
			let v = tableView.make(withIdentifier: "CheckFilter", owner: self)!
			(v.subviews.first! as! NSButton).title = envs[row - 2]
			(v.subviews.first! as! NSButton).tag = row
			return v
			
		case .separator2:
			return tableView.make(withIdentifier: "Sep", owner: self)!
			
		case .stateFilter:
			return tableView.make(withIdentifier: "CheckFilter", owner: self)!
		}
	}
	
	func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
		return true
	}
	
	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		switch sectionForRow(row) {
		case .stringFilter:            return 27
		case .envFilter, .stateFilter: return 19
		case .separator1, .separator2: return 31
		}
	}
	
	func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
		return sectionForRow(row).isSeparator
	}
	
	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		return false
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum Section {
		case stringFilter
		case separator1
		case envFilter
		case separator2
		case stateFilter
		
		var isSeparator: Bool {return self == .separator1 || self == .separator2}
	}
	
	/* Currently we keep the list statically. We may want to extract it from the happnCSVLoc later. */
	private let envs = ["Xcode", "Android", "Windows", "RefLoc"]
	
	private func sectionForRow(_ row: Int) -> Section {
		let section1SepIndex = 1
		let section2SepIndex = section1SepIndex + 1 + envs.count
		let section3SepIndex = section2SepIndex + 1 + 4
		switch row {
		case 0:                                         return .stringFilter
		case section1SepIndex:                          return .separator1
		case (section1SepIndex + 1)..<section2SepIndex: return .envFilter
		case section2SepIndex:                          return .separator2
		case (section2SepIndex + 1)..<section3SepIndex: return .stateFilter
		default: fatalError("Invalid index to convert to section: \(index)")
		}
	}
	
}

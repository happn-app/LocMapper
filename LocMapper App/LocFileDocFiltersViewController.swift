/*
 * LocFileDocFiltersViewController.swift
 * LocMapper App
 *
 * Created by François Lamboley on 7/31/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Cocoa

import LocMapper



private extension NSUserInterfaceItemIdentifier {
	
	static let stringFilter = NSUserInterfaceItemIdentifier(rawValue: "StringFilter")
	static let sep          = NSUserInterfaceItemIdentifier(rawValue: "Sep")
	static let checkFilter  = NSUserInterfaceItemIdentifier(rawValue: "CheckFilter")
	
}


class TextFieldSelectableTableView : NSTableView {
	override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
		return responder is NSTextField || super.validateProposedFirstResponder(responder, for: event)
	}
}


class LocFileDocFiltersViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	
	@IBOutlet var tableView: NSTableView!
	
	var uiState: [String: Any] {
		return [:]
	}
	
	func restoreUIState(with uiState: [String: Any]) {
		/* nop */
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	/* *********************************************************************
	   MARK: - Doc Modification Actions & Handlers
	           Handlers notify the doc object the doc has been modified
	           Actions are called to notify you of a modification of the doc
	   ********************************************************************* */
	
	override var representedObject: Any? {
		didSet {
			guard !internalRepresentedObjectChange else {return}
			
			stringFilter = ""
			envsStatus.removeAll()
			stateFiltersStatus.removeAll()
			if let filters = representedObject as? [LocFile.Filter] {
				for env in envs {envsStatus[env] = false}
				for stateFilter in stateFilters {stateFiltersStatus[stateFilter] = false}
				for filter in filters {
					switch filter {
					case .string(let str):      stringFilter = str
					case .env(let env):         envsStatus[env] = true
					case .stateTodoloc:         stateFiltersStatus["todoloc"] = true
					case .stateHardCodedValues: stateFiltersStatus["hard_coded_values"] = true
					case .stateMappedValid:     stateFiltersStatus["valid_mapped_values"] = true
					case .stateMappedInvalid:   stateFiltersStatus["invalid_mapped_values"] = true
					case .uiHidden, .uiPresentable: (/*nop*/)
					}
				}
			}
			
			tableView.reloadData()
		}
	}
	
	var handlerNotifyFiltersModification: (() -> Void)?
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func textFieldValueChanged(_ sender: NSTextField) {
		stringFilter = sender.stringValue
		updateDocFilters()
	}
	
	@IBAction func checkValueChanged(_ sender: NSButton) {
		switch sectionIndex(forRow: sender.tag) {
		case .envFilter:
			let env = envs[rowIndexInSection(forRow: sender.tag)]
			envsStatus[env] = (sender.state == .on)
			updateDocFilters()
			
		case .stateFilter:
			let stateFilter = stateFilters[rowIndexInSection(forRow: sender.tag)]
			stateFiltersStatus[stateFilter] = (sender.state == .on)
			updateDocFilters()
			
		default: fatalError("Invalid section for a check change")
		}
	}
	
	/* *******************************************
	   MARK: - Table View Data Source and Delegate
	   ******************************************* */
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return 1 /* String filter */ + 1 /* Sep */ + envs.count + 1 /* Sep */ + stateFilters.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let rowInSection = rowIndexInSection(forRow: row)
		switch sectionIndex(forRow: row) {
		case .stringFilter:
			let ret = tableView.makeView(withIdentifier: .stringFilter, owner: self)! as! NSTableCellView
			ret.textField?.stringValue = stringFilter
			return ret
			
		case .separator1:
			let ret = tableView.makeView(withIdentifier: .sep, owner: self)! as! NSTableCellView
			ret.textField?.stringValue = "Environment Filters"
			return ret
			
		case .envFilter:
			let v = tableView.makeView(withIdentifier: .checkFilter, owner: self)!
			let env = envs[rowInSection]
			(v.subviews.first! as! NSButton).state = (envsStatus[env] ?? true ? .on : .off)
			(v.subviews.first! as! NSButton).title = env
			(v.subviews.first! as! NSButton).tag = row
			return v
			
		case .separator2:
			let ret = tableView.makeView(withIdentifier: .sep, owner: self)! as! NSTableCellView
			ret.textField?.stringValue = "State Filters"
			return ret
			
		case .stateFilter:
			let v = tableView.makeView(withIdentifier: .checkFilter, owner: self)!
			let stateFilter = stateFilters[rowInSection]
			(v.subviews.first! as! NSButton).state = (stateFiltersStatus[stateFilter] ?? true ? .on : .off)
			(v.subviews.first! as! NSButton).title = NSLocalizedString(stateFilter + " state filter", comment: "")
			(v.subviews.first! as! NSButton).tag = row
			return v
		}
	}
	
	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		switch sectionIndex(forRow: row) {
		case .stringFilter:            return 27
		case .envFilter, .stateFilter: return 19
		case .separator1, .separator2: return 31
		}
	}
	
	func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
		return sectionIndex(forRow: row).isSeparator
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
	
	private var internalRepresentedObjectChange = false
	private var representedFilters: [LocFile.Filter] {
		get {return representedObject as? [LocFile.Filter] ?? []}
		set {internalRepresentedObjectChange = true; representedObject = newValue; internalRepresentedObjectChange = false}
	}
	
	/* Currently we keep the envs list statically. We may want to extract it from the LocFile later. */
	private let envs         = ["Xcode", "Android", "Windows", "RefLoc"]
	private let stateFilters = ["todoloc", "hard_coded_values", "valid_mapped_values", "invalid_mapped_values"]
	private lazy var section1SepIndex = 1
	private lazy var section2SepIndex = section1SepIndex + 1 + envs.count
	private lazy var section3SepIndex = section2SepIndex + 1 + stateFilters.count
	
	private var stringFilter = ""
	private var envsStatus = [String: Bool]()
	private var stateFiltersStatus = [String: Bool]()
	
	private func sectionIndex(forRow row: Int) -> Section {
		switch row {
		case 0:                                         return .stringFilter
		case section1SepIndex:                          return .separator1
		case (section1SepIndex + 1)..<section2SepIndex: return .envFilter
		case section2SepIndex:                          return .separator2
		case (section2SepIndex + 1)..<section3SepIndex: return .stateFilter
		default: fatalError("Invalid index to convert to section: \(index)")
		}
	}
	
	private func rowIndexInSection(forRow row: Int) -> Int {
		switch sectionIndex(forRow: row) {
		case .stringFilter: return 0
		case .separator1:   return 0
		case .envFilter:    return row - (section1SepIndex + 1)
		case .separator2:   return 0
		case .stateFilter:  return row - (section2SepIndex + 1)
		}
	}
	
	private func updateDocFilters() {
		var res = [LocFile.Filter.string(stringFilter)]
		for env in envs {if envsStatus[env] ?? true {res.append(.env(env))}}
		if stateFiltersStatus["todoloc"] ?? true               {res.append(.stateTodoloc)}
		if stateFiltersStatus["hard_coded_values"] ?? true     {res.append(.stateHardCodedValues)}
		if stateFiltersStatus["valid_mapped_values"] ?? true   {res.append(.stateMappedValid)}
		if stateFiltersStatus["invalid_mapped_values"] ?? true {res.append(.stateMappedInvalid)}
		representedFilters = res
		handlerNotifyFiltersModification?()
	}
	
}

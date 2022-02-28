/*
 * PreferencesViewController.swift
 * Lokalise Project Migration
 *
 * Created by François Lamboley on 22/08/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Cocoa
import Foundation



class PreferencesViewController : NSViewController, NSTableViewDataSource, NSTableViewDelegate {
	
	static var accessToken: String {
		return (try? Keychain.getStoredData(withIdentifier: "Lokalise Access Token").flatMap{ String(data: $0, encoding: .utf8) } ?? "") ?? ""
	}
	
	static var projectId: String {
		return UserDefaults.standard.string(forKey: "LokaliseProjectId") ?? ""
	}
	
	static var excludedTags: Set<String> {
		return Set(UserDefaults.standard.array(forKey: "ExcludedTags") as? [String] ?? [])
	}
	
	/* Lokalise to LocMapper language name mapping */
	static var languagesNameMappings: [String: String] {
		var ret = [String: String]()
		for e in udLanguagesNameMappings {
			ret[e["lokaliseName"] ?? "unknown"] = e["locmapperName"] ?? "unknown"
		}
		return ret
	}
	
	@IBOutlet var tableView: NSTableView!
	
	@IBOutlet var buttonAddLanguageMapping: NSButton!
	@IBOutlet var buttonRemoveLanguageMapping: NSButton!
	
	@objc var accessToken: String {
		get {return PreferencesViewController.accessToken}
		set {_ = try? Keychain.setStoredData(Data(newValue.utf8), withIdentifier: "Lokalise Access Token")}
	}
	
	var languagesNameMappings: [String: String] {
		get {return PreferencesViewController.languagesNameMappings}
		set {
			var udValue = [[String: String]]()
			for (k, v) in newValue {
				udValue.append(["lokaliseName": k, "locmapperName": v])
			}
			PreferencesViewController.udLanguagesNameMappings = udValue
		}
	}
	
	@IBAction func addLanguageMapping(_ sender: AnyObject) {
		var i = 2
		var curKey = "new_language"
		while languagesNameMappings[curKey] != nil {curKey = "new_language_\(i)"; i += 1}
		languagesNameMappings[curKey] = "new_language"
	}
	
	@IBAction func removeLanguageMapping(_ sender: AnyObject) {
		var udMappings = PreferencesViewController.udLanguagesNameMappings
		for i in tableView.selectedRowIndexes.sorted().reversed() {
			udMappings.remove(at: i)
		}
		PreferencesViewController.udLanguagesNameMappings = udMappings
	}
	
	@IBAction func lokaliseLanguageNameEdited(_ sender: AnyObject) {
		guard let textField = sender as? NSTextField else {return}
		let row = tableView.row(for: textField) /* Note: O(n)… */
		guard row >= 0 else {return}
		
		PreferencesViewController.udLanguagesNameMappings[row]["lokaliseName"] = textField.stringValue
	}
	
	@IBAction func locmapperLanguageNameEdited(_ sender: AnyObject) {
		guard let textField = sender as? NSTextField else {return}
		let row = tableView.row(for: textField) /* Note: O(n)… */
		guard row >= 0 else {return}
		
		PreferencesViewController.udLanguagesNameMappings[row]["locmapperName"] = textField.stringValue
	}
	
	/* *******************************************
	   MARK: - Table View Data Source and Delegate
	   ******************************************* */
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return 7
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn = tableColumn else {return nil}
		guard let r = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) else {return nil}
		return r
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private static var udLanguagesNameMappings: [[String: String]] {
		get {return UserDefaults.standard.array(forKey: "LanguagesMapping") as? [[String: String]] ?? []}
		set {
			let sorted = newValue.sorted(by: {
				$0["locmapperName"]! != $1["locmapperName"]! ?
				$0["locmapperName"]! < $1["locmapperName"]! :
				$0["lokaliseName"]! < $1["lokaliseName"]!
			})
			UserDefaults.standard.set(sorted, forKey: "LanguagesMapping")
		}
	}
	
}

/*
 * ImportKeyStructurePanelController.swift
 * LocMapper App
 *
 * Created by François Lamboley on 7/10/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import AppKit

import LocMapper



class ImportKeyStructurePanelController : NSViewController, NSTokenFieldDelegate {
	
	enum ImportType: Int {
		case Xcode = 1
		case Android = 2
	}
	
	@IBOutlet var labelEnvironment: NSTextField!
	@IBOutlet var popUpButtonEnvironment: NSPopUpButton!
	
	@IBOutlet var labelExcludedPaths: NSTextField!
	@IBOutlet var tokenFieldExcludedPaths: NSTokenField!
	
	@IBOutlet var labelImportedFolderName: NSTextField!
	@IBOutlet var textFieldImportedFolderName: NSTextField!
	
	@IBOutlet var labelImportedLanguageName: NSTextField!
	@IBOutlet var textFieldImportedLanguageName: NSTextField!
	
	private(set) var selectedImportType: ImportType
	
	var excludedPaths: [String] {
		return tokenFieldExcludedPaths.stringValue.split(separator: ",").map(String.init)
	}
	
	var importedFolderForXcode: String {
		return textFieldImportedFolderName.stringValue.isEmpty ? textFieldImportedFolderName.placeholderString ?? "" : textFieldImportedFolderName.stringValue
	}
	
	var importedLanguageName: String {
		return textFieldImportedLanguageName.stringValue.isEmpty ? textFieldImportedLanguageName.placeholderString ?? "" : textFieldImportedLanguageName.stringValue
	}
	
	init?(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?, csvLocFile f: LocFile, openPanel op: NSOpenPanel) {
		openPanel = op
		csvLocFile = f
		
		if let previouslySavedTag = csvLocFile.intMetadataValueForKey(metadataKeyForSavedEnvironment) {
			selectedImportType = ImportType(rawValue: previouslySavedTag) ?? .Xcode
		} else {
			selectedImportType = .Xcode
		}
		
		importedLanguageNameForXcode = csvLocFile.stringMetadataValueForKey(metadataKeyForImportedLanguageForXcode) ?? ""
		importedLanguageNameForAndroid = csvLocFile.stringMetadataValueForKey(metadataKeyForImportedLanguageForAndroid) ?? ""
		
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("Unsupported init method")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		configureOpenPanelForXcode()
		
		popUpButtonEnvironment.selectItem(withTag: selectedImportType.rawValue)
		
		tokenFieldExcludedPaths.stringValue = csvLocFile.stringMetadataValueForKey(metadataKeyForExcludedPathsForXcode) ?? ""
		textFieldImportedFolderName.stringValue = csvLocFile.stringMetadataValueForKey(metadataKeyForImportedFolderForXcode) ?? ""
		textFieldImportedLanguageName.stringValue = importedLanguageNameForXcode
		
		gridView = NSGridView(views: [
			[labelEnvironment, popUpButtonEnvironment],
			[labelExcludedPaths, tokenFieldExcludedPaths],
			[labelImportedFolderName, textFieldImportedFolderName],
			[labelImportedLanguageName, textFieldImportedLanguageName]
		])
		
		gridView.rowAlignment = .firstBaseline
		gridView.column(at: 0).xPlacement = .trailing
		
		let rowPopUpButton = gridView.cell(for: popUpButtonEnvironment)!.row!
		rowPopUpButton.topPadding = 3
		rowPopUpButton.bottomPadding = 8
		
		gridView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(gridView)
		
		view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-(viewPadding)-[gridView]-(viewPadding)-|", options: [], metrics: ["viewPadding": viewPadding as NSNumber], views: ["gridView": gridView]))
		view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(viewPadding)-[gridView]-(viewPadding)-|", options: [], metrics: ["viewPadding": viewPadding as NSNumber], views: ["gridView": gridView]))
		
		updateUIForSelectedEnvironment()
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func handleEnvironmentMenuSelection(sender: AnyObject) {
		selectedImportType = ImportType(rawValue: popUpButtonEnvironment.selectedTag())!
		updateUIForSelectedEnvironment()
	}
	
	func saveImportSettings() {
		csvLocFile.setMetadataValue(selectedImportType.rawValue, forKey: metadataKeyForSavedEnvironment)
		
		csvLocFile.setMetadataValue(tokenFieldExcludedPaths.stringValue, forKey: metadataKeyForExcludedPathsForXcode)
		csvLocFile.setMetadataValue(textFieldImportedFolderName.stringValue, forKey: metadataKeyForImportedFolderForXcode)
		
		switch selectedImportType {
		case .Xcode:
			csvLocFile.setMetadataValue(textFieldImportedLanguageName.stringValue, forKey: metadataKeyForImportedLanguageForXcode)
			csvLocFile.setMetadataValue(importedLanguageNameForAndroid, forKey: metadataKeyForImportedLanguageForAndroid)
			
		case .Android:
			csvLocFile.setMetadataValue(textFieldImportedLanguageName.stringValue, forKey: metadataKeyForImportedLanguageForAndroid)
			csvLocFile.setMetadataValue(importedLanguageNameForXcode, forKey: metadataKeyForImportedLanguageForXcode)
		}
	}
	
	/* ****************************
	   MARK: - Token Field Delegate
	   **************************** */
	
	/* Implementing this method disables the whitespace-trimming behavior. */
	func tokenField(_ tokenField: NSTokenField, representedObjectForEditing editingString: String) -> Any? {
		return editingString
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let viewPadding = CGFloat(9)
	
	private let metadataKeyForSavedEnvironment = "Key Structure Import — Environment"
	private let metadataKeyForExcludedPathsForXcode = "Key Structure Import (Xcode) — Excluded Paths"
	private let metadataKeyForImportedFolderForXcode = "Key Structure Import (Xcode) — Imported Folder Name"
	private let metadataKeyForImportedLanguageForXcode = "Key Structure Import (Xcode) — Imported Language Name"
	private let metadataKeyForImportedLanguageForAndroid = "Key Structure Import (Android) — Imported Language Name"
	
	private let csvLocFile: LocFile
	
	private var importedLanguageNameForXcode: String
	private var importedLanguageNameForAndroid: String
	
	private let openPanel: NSOpenPanel
	
	private var gridView: NSGridView!
	
	private var shownImportType = ImportType.Xcode
	
	private func updateUIForSelectedEnvironment() {
		guard selectedImportType != shownImportType else {return}
		
		switch shownImportType {
		case .Xcode:   importedLanguageNameForXcode   = textFieldImportedLanguageName.stringValue
		case .Android: importedLanguageNameForAndroid = textFieldImportedLanguageName.stringValue
		}
		
		shownImportType = selectedImportType
		
		switch selectedImportType {
		case .Xcode:
			configureOpenPanelForXcode()
			
			textFieldImportedLanguageName.stringValue = importedLanguageNameForXcode
			
			gridView.insertRow(at: 1, with: [labelExcludedPaths, tokenFieldExcludedPaths])
			gridView.insertRow(at: 2, with: [labelImportedFolderName, textFieldImportedFolderName])
			
			updateFrameHeight()
			
		case .Android:
			configureOpenPanelForAndroid()
			
			textFieldImportedLanguageName.stringValue = importedLanguageNameForAndroid
			
			for v in [tokenFieldExcludedPaths, textFieldImportedFolderName] {
				if let v = v, let row = gridView.cell(for: v)?.row {
					gridView.removeRow(at: gridView.index(of: row))
				}
			}
			for v in [labelExcludedPaths, tokenFieldExcludedPaths, labelImportedFolderName, textFieldImportedFolderName] {
				v?.removeFromSuperview()
			}
			
			updateFrameHeight()
		}
	}
	
	private func configureOpenPanelForXcode() {
		openPanel.allowedFileTypes = nil
		openPanel.canChooseFiles = false
		openPanel.canChooseDirectories = true
		openPanel.allowsMultipleSelection = false
	}
	
	private func configureOpenPanelForAndroid() {
		openPanel.allowedFileTypes = ["xml"]
		openPanel.canChooseFiles = true
		openPanel.canChooseDirectories = false
		openPanel.allowsMultipleSelection = true
	}
	
	private func updateFrameHeight() {
		openPanel.accessoryView = nil
		
		/* Not sure this actually is the correct height we're setting... but it
		 * seems to be working with this. (We DO have a warning in the logs
		 * though.) */
		view.frame.size.height = gridView.intrinsicContentSize.height + 2*viewPadding
		
		openPanel.accessoryView = view
		openPanel.isAccessoryViewDisclosed = true
	}
	
}

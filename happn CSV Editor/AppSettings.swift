/*
 * Constants.swift
 * Localizer
 *
 * Created by François Lamboley on 11/6/16.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation



class AppSettings {
	
	/* We don't have a Service architecture */
	static let shared = AppSettings()
	
	/* Let's disable direct instantiation of this class */
	private init() {
	}
	
	func registerDefaultSettings() {
		/* Registering default user defaults */
		let defaultValues: [SettingsKey: Any] = [
			.showAlertForTabChangeDiscardMappingEdition: true,
			.showAlertForSelectionChangeDiscardMappingEdition: true,
			.showAlertForDiscardingMapping: true
		]
		
		var defaultValuesNoNull = [String: Any]()
		for (key, val) in defaultValues {
			if !(val is NSNull) {
				defaultValuesNoNull[key.rawValue] = val
			}
		}
		ud.register(defaults: defaultValuesNoNull)
	}
	
	/* **************************
	   MARK: - Settings Accessors
	   ************************** */
	
	var showAlertForDiscardingMapping: Bool {
		get {return ud.bool(forKey: SettingsKey.showAlertForDiscardingMapping.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.showAlertForDiscardingMapping.rawValue)}
	}
	
	var showAlertForTabChangeDiscardMappingEdition: Bool {
		get {return ud.bool(forKey: SettingsKey.showAlertForTabChangeDiscardMappingEdition.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.showAlertForTabChangeDiscardMappingEdition.rawValue)}
	}
	
	var showAlertForSelectionChangeDiscardMappingEdition: Bool {
		get {return ud.bool(forKey: SettingsKey.showAlertForSelectionChangeDiscardMappingEdition.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.showAlertForSelectionChangeDiscardMappingEdition.rawValue)}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let ud = UserDefaults.standard
	
	private enum SettingsKey : String {
		case showAlertForDiscardingMapping = "HC Show Alert for Discarding Mapping"
		case showAlertForTabChangeDiscardMappingEdition = "HC Show Alert for Tab Change Discard Mapping Edition"
		case showAlertForSelectionChangeDiscardMappingEdition = "HC Show Alert for Selection Change Discard Mapping Edition"
	}
	
}

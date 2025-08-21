/*
 * Constants.swift
 * LocMapper App
 *
 * Created by François Lamboley on 2016-11-06.
 * Copyright © 2016 happn. All rights reserved.
 */

import Foundation



struct AppSettings : Sendable {
	
	/* We don't have a Service architecture */
	static let shared = AppSettings()
	
	private init() {}
	
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
		            get {ud.bool(forKey: SettingsKey.showAlertForDiscardingMapping.rawValue)}
		nonmutating set {ud.set(newValue, forKey: SettingsKey.showAlertForDiscardingMapping.rawValue)}
	}
	
	var showAlertForTabChangeDiscardMappingEdition: Bool {
		            get {ud.bool(forKey: SettingsKey.showAlertForTabChangeDiscardMappingEdition.rawValue)}
		nonmutating set {ud.set(newValue, forKey: SettingsKey.showAlertForTabChangeDiscardMappingEdition.rawValue)}
	}
	
	var showAlertForSelectionChangeDiscardMappingEdition: Bool {
		            get {ud.bool(forKey: SettingsKey.showAlertForSelectionChangeDiscardMappingEdition.rawValue)}
		nonmutating set {ud.set(newValue, forKey: SettingsKey.showAlertForSelectionChangeDiscardMappingEdition.rawValue)}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var ud: UserDefaults {UserDefaults.standard}
	
	private enum SettingsKey : String {
		case showAlertForDiscardingMapping = "HC Show Alert for Discarding Mapping"
		case showAlertForTabChangeDiscardMappingEdition = "HC Show Alert for Tab Change Discard Mapping Edition"
		case showAlertForSelectionChangeDiscardMappingEdition = "HC Show Alert for Selection Change Discard Mapping Edition"
	}
	
}

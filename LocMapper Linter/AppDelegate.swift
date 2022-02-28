/*
 * AppDelegate.swift
 * LocMapper Linter
 *
 * Created by François Lamboley on 12/12/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import Cocoa



@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	func applicationWillFinishLaunching(_ notification: Notification) {
		/* Registering default user defaults. */
		do {
			let defaultValues: [String: Any] = [
				"HPN Default Show Mapped Latest": true,
				"HPN Default Show Unmapped": true,
				"HPN Default Show Not Latest Version": true,
				"HPN Default Also Show One Version Keys": false
			]
			
			var defaultValuesNoNull = [String: Any]()
			for (key, val) in defaultValues {
				if !(val is NSNull) {
					defaultValuesNoNull[key] = val
				}
			}
			UserDefaults.standard.register(defaults: defaultValuesNoNull)
		}
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
	
	@IBAction func showPreferences(_ sender: AnyObject) {
		if preferencesViewController == nil {
			preferencesViewController = (NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "PrefsWindowController") as! NSWindowController)
		}
		preferencesViewController?.showWindow(sender)
	}
	
	private var preferencesViewController: NSWindowController?
	
}

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

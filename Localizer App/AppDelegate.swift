/*
 * AppDelegate.swift
 * Localizer App
 *
 * Created by François Lamboley on 12/2/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	func applicationWillFinishLaunching(_ notification: Notification) {
		/* Let's register the user defaults */
		AppSettings.shared.registerDefaultSettings()
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
	}
	
}

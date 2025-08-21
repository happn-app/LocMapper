/*
 * AppDelegate.swift
 * LocMapper App
 *
 * Created by François Lamboley on 2015-12-02.
 * Copyright © 2015 happn. All rights reserved.
 */

import Cocoa



@main
final class AppDelegate : NSObject, NSApplicationDelegate {
	
	func applicationWillFinishLaunching(_ notification: Notification) {
		/* Let's register the user defaults */
		AppSettings.shared.registerDefaultSettings()
	}
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
	}
	
}

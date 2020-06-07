//
//  AppDelegate.swift
//  MilanInstaller
//
//  Created by Yuanzhe Bian on 6/5/20.
//  Copyright © 2020 rijn. All rights reserved.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Create the window and set the content view. 
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Apk Installer")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        #if !DEBUG
        let fileManager = FileManager()
        fileManager.changeCurrentDirectoryPath(Bundle.main.bundleURL.deletingLastPathComponent().path)
        #endif
        
        ApkService.refresh()
        DeviceService.refresh()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}


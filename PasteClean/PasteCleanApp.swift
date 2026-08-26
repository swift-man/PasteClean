//
//  PasteCleanApp.swift
//  PasteClean
//
//  Created by 김승진 on 2026. 8. 19.
//

import SwiftUI

@MainActor
private final class PasteCleanAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    HelpMenu.install()
  }
}

@main
struct PasteCleanApp: App {
  @NSApplicationDelegateAdaptor(PasteCleanAppDelegate.self) private var appDelegate
  @AppStorage("showsLineNumbers") private var showsLineNumbers = true
  @StateObject private var guide = GuideState.shared

  var body: some Scene {
    WindowGroup("PasteClean") {
      ContentView()
        .environmentObject(guide)
    }
    .defaultSize(width: 1040, height: 640)
    .commands {
      CommandGroup(replacing: .newItem) {}
      // Only this placement renders here: `.help`, `.appInfo` and `CommandMenu`
      // are all dropped, and items inserted into the Help menu through AppKit
      // are wiped when SwiftUI rebuilds the main menu.
      CommandGroup(after: .sidebar) {
        Toggle("Show Line Numbers", isOn: $showsLineNumbers)
          .keyboardShortcut("l", modifiers: [.command, .shift])
      }
    }
  }
}

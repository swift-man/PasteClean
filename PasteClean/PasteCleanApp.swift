//
//  PasteCleanApp.swift
//  PasteClean
//
//  Created by 김승진 on 2026. 8. 19.
//

import SwiftUI

@main
struct PasteCleanApp: App {
  @AppStorage("showsLineNumbers") private var showsLineNumbers = true
  @StateObject private var guide = GuideState.shared

  var body: some Scene {
    WindowGroup("PasteClean") {
      ContentView()
        .environmentObject(guide)
        .onAppear(perform: HelpMenu.install)
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

//
//  HelpMenu.swift
//  PasteClean
//
//  Created by 김승진 on 2026. 8. 19.
//

import AppKit

/// Puts the two guides in the Help menu.
///
/// SwiftUI ignores the `.help` command placement here and rebuilds the main menu
/// often enough that items inserted once are dropped again, so this attaches a
/// delegate and fills the menu in each time it is about to open.
@MainActor
enum HelpMenu {
  private static let delegate = Delegate()
  private static var timer: Timer?

  static func install() {
    attach()
    // The main menu is rebuilt as the app settles; keep re-attaching briefly.
    timer?.invalidate()
    var ticks = 0
    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
      MainActor.assumeIsolated {
        attach()
        ticks += 1
        if ticks >= 20 { timer.invalidate() }
      }
    }
  }

  private static func attach() {
    guard let menu = helpMenu else { return }
    if menu.delegate !== delegate { menu.delegate = delegate }
    delegate.fill(menu)
  }

  private static var helpMenu: NSMenu? {
    if let menu = NSApp.helpMenu { return menu }

    let submenus = NSApp.mainMenu?.items.compactMap(\.submenu) ?? []
    let menu = submenus.first { submenu in
      submenu.items.contains { $0.action == #selector(NSApplication.showHelp(_:)) }
    }
    if let menu { NSApp.helpMenu = menu }
    return menu
  }

  fileprivate static let entries: [(title: String, topic: GuideTopic)] = [
    (String(localized: "How to use PasteClean"), .app),
    (String(localized: "Install and use the Xcode extension"), .xcodeExtension)
  ]

  @MainActor
  private final class Delegate: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) { fill(menu) }

    func menuWillOpen(_ menu: NSMenu) { fill(menu) }

    func fill(_ menu: NSMenu) {
      if !menu.items.contains(where: { $0.title == HelpMenu.entries[0].title }) {
        for (index, entry) in HelpMenu.entries.enumerated() {
          let item = NSMenuItem(title: entry.title, action: #selector(open(_:)), keyEquivalent: "")
          item.target = self
          item.representedObject = entry.topic.rawValue
          menu.insertItem(item, at: index)
        }
        menu.insertItem(.separator(), at: HelpMenu.entries.count)
      }
      // AppKit leaves a separator above the system's own Help item.
      while menu.items.first?.isSeparatorItem == true {
        menu.removeItem(at: 0)
      }
    }

    @objc private func open(_ sender: NSMenuItem) {
      guard let raw = sender.representedObject as? String,
            let topic = GuideTopic(rawValue: raw)
      else { return }
      GuideState.shared.topic = topic
    }
  }
}

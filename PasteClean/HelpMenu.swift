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
  private static var trackingObserver: NSObjectProtocol?

  static func install() {
    attach()
    observeMenuTracking()
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

  /// SwiftUI throws the whole main menu away and builds a new one whenever its
  /// commands change — toggling Show Line Numbers is enough — and the
  /// replacement Help menu carries neither our items nor our delegate, so the
  /// entries vanish for good. Re-attaching the moment any menu starts tracking
  /// puts them back before the Help menu can be drawn.
  private static func observeMenuTracking() {
    guard trackingObserver == nil else { return }
    trackingObserver = NotificationCenter.default.addObserver(
      forName: NSMenu.didBeginTrackingNotification,
      object: nil,
      queue: .main
    ) { _ in
      MainActor.assumeIsolated { attach() }
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
      normalizeSeparators(menu)
    }

    /// AppKit puts its own separator above the system's Help item, and on a
    /// real click it does so after this has already run — which strands one at
    /// the top of the menu and doubles the one in the middle.
    private func normalizeSeparators(_ menu: NSMenu) {
      while menu.items.first?.isSeparatorItem == true {
        menu.removeItem(at: 0)
      }
      for index in stride(from: menu.items.count - 1, to: 0, by: -1)
      where menu.items[index].isSeparatorItem && menu.items[index - 1].isSeparatorItem {
        menu.removeItem(at: index)
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

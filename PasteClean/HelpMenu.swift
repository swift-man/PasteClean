//
//  HelpMenu.swift
//  PasteClean
//
//  Created by 김승진 on 2026. 8. 19.
//

import AppKit

/// Connects the standard app Help item to the app guide and adds the extension guide.
///
/// SwiftUI ignores the `.help` command placement here and rebuilds the main menu
/// often enough that items inserted once are dropped again, so this attaches a
/// delegate and fills the menu in each time it is about to open.
@MainActor
enum HelpMenu {
  private static let delegate = Delegate()
  private static var installTask: Task<Void, Never>?
  private static var trackingObserver: NSObjectProtocol?

  static func install() {
    observeMenuTracking()
    // The main menu is rebuilt as the app settles; keep re-attaching briefly.
    installTask?.cancel()
    installTask = Task { @MainActor in
      for _ in 0..<20 {
        guard !Task.isCancelled else { return }
        attach()
        try? await Task.sleep(nanoseconds: 500_000_000)
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
    attach(to: helpMenu)
  }

  /// Accepts a menu explicitly so the AppKit boundary can be verified without
  /// depending on the test runner's process-wide main menu.
  static func attach(to menu: NSMenu?) {
    guard let menu else { return }
    if menu.delegate !== delegate { menu.delegate = delegate }
    delegate.fill(menu)
  }

  private static var helpMenu: NSMenu? {
    let submenus = NSApp.mainMenu?.items.compactMap(\.submenu) ?? []
    let menu = submenus.first { submenu in
      submenu.items.contains {
        $0.action == #selector(NSApplication.showHelp(_:))
          || $0.identifier == appHelpIdentifier
          || $0.identifier == extensionEntryIdentifier
      }
    } ?? NSApp.mainMenu?.items.last?.submenu
    if let menu { NSApp.helpMenu = menu }
    return menu ?? NSApp.helpMenu
  }

  static let extensionEntry = (
    title: String(localized: "Install and use the Xcode extension"),
    topic: GuideTopic.xcodeExtension
  )
  static let appHelpTitle = String(localized: "PasteClean Help")
  static let extensionEntryIdentifier = NSUserInterfaceItemIdentifier(
    "PasteClean.ExtensionGuide"
  )
  static let appHelpIdentifier = NSUserInterfaceItemIdentifier(
    "PasteClean.AppHelp"
  )

  @MainActor
  final class Delegate: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) { fill(menu) }

    func menuWillOpen(_ menu: NSMenu) { fill(menu) }

    func fill(_ menu: NSMenu) {
      removeLegacyAppGuideItem(from: menu)
      redirectStandardHelpItem(in: menu)
      insertExtensionGuideIfNeeded(in: menu)
      normalizeSeparators(menu)
    }

    /// The system-provided “PasteClean Help” item keeps its native title and
    /// placement, but opens the in-app usage guide instead of a help book.
    private func redirectStandardHelpItem(in menu: NSMenu) {
      let item: NSMenuItem
      if let existing = menu.items.first(where: {
        $0.identifier == HelpMenu.appHelpIdentifier
          || $0.action == #selector(NSApplication.showHelp(_:))
      }) {
        item = existing
      } else {
        item = NSMenuItem(
          title: HelpMenu.appHelpTitle,
          action: #selector(open(_:)),
          keyEquivalent: ""
        )
        menu.addItem(item)
      }

      item.identifier = HelpMenu.appHelpIdentifier
      item.target = self
      item.action = #selector(open(_:))
      item.representedObject = GuideTopic.app.rawValue

      // AppKit can append its original help-book item after the delegate has
      // filled the menu. The next attachment pass removes that duplicate.
      for duplicate in menu.items where duplicate !== item
        && duplicate.action == #selector(NSApplication.showHelp(_:)) {
        menu.removeItem(duplicate)
      }
    }

    private func insertExtensionGuideIfNeeded(in menu: NSMenu) {
      let item: NSMenuItem
      if let existing = menu.items.first(where: {
        $0.identifier == HelpMenu.extensionEntryIdentifier
      }) {
        item = existing
      } else {
        item = NSMenuItem(
          title: HelpMenu.extensionEntry.title,
          action: #selector(open(_:)),
          keyEquivalent: ""
        )
        item.identifier = HelpMenu.extensionEntryIdentifier
        item.target = self
        item.representedObject = HelpMenu.extensionEntry.topic.rawValue
        menu.insertItem(item, at: 0)
      }

      guard let index = menu.items.firstIndex(of: item), index + 1 < menu.items.count,
            !menu.items[index + 1].isSeparatorItem
      else { return }
      menu.insertItem(.separator(), at: index + 1)
    }

    /// Removes the old duplicate item when the menu survives an in-place app
    /// update. The native app Help item now owns the app-guide action.
    private func removeLegacyAppGuideItem(from menu: NSMenu) {
      let legacyTitle = String(localized: "How to use PasteClean")
      for item in menu.items where item.title == legacyTitle {
        menu.removeItem(item)
      }
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

    @objc func open(_ sender: NSMenuItem) {
      guard let raw = sender.representedObject as? String,
            let topic = GuideTopic(rawValue: raw)
      else { return }
      GuideState.shared.topic = topic
    }
  }
}

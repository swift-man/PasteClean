//
//  GuideAndHelpMenuTests.swift
//  PasteCleanTests
//

import AppKit
import Testing

@Suite("Guide and Help menu", .serialized)
@MainActor
struct GuideAndHelpMenuTests {

  @Test("The app guide is shown until its first actual presentation")
  func appGuideIsOneTimeOnboarding() {
    withFreshDefaults { defaults in
      let firstLaunch = GuideState(defaults: defaults)
      #expect(firstLaunch.topic == .app)

      firstLaunch.markAsPresented(.app)

      let laterLaunch = GuideState(defaults: defaults)
      #expect(laterLaunch.topic == nil)
    }
  }

  @Test("Opening the extension guide does not consume app onboarding")
  func extensionGuideDoesNotConsumeOnboarding() {
    withFreshDefaults { defaults in
      let state = GuideState(defaults: defaults)
      state.markAsPresented(.xcodeExtension)

      let laterLaunch = GuideState(defaults: defaults)
      #expect(laterLaunch.topic == .app)
    }
  }

  @Test("The standard Help item is redirected without a duplicate usage item")
  func redirectsStandardHelpItem() {
    let menu = NSMenu()
    let legacy = NSMenuItem(
      title: String(localized: "How to use PasteClean"),
      action: nil,
      keyEquivalent: ""
    )
    let nativeHelp = NSMenuItem(
      title: "PasteClean Help",
      action: #selector(NSApplication.showHelp(_:)),
      keyEquivalent: ""
    )
    menu.addItem(legacy)
    menu.addItem(nativeHelp)

    HelpMenu.Delegate().fill(menu)

    #expect(menu.items.first?.identifier == HelpMenu.extensionEntryIdentifier)
    #expect(menu.items.dropFirst().first?.isSeparatorItem == true)
    #expect(menu.items.contains { $0 === nativeHelp })
    #expect(nativeHelp.identifier == HelpMenu.appHelpIdentifier)
    #expect(nativeHelp.representedObject as? String == GuideTopic.app.rawValue)
    #expect(!menu.items.contains { $0.title == legacy.title })
    #expect(!menu.items.contains { $0.action == #selector(NSApplication.showHelp(_:)) })
  }

  @Test("Filling an empty menu creates both guide entries")
  func createsEntriesForAnEmptyMenu() {
    let menu = NSMenu()

    HelpMenu.Delegate().fill(menu)

    #expect(menu.items.count == 3)
    #expect(menu.items[0].identifier == HelpMenu.extensionEntryIdentifier)
    #expect(menu.items[1].isSeparatorItem)
    #expect(menu.items[2].identifier == HelpMenu.appHelpIdentifier)
    #expect(menu.items[0].representedObject as? String == GuideTopic.xcodeExtension.rawValue)
    #expect(menu.items[2].representedObject as? String == GuideTopic.app.rawValue)
  }

  @Test("Repeated fills and a late native item stay duplicate-free")
  func repeatedFillIsIdempotent() {
    let menu = NSMenu()
    let delegate = HelpMenu.Delegate()
    delegate.fill(menu)

    menu.addItem(NSMenuItem(
      title: "Late native Help",
      action: #selector(NSApplication.showHelp(_:)),
      keyEquivalent: ""
    ))
    menu.insertItem(.separator(), at: 0)
    menu.insertItem(.separator(), at: 0)

    delegate.fill(menu)
    delegate.fill(menu)

    #expect(menu.items.filter { $0.identifier == HelpMenu.extensionEntryIdentifier }.count == 1)
    #expect(menu.items.filter { $0.identifier == HelpMenu.appHelpIdentifier }.count == 1)
    #expect(!menu.items.contains { $0.action == #selector(NSApplication.showHelp(_:)) })
    #expect(menu.items.first?.isSeparatorItem == false)
    #expect(!zip(menu.items, menu.items.dropFirst()).contains {
      $0.isSeparatorItem && $1.isSeparatorItem
    })
  }

  @Test("A valid guide menu action opens the requested guide")
  func validMenuActionOpensGuide() {
    let previousTopic = GuideState.shared.topic
    defer { GuideState.shared.topic = previousTopic }
    GuideState.shared.topic = nil
    let item = NSMenuItem()
    item.representedObject = GuideTopic.xcodeExtension.rawValue

    HelpMenu.Delegate().open(item)

    #expect(GuideState.shared.topic == .xcodeExtension)
  }

  @Test("An invalid guide menu action leaves the current guide unchanged")
  func invalidMenuActionIsIgnored() {
    let previousTopic = GuideState.shared.topic
    defer { GuideState.shared.topic = previousTopic }
    GuideState.shared.topic = .app
    let item = NSMenuItem()
    item.representedObject = "unknown-guide"

    HelpMenu.Delegate().open(item)

    #expect(GuideState.shared.topic == .app)
  }

  @Test("Attaching replaces the delegate and fills the menu")
  func attachesDelegateAndFillsMenu() {
    let menu = NSMenu()
    let previousDelegate = EmptyMenuDelegate()
    menu.delegate = previousDelegate
    #expect(menu.delegate === previousDelegate)

    HelpMenu.attach(to: menu)

    #expect(menu.delegate is HelpMenu.Delegate)
    #expect(menu.items.contains { $0.identifier == HelpMenu.extensionEntryIdentifier })
    #expect(menu.items.contains { $0.identifier == HelpMenu.appHelpIdentifier })
  }

  @Test("Filling removes consecutive separators in the middle of a menu")
  func normalizesMiddleSeparators() {
    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "Before", action: nil, keyEquivalent: ""))
    menu.addItem(.separator())
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "After", action: nil, keyEquivalent: ""))

    HelpMenu.Delegate().fill(menu)

    #expect(!zip(menu.items, menu.items.dropFirst()).contains {
      $0.isSeparatorItem && $1.isSeparatorItem
    })
  }

  @Test("The last submenu is used while AppKit is still building Help")
  func resolvesTransientHelpMenuFallback() {
    let mainMenu = NSMenu()
    let fileMenu = NSMenu(title: "File")
    let helpMenu = NSMenu(title: "Help")
    let registeredHelpMenu = NSMenu(title: "Previously Registered Help")
    mainMenu.addItem(NSMenuItem(title: "File", action: nil, keyEquivalent: ""))
    mainMenu.setSubmenu(fileMenu, for: mainMenu.items[0])
    mainMenu.addItem(NSMenuItem(title: "Help", action: nil, keyEquivalent: ""))
    mainMenu.setSubmenu(helpMenu, for: mainMenu.items[1])

    let resolved = HelpMenu.resolveHelpMenu(
      in: mainMenu,
      registeredHelpMenu: registeredHelpMenu
    )

    #expect(resolved === helpMenu)
  }

  private func withFreshDefaults(_ body: (UserDefaults) -> Void) {
    let suiteName = "GuideAndHelpMenuTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    body(defaults)
  }
}

@MainActor
private final class EmptyMenuDelegate: NSObject, NSMenuDelegate {}

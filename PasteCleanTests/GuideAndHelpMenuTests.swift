//
//  GuideAndHelpMenuTests.swift
//  PasteCleanTests
//

import AppKit
import Testing

@Suite("Guide and Help menu", .serialized)
@MainActor
struct GuideAndHelpMenuTests {

  @Test("About metadata reads version, build, and copyright from the bundle dictionary")
  func readsAboutMetadata() {
    let metadata = AppMetadata(infoDictionary: [
      "CFBundleDisplayName": "PasteClean Test",
      "CFBundleShortVersionString": "1.2",
      "CFBundleVersion": "34",
      "NSHumanReadableCopyright": "Copyright © 2026 PasteClean",
    ])

    #expect(metadata.appName == "PasteClean Test")
    #expect(metadata.shortVersion == "1.2")
    #expect(metadata.buildVersion == "34")
    #expect(metadata.copyright == "Copyright © 2026 PasteClean")
  }

  @Test("About metadata ignores blank optional values")
  func ignoresBlankAboutMetadata() {
    let metadata = AppMetadata(infoDictionary: [
      "CFBundleName": "PasteClean",
      "NSHumanReadableCopyright": "   ",
    ])

    #expect(metadata.appName == "PasteClean")
    #expect(metadata.shortVersion == "—")
    #expect(metadata.buildVersion == "—")
    #expect(metadata.copyright == nil)
  }

  @Test("Bundled Markdown keeps headings, paragraphs, and wrapped list items")
  func parsesBundledMarkdownStructure() {
    let blocks = MarkdownDocument.blocks(
      from: """
        ## Heading

        A paragraph that is
        wrapped across lines.

        - **Item:** A list item that is
          wrapped across lines.
        """)

    #expect(
      blocks == [
        .heading(level: 2, text: "Heading"),
        .paragraph("A paragraph that is wrapped across lines."),
        .bullet("**Item:** A list item that is wrapped across lines."),
      ])
  }

  @Test("Bundled Markdown accepts mixed and Unicode line endings")
  func parsesBundledMarkdownLineEndings() {
    let blocks = MarkdownDocument.blocks(
      from: "## Heading\r\n\r\nA paragraph.\r\r- Item\u{2028}continued"
    )

    #expect(
      blocks == [
        .heading(level: 2, text: "Heading"),
        .paragraph("A paragraph."),
        .bullet("Item continued"),
      ])
  }

  @Test("The in-app privacy policy shows only the current language")
  func localizesBundledPrivacyPolicy() {
    let policy = """
      # Privacy

      Effective date / 시행일: August 31, 2026 / 2026년 8월 31일

      ## English

      English policy.

      ## 한국어

      한국어 정책입니다.
      """

    let korean = MarkdownDocument.localizedPrivacyContents(
      policy,
      languageCode: "ko"
    )
    let english = MarkdownDocument.localizedPrivacyContents(
      policy,
      languageCode: "en"
    )

    #expect(korean.contains("한국어 정책입니다."))
    #expect(!korean.contains("English policy."))
    #expect(korean.contains("시행일: 2026년 8월 31일"))
    #expect(!korean.contains("Effective date"))
    #expect(english.contains("English policy."))
    #expect(!english.contains("한국어 정책입니다."))
    #expect(english.contains("Effective date: August 31, 2026"))
    #expect(!english.contains("시행일"))
  }

  @Test("Privacy localization falls back when section markers are reversed")
  func rejectsReversedPrivacySectionMarkers() {
    let malformedPolicy = """
      # Privacy

      ## 한국어

      한국어 정책입니다.

      ## English

      English policy.
      """

    #expect(
      MarkdownDocument.localizedPrivacyContents(
        malformedPolicy,
        languageCode: "en"
      ) == malformedPolicy
    )
  }

  @Test("Privacy localization falls back when a section marker is missing")
  func rejectsMissingPrivacySectionMarker() {
    let incompletePolicy = """
      # Privacy

      ## English

      English policy.
      """

    #expect(
      MarkdownDocument.localizedPrivacyContents(
        incompletePolicy,
        languageCode: "en"
      ) == incompletePolicy
    )
  }

  @Test("The standard About item opens the custom reusable window")
  func redirectsStandardAboutItem() {
    let menu = NSMenu()
    let nativeAbout = NSMenuItem(
      title: "About PasteClean",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
      keyEquivalent: ""
    )
    menu.addItem(nativeAbout)

    AboutMenu.attach(to: menu)
    AboutMenu.attach(to: menu)

    #expect(nativeAbout.identifier == AboutMenu.itemIdentifier)
    #expect(nativeAbout.target === AboutWindowController.shared)
    #expect(nativeAbout.action == #selector(AboutWindowController.showAbout(_:)))
    #expect(menu.items.filter { $0.identifier == AboutMenu.itemIdentifier }.count == 1)
    #expect(
      !menu.items.contains {
        $0.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:))
      }
    )
  }

  @Test("The application menu is resolved independently of its position")
  func resolvesApplicationMenu() {
    let mainMenu = NSMenu()
    let fileMenu = NSMenu(title: "File")
    let appMenu = NSMenu(title: "PasteClean")
    mainMenu.addItem(NSMenuItem(title: "File", action: nil, keyEquivalent: ""))
    mainMenu.setSubmenu(fileMenu, for: mainMenu.items[0])
    mainMenu.addItem(NSMenuItem(title: "PasteClean", action: nil, keyEquivalent: ""))
    mainMenu.setSubmenu(appMenu, for: mainMenu.items[1])
    appMenu.addItem(
      NSMenuItem(
        title: "About PasteClean",
        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
        keyEquivalent: ""
      ))

    #expect(AboutMenu.resolveApplicationMenu(in: mainMenu) === appMenu)
  }

  @Test("The application menu resolver does not guess without an About item")
  func doesNotGuessApplicationMenu() {
    let mainMenu = NSMenu()
    let fileMenu = NSMenu(title: "File")
    mainMenu.addItem(NSMenuItem(title: "File", action: nil, keyEquivalent: ""))
    mainMenu.setSubmenu(fileMenu, for: mainMenu.items[0])

    #expect(AboutMenu.resolveApplicationMenu(in: mainMenu) == nil)
  }

  @Test("A late standard About item does not duplicate the custom item")
  func removesLateStandardAboutItem() throws {
    let menu = NSMenu()
    AboutMenu.attach(to: menu)
    let customAbout = try #require(
      menu.items.first { $0.identifier == AboutMenu.itemIdentifier }
    )
    let lateStandardAbout = NSMenuItem(
      title: "About PasteClean",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
      keyEquivalent: ""
    )
    menu.insertItem(lateStandardAbout, at: 0)

    AboutMenu.attach(to: menu)

    #expect(menu.items.filter { $0.identifier == AboutMenu.itemIdentifier }.count == 1)
    #expect(menu.items.contains { $0 === customAbout })
    #expect(!menu.items.contains { $0 === lateStandardAbout })
  }

  @Test("Each guide stays focused on its own workflow")
  func guidesStayFocused() {
    #expect(GuideTopic.app.stepTitles.count == 2)
    #expect(GuideTopic.xcodeExtension.stepTitles.count == 2)
    #expect(
      GuideTopic.xcodeExtension.stepTitles[0]
        == String(localized: "Enable the Xcode extension")
    )
    #expect(
      GuideTopic.xcodeExtension.stepTitles[1]
        == String(localized: "Use it in Xcode")
    )
  }

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

    menu.addItem(
      NSMenuItem(
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
    #expect(
      !zip(menu.items, menu.items.dropFirst()).contains {
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

    #expect(
      !zip(menu.items, menu.items.dropFirst()).contains {
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

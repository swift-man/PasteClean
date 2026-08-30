//
//  AboutView.swift
//  PasteClean
//

import AppKit
import SwiftUI

/// Product and support information shown from the standard application menu.
struct AboutView: View {
  private let metadata: AppMetadata
  @State private var presentedDocument: AboutDocument?

  init(bundle: Bundle = .main) {
    metadata = AppMetadata(bundle: bundle)
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(nsImage: NSApplication.shared.applicationIconImage)
        .resizable()
        .scaledToFit()
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)

      VStack(spacing: 5) {
        Text(metadata.appName)
          .font(.title.bold())
        Text(metadata.versionDescription)
          .font(.callout)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
        if let copyright = metadata.copyright {
          Text(copyright)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
      }

      Text("PasteClean is licensed under GNU LGPL v3 or later.")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 10) {
        Link(destination: Self.sourceCodeURL) {
          Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .accessibilityHint("Open the PasteClean source code repository")

        Link(destination: Self.supportURL) {
          Label("Support", systemImage: "questionmark.bubble")
        }
        .accessibilityHint("Open PasteClean support information")
      }
      .buttonStyle(.bordered)

      Divider()

      HStack(spacing: 18) {
        Button("Privacy Policy") {
          presentedDocument = .privacy
        }
        Button("Open Source Licenses") {
          presentedDocument = .licenses
        }
      }
      .buttonStyle(.link)
    }
    .padding(28)
    .frame(width: 520)
    .sheet(item: $presentedDocument) { document in
      AboutDocumentSheet(document: document)
    }
  }

  private static let sourceCodeURL = URL(string: "https://github.com/swift-man/PasteClean")!
  private static let supportURL = URL(
    string: "https://github.com/swift-man/PasteClean/blob/main/SUPPORT.md"
  )!
}

/// Bundle values are kept out of the view so missing optional metadata has a
/// predictable fallback and the presentation remains straightforward to test.
struct AppMetadata: Equatable {
  let appName: String
  let shortVersion: String
  let buildVersion: String
  let copyright: String?

  init(bundle: Bundle) {
    self.init(infoDictionary: bundle.infoDictionary ?? [:])
  }

  init(infoDictionary: [String: Any]) {
    appName =
      Self.nonemptyString(
        infoDictionary["CFBundleDisplayName"]
      ) ?? Self.nonemptyString(
        infoDictionary["CFBundleName"]
      ) ?? "PasteClean"
    shortVersion =
      Self.nonemptyString(
        infoDictionary["CFBundleShortVersionString"]
      ) ?? "—"
    buildVersion =
      Self.nonemptyString(
        infoDictionary["CFBundleVersion"]
      ) ?? "—"
    copyright = Self.nonemptyString(
      infoDictionary["NSHumanReadableCopyright"]
    )
  }

  var versionDescription: String {
    String(
      format: String(localized: "Version %@ (%@)"),
      locale: .current,
      shortVersion,
      buildVersion
    )
  }

  private static func nonemptyString(_ value: Any?) -> String? {
    guard let string = value as? String else { return nil }
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

enum AboutDocument: String, Identifiable {
  case privacy
  case licenses

  var id: String { rawValue }
}

private struct AboutDocumentSheet: View {
  let document: AboutDocument
  @Environment(\.dismiss) private var dismiss

  private var title: LocalizedStringKey {
    switch document {
    case .privacy:
      "Privacy Policy"
    case .licenses:
      "Open Source Licenses"
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(title)
          .font(.title2.bold())
        Spacer()
      }
      .padding(20)

      Divider()

      Group {
        switch document {
        case .privacy:
          BundledDocumentView(document: .privacyPolicy)
        case .licenses:
          LicenseDocumentsView()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Divider()

      HStack {
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.cancelAction)
      }
      .padding(16)
    }
    .frame(minWidth: 680, idealWidth: 720, minHeight: 520, idealHeight: 600)
  }
}

/// Owns the one reusable About window opened by the standard app-menu item.
@MainActor
final class AboutWindowController: NSWindowController {
  static let shared = AboutWindowController()

  private init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = String(localized: "About PasteClean")
    window.contentView = NSHostingView(rootView: AboutView())
    window.contentMinSize = NSSize(width: 520, height: 400)
    window.isReleasedWhenClosed = false
    window.center()
    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc func showAbout(_ sender: Any?) {
    guard let window else { return }
    NSApplication.shared.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(sender)
  }
}

/// Redirects AppKit's standard About item without changing its native title or
/// position. SwiftUI may rebuild this menu, so HelpMenu reattaches it alongside
/// the resilient Help menu integration.
@MainActor
enum AboutMenu {
  static let itemIdentifier = NSUserInterfaceItemIdentifier("PasteClean.About")

  static func attach() {
    attach(to: resolveApplicationMenu(in: NSApplication.shared.mainMenu))
  }

  static func attach(to menu: NSMenu?) {
    guard let menu else { return }

    let item: NSMenuItem
    if let existing = menu.items.first(where: { $0.identifier == itemIdentifier })
      ?? menu.items.first(where: {
        $0.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:))
      })
    {
      item = existing
    } else {
      item = NSMenuItem(
        title: String(localized: "About PasteClean"),
        action: #selector(AboutWindowController.showAbout(_:)),
        keyEquivalent: ""
      )
      menu.insertItem(item, at: 0)
    }

    item.identifier = itemIdentifier
    item.target = AboutWindowController.shared
    item.action = #selector(AboutWindowController.showAbout(_:))

    let duplicates = menu.items.filter {
      $0 !== item
        && ($0.identifier == itemIdentifier
          || $0.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:)))
    }
    for duplicate in duplicates {
      menu.removeItem(duplicate)
    }
  }

  static func resolveApplicationMenu(in mainMenu: NSMenu?) -> NSMenu? {
    let submenus = mainMenu?.items.compactMap(\.submenu) ?? []
    return submenus.first { submenu in
      submenu.items.contains {
        $0.identifier == itemIdentifier
          || $0.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:))
      }
    } ?? submenus.first
  }
}

//
//  GuideView.swift
//  PasteClean
//
//  Created by 김승진 on 2026. 8. 19.
//

import SwiftUI

/// Which guide is open.
enum GuideTopic: String, Identifiable {
  /// Using the app itself — what most people need.
  case app
  /// The one-off setup for the Xcode source editor extension.
  case xcodeExtension

  var id: String { rawValue }

  var title: String {
    switch self {
    case .app: String(localized: "How to use PasteClean")
    case .xcodeExtension: String(localized: "Set up and use the Xcode extension")
    }
  }

  var stepTitles: [String] {
    switch self {
    case .app:
      [
        String(localized: "What it fixes"),
        String(localized: "Using the app"),
      ]
    case .xcodeExtension:
      [
        String(localized: "Enable the Xcode extension"),
        String(localized: "Use it in Xcode"),
      ]
    }
  }
}

/// Lets the Help menu and the window open the same sheets.
@MainActor final class GuideState: ObservableObject {
  /// Shared so the menu can reach it without a property wrapper, which stops
  /// SwiftUI from dropping the command group.
  static let shared = GuideState()

  @Published var topic: GuideTopic?

  private static let hasPresentedAppGuideKey = "hasPresentedAppGuide"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    topic = defaults.bool(forKey: Self.hasPresentedAppGuideKey) ? nil : .app
  }

  /// The automatic guide is onboarding, not a launch screen. Once it has
  /// actually appeared, future launches stay in the main window.
  func markAsPresented(_ topic: GuideTopic) {
    guard topic == .app else { return }
    defaults.set(true, forKey: Self.hasPresentedAppGuideKey)
  }
}

/// Shown as a sheet, one step at a time.
///
/// Each topic stays focused on its own workflow: app onboarding explains the
/// editor, while the Xcode guide covers extension setup and use.
struct GuideView: View {
  let topic: GuideTopic
  /// Opens another guide, or closes the sheet when passed `nil`.
  let open: (GuideTopic?) -> Void

  @State private var step = 0
  /// Which way the next transition should slide.
  @State private var isAdvancing = true
  private var lastStep: Int { topic.stepTitles.count - 1 }

  private func dismiss() { open(nil) }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 24) {
        header
        ZStack(alignment: .topLeading) {
          // Every step, laid out but never drawn, so the sheet stands as tall
          // as the tallest one and keeps that size while the reader moves
          // through them. Measuring beats hardcoding a height that silently
          // stops matching the moment a step gains a line.
          ForEach(0...lastStep, id: \.self) { index in
            content(index)
              .hidden()
              .accessibilityHidden(true)
          }
          content(step)
            .id(step)
            .transition(slide)
        }
      }
      .padding(32)
      .frame(maxWidth: .infinity, alignment: .leading)
      // The slide transition parks the outgoing step beside the incoming one.
      .clipped()
      Divider()
      footer
    }
    // Width is fixed so the text measure stays put; height follows whichever
    // step is showing, which is why the steps are kept short enough to fit.
    .frame(width: 820)
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: topic == .app ? "wand.and.sparkles" : "puzzlepiece.extension")
        .font(.system(size: 26))
        .foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 2) {
        Text(topic.stepTitles[step])
          .font(.system(size: 26, weight: .semibold))
          .id(step)
          .transition(.opacity)
        Text(topic.title)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button(action: dismiss) {
        Image(systemName: "xmark")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 34, height: 34)
          .background(.quaternary, in: .circle)
          .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.cancelAction)
      .help("Close")
    }
  }

  @ViewBuilder private func content(_ step: Int) -> some View {
    switch (topic, step) {
    case (.app, 0): preview
    case (.app, _): appUseStep
    case (.xcodeExtension, 0): enableStep
    default: extensionUseStep
    }
  }

  // MARK: - Steps

  private var preview: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        CodeBlock(title: "Before", code: Self.before)
        CodeBlock(title: "After", code: Self.after)
      }
      Text(
        "PasteClean removes extra blank lines and trailing whitespace, then matches your indentation."
      )
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var appUseStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      WindowSketch(before: Self.before, after: Self.after)
      Steps(items: [
        "Paste or edit code in Input. ⌘V pastes at the cursor; ⇧⌘V replaces all input and cleans it.",
        "Choose Clean or press ⌥O.",
        "Copy the result from Output.",
      ])
    }
  }

  private var enableStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      Button("Open Extension Settings", systemImage: "gearshape") {
        NSWorkspace.shared.open(
          URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
        )
      }
      .controlSize(.large)
      Text("If the page does not open directly, search System Settings for Extensions.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Steps(items: [
        "Choose Xcode Source Editor, then turn PasteClean on.",
        "Restart Xcode if it was already running.",
      ])
    }
  }

  private var extensionUseStep: some View {
    VStack(alignment: .leading, spacing: 16) {
      MenuPath(items: ["Editor", "PasteClean", "Clean Pasted Code"])
      Steps(items: [
        "Select code, or leave the selection empty to clean the whole file.",
        "Run this menu command. ⌘Z undoes the change.",
        "Indentation follows Xcode's settings.",
      ])
      Text(
        "A shortcut is optional. Search for Clean Pasted Code in Xcode Settings > Key Bindings to assign one."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Chrome

  private var footer: some View {
    ZStack {
      HStack(spacing: 7) {
        ForEach(0...lastStep, id: \.self) { index in
          Circle()
            .fill(index == step ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
            .frame(width: 7, height: 7)
        }
      }
      HStack(spacing: 12) {
        Spacer()
        Button("Back") { move(by: -1) }
          .opacity(step == 0 ? 0 : 1)
          .disabled(step == 0)
        Button(step == lastStep ? "Done" : "Next") {
          if step == lastStep { dismiss() } else { move(by: 1) }
        }
        .keyboardShortcut(.defaultAction)
        .controlSize(.large)
      }
    }
    .padding(16)
  }

  private func move(by delta: Int) {
    isAdvancing = delta > 0
    withAnimation(.easeInOut(duration: 0.22)) { step += delta }
  }

  /// Slides in from the direction of travel and out the opposite way.
  private var slide: AnyTransition {
    .asymmetric(
      insertion: .move(edge: isAdvancing ? .trailing : .leading).combined(with: .opacity),
      removal: .move(edge: isAdvancing ? .leading : .trailing).combined(with: .opacity)
    )
  }

  private static let before = """
    make.left.right.equalToSuperview().inset(22)

    // width: 1000 : height 313

    make.height.equalTo(bannerView.snp.width)

      .multipliedBy(313.0 / 1000.0)

    make.bottom.equalToSuperview().offset(-20)
    """

  private static let after = """
    make.left.right.equalToSuperview().inset(22)
    // width: 1000 : height 313
    make.height.equalTo(bannerView.snp.width)
      .multipliedBy(313.0 / 1000.0)
    make.bottom.equalToSuperview().offset(-20)
    """
}

/// A numbered list with an optional trailing control.
private struct Steps<Accessory: View>: View {
  let items: [LocalizedStringKey]
  @ViewBuilder var accessory: Accessory

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(index + 1)")
              .font(.footnote.weight(.bold))
              .foregroundStyle(.white)
              .frame(width: 20, height: 20)
              .background(.tint, in: .circle)
            Text(item)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      accessory
    }
  }
}

extension Steps where Accessory == EmptyView {
  init(items: [LocalizedStringKey]) {
    self.init(items: items) { EmptyView() }
  }
}

/// A drawing of the main window — deliberately not a screenshot.
///
/// It is built from the same localized strings the window itself uses, so it
/// reads correctly in every language the app is translated into and in both
/// appearances. A captured bitmap would only ever match the language it was
/// taken in, and would quietly go stale the next time the window changed.
private struct WindowSketch: View {
  let before: String
  let after: String

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        pane(title: "Input", code: before)
        Divider()
        pane(title: "Output", code: after)
      }
      Divider()
      HStack(spacing: 6) {
        button("Paste", "doc.on.clipboard", prominent: false)
        button("Clean", "wand.and.sparkles", prominent: true)
        Spacer(minLength: 0)
        Text(verbatim: "Indent Using")
          .foregroundStyle(.secondary)
        Text(verbatim: "Spaces")
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 4))
        Text(verbatim: "Widths")
          .foregroundStyle(.secondary)
        ForEach(["Tab", "Indent"], id: \.self) { caption in
          Text(verbatim: "\(caption)  4")
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 4))
        }
      }
      .font(.caption)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
    }
    .background(.background.secondary)
    .clipShape(.rect(cornerRadius: 8))
    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("The PasteClean window, with Input on the left and Output on the right.")
  }

  private func pane(title: LocalizedStringKey, code: String) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Text(title)
          .fontWeight(.semibold)
          .foregroundStyle(.secondary)
        Spacer(minLength: 0)
        Label("Copy", systemImage: "doc.on.doc")
          .foregroundStyle(.secondary)
      }
      .font(.caption2)
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      Divider()
      Text(code)
        .font(.system(size: 8, design: .monospaced))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
    }
    .frame(maxWidth: .infinity)
  }

  private func button(_ title: LocalizedStringKey, _ symbol: String, prominent: Bool) -> some View {
    Label(title, systemImage: symbol)
      .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(
        prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary.opacity(0.5)),
        in: .rect(cornerRadius: 4)
      )
  }
}

/// A menu path, drawn the way the menu bar reads it.
///
/// Plain `String`s: these are the names Xcode's own menu shows, which stay in
/// English whatever language PasteClean is running in.
private struct MenuPath: View {
  let items: [String]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        if index > 0 {
          Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        Text(item)
          .font(.callout.weight(index == items.count - 1 ? .semibold : .regular))
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
  }
}

/// A labelled, monospaced, non-editable snippet.
private struct CodeBlock: View {
  let title: LocalizedStringKey
  let code: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(code)
        .font(.system(size: 12, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
    }
  }
}

#Preview {
  GuideView(topic: .app) { _ in }
}

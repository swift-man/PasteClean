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
    case .xcodeExtension: String(localized: "Install and use the Xcode extension")
    }
  }

  var stepTitles: [String] {
    switch self {
    case .app: [String(localized: "Guide"), String(localized: "Guide")]
    case .xcodeExtension: [
      String(localized: "Enable the extension"),
      String(localized: "Assign a shortcut"),
      String(localized: "Use it in Xcode")
    ]
    }
  }
}

/// Lets the Help menu and the window open the same sheets.
@MainActor final class GuideState: ObservableObject {
  /// Shared so the menu can reach it without a property wrapper, which stops
  /// SwiftUI from dropping the command group.
  static let shared = GuideState()
  @Published var topic: GuideTopic? = .app
}

/// Shown as a sheet, one step at a time.
///
/// Step 1 shows what the cleaner does; the rest are the one-off setup for the
/// Xcode extension. Anything needed while actually working lives in the main
/// window instead, so it is visible without opening this.
struct GuideView: View {
  let topic: GuideTopic
  let dismiss: () -> Void

  @State private var step = 0
  /// Which way the next transition should slide.
  @State private var isAdvancing = true
  private var lastStep: Int { topic.stepTitles.count - 1 }

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header
          content
            .id(step)
            .transition(slide)
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .clipped()
      Divider()
      footer
    }
    .frame(width: 820, height: 620)
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
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 26, height: 26)
          .background(.quaternary, in: .circle)
          .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.cancelAction)
      .help("Close")
    }
  }

  @ViewBuilder private var content: some View {
    switch (topic, step) {
    case (.app, 0): preview
    case (.app, _): appUseStep
    case (.xcodeExtension, 0): enableStep
    case (.xcodeExtension, 1): shortcutStep
    default: extensionUseStep
    }
  }

  // MARK: - Steps

  private var preview: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Copying from a rendered Markdown code block leaves a blank line between every line, trailing whitespace at the ends, and indentation that does not match your project. This fixes all of it at once.")
        .fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .top, spacing: 12) {
        CodeBlock(title: "Before", code: Self.before)
        CodeBlock(title: "After", code: Self.after)
      }
    }
  }

  private var appUseStep: some View {
    Steps(items: [
      "Paste into Input on the left. ⌘V goes there no matter what has focus.",
      "Press ⌥O, or the Clean button, and the result appears in Output on the right.",
      "Take the result with the Copy button in the Output header.",
      "Hover any indentation control for an explanation of what it does."
    ])
  }

  private var enableStep: some View {
    Steps(items: [
      "Open System Settings ▸ General ▸ Login Items & Extensions.",
      "Select Xcode Source Editor.",
      "Turn PasteClean on.",
      "Restart Xcode if it was already running."
    ]) {
      Button("Open Extension Settings", systemImage: "gearshape") {
        NSWorkspace.shared.open(
          URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
        )
      }
      .controlSize(.large)
    }
  }

  private var shortcutStep: some View {
    Steps(items: [
      "Open Xcode ▸ Settings ▸ Shortcuts.",
      "Search for Clean Pasted Code.",
      "Type a shortcut. ⌥O is recommended."
    ])
  }

  private var extensionUseStep: some View {
    Steps(items: [
      "Select the code you want to clean.",
      "Run Editor ▸ PasteClean ▸ Clean Pasted Code, or press ⌥O.",
      "With nothing selected it cleans the whole file. ⌘Z undoes it.",
      "Indentation follows Xcode's own settings, so there is nothing to configure."
    ])
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

    // 1000 : 313 비율

    make.height.equalTo(bannerView.snp.width)

      .multipliedBy(313.0 / 1000.0)

    make.bottom.equalToSuperview().offset(-20)
    """

  private static let after = """
    make.left.right.equalToSuperview().inset(22)
    // 1000 : 313 비율
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
  GuideView(topic: .app) {}
}

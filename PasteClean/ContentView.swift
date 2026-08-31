//
//  ContentView.swift
//  PasteClean
//
//  Created by 김승진 on 2026. 8. 19.
//

import SwiftUI

/// The main window: paste on the left, read the cleaned result on the right.
///
/// The Xcode extension is the primary way to use PasteClean, but the same
/// cleaner runs here so the app is useful without Xcode.
struct ContentView: View {
  @State private var input = ""
  @State private var output = ""
  @AppStorage("cleanerUsesTabs") private var usesTabs = false
  @AppStorage("cleanerIndentationWidth") private var indentationWidth = 4
  @AppStorage("cleanerTabWidth") private var tabWidth = 4
  @EnvironmentObject private var guide: GuideState
  @AppStorage("showsLineNumbers") private var showsLineNumbers = true
  @State private var status = ""

  var body: some View {
    VStack(spacing: 0) {
      xcodeExtensionBar
      Divider()
      HSplitView {
        pane(title: String(localized: "Input"), text: $input, placeholder: Self.inputPlaceholder)
        pane(title: String(localized: "Output"), text: $output, placeholder: Self.outputPlaceholder)
      }
      Divider()
      footer
    }
    .frame(minWidth: 980, minHeight: 480)
    .sheet(item: $guide.topic) { topic in
      // Identity follows the topic so switching guides mid-sheet starts the
      // new one at its first step instead of inheriting the old step number.
      GuideView(topic: topic) { guide.topic = $0 }
        .id(topic)
        .onAppear { guide.markAsPresented(topic) }
    }
  }

  /// Keep the optional Xcode entry discoverable without placing project and
  /// support information ahead of the editor itself.
  private var xcodeExtensionBar: some View {
    HStack(spacing: 10) {
      Label("Xcode Extension", systemImage: "puzzlepiece.extension")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Spacer(minLength: 12)
      Button("Set Up", systemImage: "gearshape") {
        guide.topic = .xcodeExtension
      }
      .buttonStyle(.bordered)
      .accessibilityLabel("Set Up Xcode Extension")
      .help("Enable PasteClean in System Settings for use in Xcode.")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
  }

  /// One titled editor with a copy button in its header and a placeholder.
  private func pane(
    title: String,
    text: Binding<String>,
    placeholder: String
  ) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          copy(text.wrappedValue, label: title)
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
        .buttonStyle(.borderless)
        .disabled(text.wrappedValue.isEmpty)
        .help("Copy \(title)")
      }
      .padding(.horizontal, 10)
      .frame(height: Self.headerHeight)
      Divider()
      ZStack(alignment: .topLeading) {
        if text.wrappedValue.isEmpty {
          // Line up with where CodeTextView actually draws: the gutter, then the
          // text container inset (4) plus the line fragment padding (5).
          Text(placeholder)
            .font(.system(size: CodeTextView.fontSize, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.leading, (showsLineNumbers ? Self.gutterWidth : 0) + 9)
            .padding(.top, 6)
            .allowsHitTesting(false)
        }
        CodeTextView(text: text, showsLineNumbers: showsLineNumbers)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(minWidth: 380)
  }

  /// Keep both editors equally tall. Input actions stay on the left and
  /// output settings on the right, outside the resizable editor panes.
  private var footer: some View {
    HStack(spacing: 12) {
      inputActions
        .fixedSize()
      Text(status)
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
        .help(status)
      indentationControls
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private var inputActions: some View {
    HStack(spacing: 12) {
      Button("Paste", systemImage: "doc.on.clipboard", action: pasteIntoInput)
        // Leave standard paste on the text editor's responder chain so partial
        // edits keep their selection and native undo history.
        .keyboardShortcut("v", modifiers: [.command, .shift])
        .buttonStyle(.bordered)
        .help("Replace Input with the clipboard and clean it (⇧⌘V).")
      Button("Clean", systemImage: "wand.and.sparkles", action: clean)
        .keyboardShortcut("o", modifiers: .option)
        .buttonStyle(.borderedProminent)
        .disabled(input.isEmpty)
    }
  }

  /// Output formatting controls laid out as a single inspector-style row.
  ///
  /// These labels stay in English because they mirror Xcode's names exactly.
  private var indentationControls: some View {
    HStack(spacing: 8) {
      settingLabel("Indent Using")
      Menu {
        Button {
          usesTabs = false
        } label: {
          if usesTabs {
            Text(verbatim: "Spaces")
          } else {
            Label {
              Text(verbatim: "Spaces")
            } icon: {
              Image(systemName: "checkmark")
            }
          }
        }
        Button {
          usesTabs = true
        } label: {
          if usesTabs {
            Label {
              Text(verbatim: "Tabs")
            } icon: {
              Image(systemName: "checkmark")
            }
          } else {
            Text(verbatim: "Tabs")
          }
        }
      } label: {
        Color.clear
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .buttonStyle(.plain)
      .frame(width: Self.indentationPickerWidth, height: 22)
      .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 6))
      .overlay {
        HStack(spacing: 6) {
          Text(verbatim: usesTabs ? "Tabs" : "Spaces")
          Spacer(minLength: 0)
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 9, weight: .semibold))
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .allowsHitTesting(false)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color.secondary.opacity(0.10))
      }
      .contentShape(.rect)
      .accessibilityLabel(Text(verbatim: "Indent Using"))
      .accessibilityValue(Text(verbatim: usesTabs ? "Tabs" : "Spaces"))
      .help("Choose spaces or tabs for Output indentation.")

      settingLabel("Widths")
        .padding(.leading, 4)
      widthField(
        "Tab",
        value: $tabWidth,
        help: String(localized: "Number of columns represented by one tab.")
      )
      widthField(
        "Indent",
        value: $indentationWidth,
        help: String(localized: "Number of columns in one indentation level.")
      )
    }
    .controlSize(.small)
    .fixedSize()
  }

  private func settingLabel(_ title: String) -> some View {
    Text(verbatim: title)
      .font(.system(size: 13, weight: .medium))
  }

  private func widthField(_ caption: String, value: Binding<Int>, help: String) -> some View {
    let supportedRange = IndentationStyle.supportedWidthRange
    let clampedValue = Binding(
      get: { value.wrappedValue },
      set: {
        value.wrappedValue = min(
          max($0, supportedRange.lowerBound),
          supportedRange.upperBound
        )
      }
    )
    return HStack(spacing: 4) {
      Text(verbatim: caption)
        .font(.system(size: 13, weight: .medium))
      TextField("", value: clampedValue, format: .number)
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .frame(width: 34)
        .accessibilityLabel(Text(verbatim: caption))
      Stepper(value: clampedValue, in: supportedRange) {
        Text(verbatim: caption)
      }
      .labelsHidden()
    }
    .help(help)
  }

  /// Writes the cleaned form of `input` into `output`.
  private func clean() {
    guard !input.isEmpty else {
      output = ""
      status = String(localized: "Paste the code you want to clean.")
      return
    }
    output = CodeCleaner.clean(
      text: input,
      style: IndentationStyle(
        usesTabs: usesTabs,
        indentationWidth: indentationWidth,
        tabWidth: tabWidth
      )
    )
    // A clean that changed something speaks for itself in the Output pane; the
    // line says something only when nothing happened.
    status = output == input ? String(localized: "Nothing to clean.") : ""
  }

  /// The Paste button and ⇧⌘V explicitly replace Input and clean it.
  private func pasteIntoInput() {
    guard let pasted = NSPasteboard.general.string(forType: .string) else {
      status = String(localized: "The clipboard has no text.")
      return
    }
    input = pasted
    clean()
  }

  private func copy(_ string: String, label: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
    status = String(localized: "Copied \(label) to the clipboard.")
  }

  /// A paste out of a rendered Markdown code block: a blank line after every line.
  private static let inputPlaceholder = """
    private lazy var stackView = UIStackView(

      arrangedSubviews: [],

      axis: .vertical,

      spacing: 0,

      alignment: .fill,

      distribution: .fill

    )
    """

  private static var outputPlaceholder: String {
    String(localized: "The cleaned code appears here.")
  }

  /// Matches `LineNumberRulerView.ruleThickness`.
  private static let gutterWidth: CGFloat = 38

  private static let indentationPickerWidth: CGFloat = 126

  /// Every pane header stands this tall so the rules and editor tops line up.
  private static let headerHeight: CGFloat = 36
}

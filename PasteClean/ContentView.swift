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
  @State private var usesTabs = false
  @State private var indentationWidth = 4
  @State private var tabWidth = 4
  @EnvironmentObject private var guide: GuideState
  @AppStorage("showsLineNumbers") private var showsLineNumbers = true
  @State private var status = ""

  var body: some View {
    VStack(spacing: 0) {
      usageBar
      Divider()
      HSplitView {
        pane(title: String(localized: "Input"), text: $input, placeholder: Self.inputPlaceholder)
        pane(title: String(localized: "Output"), text: $output, placeholder: Self.outputPlaceholder) {
          indentCharacterPicker
        }
      }
      Divider()
      toolbar
    }
    .frame(minWidth: 980, minHeight: 480)
    .sheet(item: $guide.topic) { topic in
      GuideView(topic: topic) { guide.topic = nil }
    }
  }

  /// Always-visible summary of the workflow, so the steps are never hidden
  /// behind a hover or a sheet.
  private var usageBar: some View {
    HStack(spacing: 10) {
      Image(systemName: "wand.and.sparkles")
        .foregroundStyle(.tint)
      Text("Paste ⌘V → Clean ⌥O → Copy from the right")
        .font(.callout.weight(.medium))
      Text("Removes blank lines and trailing whitespace, then rewrites indentation.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Spacer(minLength: 12)
      Button("Xcode Extension", systemImage: "puzzlepiece.extension") {
        guide.topic = .xcodeExtension
      }
      .buttonStyle(.borderless)
      .help("Install the extension to use this inside Xcode.")
      Button("Guide", systemImage: "questionmark.circle") { guide.topic = .app }
        .buttonStyle(.borderless)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  /// One titled editor with a copy button in its header and a placeholder.
  ///
  /// `controls` holds settings that describe this pane's own text — the
  /// indentation character lives above Output because that is what it rewrites.
  private func pane<Controls: View>(
    title: String,
    text: Binding<String>,
    placeholder: String,
    @ViewBuilder controls: () -> Controls = { EmptyView() }
  ) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        controls()
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
            .font(.system(size: 12, design: .monospaced))
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

  private var toolbar: some View {
    HStack(spacing: 12) {
      widths

      Text(status)
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button("Paste", systemImage: "doc.on.clipboard", action: pasteIntoInput)
        .keyboardShortcut("v", modifiers: .command)
      Button("Clean", systemImage: "wand.and.sparkles", action: clean)
        .keyboardShortcut("o", modifiers: .option)
        .buttonStyle(.borderedProminent)
        .disabled(input.isEmpty)
    }
    .padding(12)
  }

  /// Which character the cleaner writes indentation with.
  ///
  /// Only the app needs this control: inside Xcode the extension reads the
  /// editor's own setting, so the help text explains the choice on its own
  /// terms rather than naming a preference the reader may never have seen.
  private var indentCharacterPicker: some View {
    Picker("", selection: $usesTabs) {
      Text("Spaces").tag(false)
      Text("Tabs").tag(true)
    }
    .pickerStyle(.segmented)
    .frame(width: 130)
    .labelsHidden()
    .help("Whether the cleaned code is indented with spaces or with tab characters. Match whatever the file you are pasting into already uses — mixing the two is what makes indentation look ragged.")
  }

  /// Laid out like Xcode's own indentation widths control.
  private var widths: some View {
    HStack(spacing: 8) {
      Text("Widths")
        .foregroundStyle(.secondary)
      widthField(
        String(localized: "Tab"),
        value: $tabWidth,
        help: String(localized: "How many columns one tab counts as. Match the editor the code came from. This value measures tabs in the pasted code and, when Tabs is selected above, determines how many tabs and spaces are used to write the result.")
      )
      widthField(
        String(localized: "Indent"),
        value: $indentationWidth,
        help: String(localized: "How many columns one indentation level uses. Code pasted at 4 becomes 2 when this is 2.")
      )
    }
  }

  private func widthField(_ caption: String, value: Binding<Int>, help: String) -> some View {
    let clampedValue = Binding(
      get: { value.wrappedValue },
      set: { value.wrappedValue = min(max($0, 1), 16) }
    )
    return VStack(spacing: 2) {
      HStack(spacing: 2) {
        TextField("", value: clampedValue, format: .number)
          .textFieldStyle(.roundedBorder)
          .multilineTextAlignment(.trailing)
          .frame(width: 46)
        Stepper("", value: clampedValue, in: IndentationStyle.supportedWidthRange)
          .labelsHidden()
      }
      Text(caption)
        .font(.caption)
        .foregroundStyle(.secondary)
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
    let lines = Self.split(input)
    let cleaned = CodeCleaner.clean(
      lines: lines,
      style: IndentationStyle(
        usesTabs: usesTabs,
        indentationWidth: indentationWidth,
        tabWidth: tabWidth
      )
    )
    output = cleaned.joined(separator: "\n")
    let removed = lines.count - cleaned.count
    if removed > 0 {
      status = String(localized: "\(lines.count) lines → \(cleaned.count) lines, \(removed) blank removed")
    } else if output != input {
      status = String(localized: "Cleaned \(cleaned.count) lines.")
    } else {
      status = String(localized: "Nothing to clean.")
    }
  }

  /// ⌘V anywhere in the window drops the clipboard into the left pane and cleans it.
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

  /// Splits on any line ending, matching what the editor hands the extension.
  private static func split(_ string: String) -> [String] {
    string
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
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

  private static var outputPlaceholder: String { String(localized: "The cleaned code appears here.") }

  /// Matches `LineNumberRulerView.ruleThickness`.
  private static let gutterWidth: CGFloat = 38

  /// Every pane header stands this tall whatever controls it carries, so the
  /// rule beneath it — and with it the top of both editors — lines up across
  /// the split. Sized for the tallest control any header holds: Output's
  /// segmented picker, which is 24pt, plus 6pt of air above and below.
  private static let headerHeight: CGFloat = 36
}

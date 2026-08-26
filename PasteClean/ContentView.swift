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
      aboutBar
      Divider()
      usageBar
      Divider()
      HSplitView {
        pane(title: String(localized: "Input"), text: $input, placeholder: Self.inputPlaceholder)
        VStack(spacing: 0) {
          pane(title: String(localized: "Output"), text: $output, placeholder: Self.outputPlaceholder)
          Divider()
          HStack {
            indentationControls
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
        }
      }
      Divider()
      toolbar
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

  /// Project context and the public support path, kept at the very top of the
  /// main window so users can find it without opening another screen.
  private var aboutBar: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "info.circle.fill")
        .foregroundStyle(.secondary)
        .padding(.top, 1)
      VStack(alignment: .leading, spacing: 2) {
        Text("About PasteClean")
          .font(.subheadline.weight(.semibold))
        Text("The PasteClean editor and its Xcode extension are open source. For questions or bug reports, [open an issue on GitHub](https://github.com/swift-man/PasteClean).")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
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
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
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

  private var toolbar: some View {
    HStack(spacing: 12) {
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
      .background(Color.white.opacity(0.10), in: .rect(cornerRadius: 6))
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
          .strokeBorder(Color.white.opacity(0.04))
      }
      .contentShape(.rect)
      .accessibilityLabel(Text(verbatim: "Indent Using"))
      .accessibilityValue(Text(verbatim: usesTabs ? "Tabs" : "Spaces"))
      .help("Whether the cleaned code is indented with spaces or with tab characters. Match whatever the file you are pasting into already uses — mixing the two is what makes indentation look ragged.")

      settingLabel("Widths")
        .padding(.leading, 4)
      widthField(
        "Tab",
        value: $tabWidth,
        help: String(localized: "How many columns one tab counts as. Match the editor the code came from. This value measures tabs in the pasted code and, when Tabs is selected above, determines how many tabs and spaces are used to write the result.")
      )
      widthField(
        "Indent",
        value: $indentationWidth,
        help: String(localized: "How many columns one indentation level uses. Code pasted at 4 becomes 2 when this is 2.")
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
      Stepper("", value: clampedValue, in: supportedRange)
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
    let lines = CodeCleaner.splitLines(in: input)
    let cleaned = CodeCleaner.clean(
      lines: lines,
      style: IndentationStyle(
        usesTabs: usesTabs,
        indentationWidth: indentationWidth,
        tabWidth: tabWidth
      )
    )
    output = cleaned.joined(separator: "\n")
    // A clean that changed something speaks for itself in the Output pane; the
    // line says something only when nothing happened.
    status = output == input ? String(localized: "Nothing to clean.") : ""
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

  private static let indentationPickerWidth: CGFloat = 126

  /// Every pane header stands this tall so the rules and editor tops line up.
  private static let headerHeight: CGFloat = 36
}

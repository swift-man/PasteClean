//
//  CodeCleaner.swift
//  PasteCleanExtension
//
//  Created by 김승진 on 2026. 8. 19.
//

import Foundation

/// How the host editor wants indentation written.
struct IndentationStyle {
  static let supportedWidthRange = 1...16

  /// Whether tab characters are preferred over spaces.
  var usesTabs: Bool
  /// How many columns one level of indentation is worth.
  var indentationWidth: Int
  /// How many columns a tab character advances.
  var tabWidth: Int

  init(usesTabs: Bool, indentationWidth: Int, tabWidth: Int) {
    self.usesTabs = usesTabs
    self.indentationWidth = indentationWidth.clamped(to: Self.supportedWidthRange)
    self.tabWidth = tabWidth.clamped(to: Self.supportedWidthRange)
  }

  static let `default` = IndentationStyle(usesTabs: false, indentationWidth: 4, tabWidth: 4)
}

/// Tidies up code pasted in from a rendered Markdown code block.
///
/// The cleaner is intentionally not a formatter: it never reflows lines, never
/// re-derives nesting from braces, and never touches anything inside a
/// multi-line string literal. It only removes whitespace that the copy/paste
/// round trip added, and restates the indentation that is already there in the
/// editor's own units.
enum CodeCleaner {
  /// Longest run of blank lines the cleaner will leave behind.
  static let maximumConsecutiveBlankLines = 1

  /// Share of adjacent code-line pairs that must be separated by exactly one
  /// blank line before the text counts as "double spaced" by the assistant.
  private static let doubleSpacingThreshold = 0.6

  /// Cleans `lines` (which must not contain line terminators).
  ///
  /// - Parameters:
  ///   - lines: The lines to clean, without their line endings.
  ///   - style: Indentation style to write leading whitespace in.
  ///   - startsInsideMultilineString: Whether the first line is already inside
  ///     a `"""` literal. Use ``isInsideMultilineString(after:)`` to compute it
  ///     from the lines preceding the selection.
  static func clean(
    lines: [String],
    style: IndentationStyle,
    startsInsideMultilineString: Bool = false,
    startingMultilineStringHashCount: Int? = nil
  ) -> [String] {
    let classified = classify(
      lines,
      startingMultilineStringHashCount: startingMultilineStringHashCount
        ?? (startsInsideMultilineString ? 0 : nil)
    )
    let dropsSingleBlankLines = isDoubleSpaced(classified)
    let plan = IndentationPlan(for: classified, style: style)

    var result: [String] = []
    result.reserveCapacity(lines.count)
    var blankRun = 0

    func flushBlankRun() {
      guard blankRun > 0 else { return }
      let kept = dropsSingleBlankLines ? blankRun - 1 : blankRun
      result.append(contentsOf: repeatElement("", count: min(max(kept, 0), maximumConsecutiveBlankLines)))
      blankRun = 0
    }

    for line in classified {
      // String literal contents are code, not layout: leave them alone.
      if line.isInsideStringLiteral {
        flushBlankRun()
        result.append(line.text)
      } else if line.isBlank {
        blankRun += 1
      } else {
        flushBlankRun()
        result.append(reindenting(trimmingTrailingWhitespace(line.text), plan: plan, style: style))
      }
    }
    flushBlankRun()

    return result
  }

  /// Whether the line following `lines` sits inside a multi-line string literal.
  ///
  /// Pass the lines above the selection so a selection that starts in the
  /// middle of a `"""` literal is still recognised.
  static func isInsideMultilineString(after lines: [String]) -> Bool {
    multilineStringHashCount(after: lines) != nil
  }

  /// Hash count of the raw multi-line string containing the next line, or
  /// `nil` when the next line is ordinary code. A plain `"""` literal uses 0.
  static func multilineStringHashCount(after lines: [String]) -> Int? {
    lines.reduce(nil as Int?) { state, line in
      multilineStringHashCount(after: line, startingWith: state)
    }
  }

  // MARK: - Line classification

  private struct Line {
    var text: String
    var isInsideStringLiteral: Bool
    var isBlank: Bool
  }

  /// Marks which lines are string-literal contents rather than code.
  ///
  /// The line that opens a `"""` literal is code (only its tail is string), and
  /// the line that closes one is treated as string contents because its
  /// indentation defines how much whitespace Swift strips from the literal.
  private static func classify(
    _ lines: [String],
    startingMultilineStringHashCount: Int?
  ) -> [Line] {
    var hashCount = startingMultilineStringHashCount
    return lines.map { text in
      let wasInside = hashCount != nil
      hashCount = multilineStringHashCount(after: text, startingWith: hashCount)
      return Line(
        text: text,
        isInsideStringLiteral: wasInside,
        isBlank: text.trimmingCharacters(in: .whitespaces).isEmpty
      )
    }
  }

  /// Detects the "a blank line between every single line" pattern that chat
  /// assistants produce, as opposed to blank lines a human put there on purpose.
  private static func isDoubleSpaced(_ lines: [Line]) -> Bool {
    var gaps: [Int] = []
    var blankRun = 0
    var previousWasCode = false

    for line in lines {
      if line.isInsideStringLiteral {
        previousWasCode = false
        blankRun = 0
      } else if line.isBlank {
        blankRun += 1
      } else {
        if previousWasCode { gaps.append(blankRun) }
        blankRun = 0
        previousWasCode = true
      }
    }

    guard !gaps.isEmpty else { return false }
    let singleBlankGaps = gaps.filter { $0 == 1 }.count
    return Double(singleBlankGaps) >= doubleSpacingThreshold * Double(gaps.count)
  }

  // MARK: - Indentation

  /// Rescales the selection's indentation levels to the editor's indentation
  /// width.
  ///
  /// Only the steps *above* the selection's own shallowest line are rescaled:
  /// a selection is usually a fragment sitting at some nesting depth we cannot
  /// see, so its base indentation has to be left where it is. Anything that is
  /// not a whole number of steps — the alignment of a wrapped expression — is
  /// carried over unchanged, which keeps continuation lines lined up.
  private struct IndentationPlan {
    /// Indentation of the shallowest line, preserved as-is.
    var base = 0
    /// Columns per level in the pasted code, or `0` when it could not be
    /// determined confidently, in which case nothing is rescaled.
    var unit = 0

    init(for lines: [Line], style: IndentationStyle) {
      var widths: [Int] = []
      var structuralWidths: [Int] = []
      var previous: String?

      for line in lines where !line.isInsideStringLiteral && !line.isBlank {
        let (width, content) = measureIndent(line.text, tabWidth: style.tabWidth)
        let code = trimmingTrailingWhitespace(String(content))
        widths.append(width)
        if !isContinuation(code, after: previous) {
          structuralWidths.append(width)
        }
        previous = code
      }

      guard let base = widths.min() else { return }
      self.base = base

      // The smallest step is the unit, and every other step has to be a
      // whole multiple of it. Mixed indentation fails this test, and then
      // guessing would do more harm than leaving the code alone.
      let steps = Set(structuralWidths.map { $0 - base }).filter { $0 > 0 }
      guard let unit = steps.min(), steps.allSatisfy({ $0.isMultiple(of: unit) }) else { return }
      self.unit = unit
    }

    func targetWidth(for width: Int, indentationWidth: Int) -> Int {
      guard unit > 0, width > base else { return width }
      let step = width - base
      return base + (step / unit) * indentationWidth + (step % unit)
    }
  }

  /// Whether a line continues the previous statement rather than opening a new
  /// one. Such lines are aligned by hand, so they must not be mistaken for a
  /// level of nesting when measuring the indentation unit.
  private static func isContinuation(_ code: String, after previous: String?) -> Bool {
    if let first = code.first, ".?+-*/%&|=<>".contains(first) { return true }
    if let last = previous?.last, ",=+-*/%&|?([".contains(last) { return true }
    return false
  }

  private static func reindenting(
    _ line: String,
    plan: IndentationPlan,
    style: IndentationStyle
  ) -> String {
    let (width, content) = measureIndent(line, tabWidth: style.tabWidth)
    let target = plan.targetWidth(for: width, indentationWidth: style.indentationWidth)
    return indentation(width: target, style: style) + content
  }

  /// Splits a line into the visual column its text starts at, and that text.
  private static func measureIndent(_ line: String, tabWidth: Int) -> (width: Int, content: Substring) {
    var width = 0
    var index = line.startIndex

    loop: while index < line.endIndex {
      switch line[index] {
      case " ": width += 1
      case "\t": width += tabWidth - (width % tabWidth)
      default: break loop
      }
      index = line.index(after: index)
    }
    return (width, line[index...])
  }

  /// Writes `width` columns of indentation in the editor's preferred characters.
  ///
  /// Tabs cover as much as they can and spaces pad the rest, which is the rule
  /// Xcode itself documents for `usesTabsForIndentation`.
  private static func indentation(width: Int, style: IndentationStyle) -> String {
    guard width > 0 else { return "" }
    guard style.usesTabs else { return String(repeating: " ", count: width) }
    return String(repeating: "\t", count: width / style.tabWidth)
    + String(repeating: " ", count: width % style.tabWidth)
  }

  // MARK: - Whitespace

  private static func trimmingTrailingWhitespace(_ line: String) -> String {
    var trimmed = line
    while let last = trimmed.last, last == " " || last == "\t" {
      trimmed.removeLast()
    }
    return trimmed
  }

  /// Tracks Swift's plain and raw multi-line string delimiters through a line.
  /// Raw literals close only with the same number of hashes they opened with,
  /// so a bare `"""` inside `#""" ... """#` remains literal content.
  private static func multilineStringHashCount(
    after line: String,
    startingWith initialHashCount: Int?
  ) -> Int? {
    let characters = Array(line)
    var hashCount = initialHashCount
    var index = 0

    while index + 3 <= characters.count {
      guard characters[index] == "\"",
            characters[index + 1] == "\"",
            characters[index + 2] == "\""
      else {
        index += 1
        continue
      }

      if let expectedHashes = hashCount {
        let availableHashes = consecutiveHashes(in: characters, startingAt: index + 3)
        let isEscapedPlainDelimiter = expectedHashes == 0
          && hasOddBackslashRun(before: index, in: characters)
        if availableHashes >= expectedHashes && !isEscapedPlainDelimiter {
          hashCount = nil
          index += 3 + expectedHashes
        } else {
          index += 3
        }
      } else {
        let openingHashes = consecutiveHashes(before: index, in: characters)
        let isEscapedPlainDelimiter = openingHashes == 0
          && hasOddBackslashRun(before: index, in: characters)
        if !isEscapedPlainDelimiter {
          hashCount = openingHashes
        }
        index += 3
      }
    }
    return hashCount
  }

  private static func consecutiveHashes(in characters: [Character], startingAt index: Int) -> Int {
    guard index < characters.count else { return 0 }
    var cursor = index
    while cursor < characters.count, characters[cursor] == "#" { cursor += 1 }
    return cursor - index
  }

  private static func consecutiveHashes(before index: Int, in characters: [Character]) -> Int {
    guard index > 0 else { return 0 }
    var cursor = index
    while cursor > 0, characters[cursor - 1] == "#" { cursor -= 1 }
    return index - cursor
  }

  private static func hasOddBackslashRun(before index: Int, in characters: [Character]) -> Bool {
    guard index > 0 else { return false }
    var cursor = index
    while cursor > 0, characters[cursor - 1] == "\\" { cursor -= 1 }
    return (index - cursor).isMultiple(of: 2) == false
  }
}

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

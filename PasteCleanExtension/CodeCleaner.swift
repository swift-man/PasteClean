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
  struct LexicalState: Equatable {
    enum StringContext: Equatable {
      case multiline(hashCount: Int)
      case singleLine(hashCount: Int)
    }

    struct StringInterpolation: Equatable {
      var parent: StringContext
      var parenthesisDepth: Int
    }

    var multilineStringHashCount: Int?
    var multilineRegexHashCount: Int?
    var blockCommentDepth = 0
    var stringInterpolations: [StringInterpolation] = []
  }

  /// Advances lexical state through a file without rescanning an earlier prefix.
  ///
  /// Selection ranges are sorted before planning, so each subsequent checkpoint
  /// can continue from the previous one. `scannedLineCount` makes the linear-scan
  /// guarantee deterministic to test without relying on wall-clock timings.
  struct LexicalStateCursor {
    private var state = LexicalState(multilineStringHashCount: nil)
    private var nextLine = 0
    private(set) var scannedLineCount = 0

    mutating func state(before line: Int, in lines: [String]) -> LexicalState {
      precondition(line >= nextLine, "Lexical checkpoints must be requested in order")
      precondition(line <= lines.count, "Lexical checkpoint exceeds the buffer")
      state = CodeCleaner.lexicalState(
        after: lines[nextLine..<line],
        startingWith: state
      )
      scannedLineCount += line - nextLine
      nextLine = line
      return state
    }
  }

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
    startingMultilineStringHashCount: Int? = nil,
    startingLexicalState: LexicalState? = nil
  ) -> [String] {
    let initialState = startingLexicalState ?? LexicalState(
      multilineStringHashCount: startingMultilineStringHashCount
        ?? (startsInsideMultilineString ? 0 : nil)
    )
    let classified = classify(
      lines,
      startingLexicalState: initialState
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
  static func isInsideMultilineString<S: Sequence>(after lines: S) -> Bool where S.Element == String {
    multilineStringHashCount(after: lines) != nil
  }

  /// Hash count of the raw multi-line string containing the next line, or
  /// `nil` when the next line is ordinary code. A plain `"""` literal uses 0.
  static func multilineStringHashCount<S: Sequence>(after lines: S) -> Int? where S.Element == String {
    lexicalState(after: lines).multilineStringHashCount
  }

  static func lexicalState<S: Sequence>(after lines: S) -> LexicalState where S.Element == String {
    lexicalState(
      after: lines,
      startingWith: LexicalState(multilineStringHashCount: nil)
    )
  }

  static func lexicalState<S: Sequence>(
    after lines: S,
    startingWith initialState: LexicalState
  ) -> LexicalState where S.Element == String {
    lines.reduce(initialState) { state, line in
      lexicalScan(after: line, startingWith: state).state
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
    startingLexicalState: LexicalState
  ) -> [Line] {
    var state = startingLexicalState
    return lines.map { text in
      let scan = lexicalScan(after: text, startingWith: state)
      state = scan.state
      return Line(
        text: text,
        isInsideStringLiteral: scan.containsProtectedLiteralContent,
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
  private struct LexicalScan {
    var state: LexicalState
    var containsProtectedLiteralContent: Bool
  }

  private static func lexicalScan(
    after line: String,
    startingWith initialState: LexicalState
  ) -> LexicalScan {
    let characters = Array(line)
    var state = initialState
    var containsProtectedLiteralContent =
      initialState.multilineStringHashCount != nil
      || initialState.multilineRegexHashCount != nil
      || !initialState.stringInterpolations.isEmpty
    var singleLineStringHashCount: Int?
    var index = 0

    while index < characters.count {
      if let expectedHashes = state.multilineStringHashCount {
        containsProtectedLiteralContent = true
        if let interpolationLength = stringInterpolationOpeningLength(
          in: characters,
          at: index,
          hashCount: expectedHashes
        ) {
          state.stringInterpolations.append(
            LexicalState.StringInterpolation(
              parent: .multiline(hashCount: expectedHashes),
              parenthesisDepth: 1
            )
          )
          state.multilineStringHashCount = nil
          index += interpolationLength
          continue
        }

        guard hasTripleQuote(in: characters, at: index) else {
          index += 1
          continue
        }
        guard isFirstNonWhitespaceToken(in: characters, at: index) else {
          index += 3
          continue
        }
        let availableHashes = consecutiveHashes(in: characters, startingAt: index + 3)
        let isEscapedDelimiter = expectedHashes == 0
          ? hasOddBackslashRun(before: index, in: characters)
          : hasRawEscapePrefix(before: index, hashCount: expectedHashes, in: characters)
        if availableHashes >= expectedHashes && !isEscapedDelimiter {
          state.multilineStringHashCount = nil
          index += 3 + expectedHashes
        } else {
          index += 3
        }
        continue
      }

      if let expectedHashes = state.multilineRegexHashCount {
        containsProtectedLiteralContent = true
        guard characters[index] == "/" else {
          index += 1
          continue
        }
        let availableHashes = consecutiveHashes(in: characters, startingAt: index + 1)
        if availableHashes >= expectedHashes && !hasOddBackslashRun(before: index, in: characters) {
          state.multilineRegexHashCount = nil
          index += 1 + expectedHashes
        } else {
          index += 1
        }
        continue
      }

      if state.blockCommentDepth > 0 {
        if hasPair("/", "*", in: characters, at: index) {
          state.blockCommentDepth += 1
          index += 2
        } else if hasPair("*", "/", in: characters, at: index) {
          state.blockCommentDepth -= 1
          index += 2
        } else {
          index += 1
        }
        continue
      }

      if let expectedHashes = singleLineStringHashCount {
        if let interpolationLength = stringInterpolationOpeningLength(
          in: characters,
          at: index,
          hashCount: expectedHashes
        ) {
          state.stringInterpolations.append(
            LexicalState.StringInterpolation(
              parent: .singleLine(hashCount: expectedHashes),
              parenthesisDepth: 1
            )
          )
          singleLineStringHashCount = nil
          index += interpolationLength
          continue
        }

        guard characters[index] == "\"" else {
          index += 1
          continue
        }
        let availableHashes = consecutiveHashes(in: characters, startingAt: index + 1)
        let isEscapedQuote = expectedHashes == 0
          ? hasOddBackslashRun(before: index, in: characters)
          : hasRawEscapePrefix(before: index, hashCount: expectedHashes, in: characters)
        if availableHashes >= expectedHashes && !isEscapedQuote {
          singleLineStringHashCount = nil
          index += 1 + expectedHashes
        } else {
          index += 1
        }
        continue
      }

      let regexHashes = consecutiveHashes(in: characters, startingAt: index)
      if regexHashes > 0,
         index + regexHashes < characters.count,
         characters[index + regexHashes] == "/"
      {
        state.multilineRegexHashCount = regexHashes
        index += regexHashes + 1
        continue
      }

      if hasPair("/", "/", in: characters, at: index) {
        break
      }
      if hasPair("/", "*", in: characters, at: index) {
        state.blockCommentDepth = 1
        index += 2
        continue
      }

      if !state.stringInterpolations.isEmpty {
        if characters[index] == "(" {
          state.stringInterpolations[state.stringInterpolations.count - 1].parenthesisDepth += 1
          index += 1
          continue
        }
        if characters[index] == ")" {
          let contextIndex = state.stringInterpolations.count - 1
          state.stringInterpolations[contextIndex].parenthesisDepth -= 1
          if state.stringInterpolations[contextIndex].parenthesisDepth == 0 {
            let context = state.stringInterpolations.removeLast()
            switch context.parent {
            case .multiline(let hashCount):
              state.multilineStringHashCount = hashCount
            case .singleLine(let hashCount):
              singleLineStringHashCount = hashCount
            }
          }
          index += 1
          continue
        }
      }

      guard characters[index] == "\"" else {
        index += 1
        continue
      }

      let openingHashes = consecutiveHashes(before: index, in: characters)
      let isEscapedPlainQuote = openingHashes == 0
        && hasOddBackslashRun(before: index, in: characters)
      if isEscapedPlainQuote {
        index += 1
      } else if isMultilineOpeningDelimiter(in: characters, at: index) {
        state.multilineStringHashCount = openingHashes
        index = characters.count
      } else {
        singleLineStringHashCount = openingHashes
        index += 1
      }
    }
    return LexicalScan(
      state: state,
      containsProtectedLiteralContent: containsProtectedLiteralContent
    )
  }

  private static func hasTripleQuote(in characters: [Character], at index: Int) -> Bool {
    index + 2 < characters.count
      && characters[index] == "\""
      && characters[index + 1] == "\""
      && characters[index + 2] == "\""
  }

  private static func stringInterpolationOpeningLength(
    in characters: [Character],
    at index: Int,
    hashCount: Int
  ) -> Int? {
    guard characters[index] == "\\" else { return nil }
    let openingLength = hashCount + 2
    guard index + openingLength <= characters.count else { return nil }
    if hashCount == 0 {
      guard hasOddBackslashRun(through: index, in: characters) else { return nil }
    } else {
      guard characters[(index + 1)..<(index + 1 + hashCount)].allSatisfy({ $0 == "#" })
      else { return nil }
    }
    guard characters[index + 1 + hashCount] == "(" else { return nil }
    return openingLength
  }

  private static func isMultilineOpeningDelimiter(
    in characters: [Character],
    at index: Int
  ) -> Bool {
    guard hasTripleQuote(in: characters, at: index) else { return false }
    return characters[(index + 3)...].allSatisfy {
      $0 == " " || $0 == "\t" || $0.isNewline
    }
  }

  private static func isFirstNonWhitespaceToken(
    in characters: [Character],
    at index: Int
  ) -> Bool {
    characters[..<index].allSatisfy { $0 == " " || $0 == "\t" }
  }

  private static func hasPair(
    _ first: Character,
    _ second: Character,
    in characters: [Character],
    at index: Int
  ) -> Bool {
    index + 1 < characters.count
      && characters[index] == first
      && characters[index + 1] == second
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

  private static func hasOddBackslashRun(through index: Int, in characters: [Character]) -> Bool {
    var cursor = index + 1
    while cursor > 0, characters[cursor - 1] == "\\" { cursor -= 1 }
    return (index + 1 - cursor).isMultiple(of: 2) == false
  }

  private static func hasRawEscapePrefix(
    before index: Int,
    hashCount: Int,
    in characters: [Character]
  ) -> Bool {
    guard hashCount > 0, index > hashCount else { return false }
    let hashesStart = index - hashCount
    guard characters[hashesStart..<index].allSatisfy({ $0 == "#" }) else { return false }
    return characters[hashesStart - 1] == "\\"
  }
}

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

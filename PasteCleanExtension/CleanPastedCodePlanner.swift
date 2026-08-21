//
//  CleanPastedCodePlanner.swift
//  PasteCleanExtension
//
//  Created by 김승진 on 2026. 8. 21.
//

import Foundation

/// Editor-independent position used to make command behavior unit-testable.
struct EditorPosition: Equatable {
  var line: Int
  var column: Int
}

/// Editor-independent selection used to make command behavior unit-testable.
struct EditorRange: Equatable {
  var start: EditorPosition
  var end: EditorPosition

  var isEmpty: Bool { start == end }
}

/// Computes every edit and resulting selection before Xcode's buffer is changed.
///
/// Keeping this separate from `XCSourceEditorCommand` means the rules for line
/// endings, selection merging, and shifted ranges can be verified without an
/// Xcode host process.
struct CleanPastedCodePlan: Equatable {
  struct Edit: Equatable {
    var originalRange: Range<Int>
    var replacementLines: [String]
  }

  var edits: [Edit]
  var resultingSelections: [EditorRange]

  static func make(
    lines originalLines: [String],
    selections: [EditorRange],
    style: IndentationStyle
  ) -> Self? {
    guard !originalLines.isEmpty else { return nil }

    let target = target(for: selections, lineCount: originalLines.count)
    guard !target.ranges.isEmpty else { return nil }

    let contentLines = originalLines.map(strippingLineEnding)
    let defaultNewline = lineEnding(of: originalLines) ?? "\n"
    var lexicalStateCursor = CodeCleaner.LexicalStateCursor()
    let startingStates = target.ranges.map {
      lexicalStateCursor.state(before: $0.lowerBound, in: contentLines)
    }
    let cleanedTargets = zip(target.ranges, startingStates).map { range, startingState in
      (
        original: range,
        cleaned: CodeCleaner.clean(
          lines: Array(contentLines[range]),
          style: style,
          startingLexicalState: startingState
        )
      )
    }

    let edits = cleanedTargets.map { item in
      let selectedLines = Array(originalLines[item.original])
      let newline = lineEnding(of: selectedLines) ?? defaultNewline
      let finalLineHadEnding = selectedLines.last?.last?.isNewline == true
      let replacement = item.cleaned.enumerated().map { index, line in
        let isFinalReplacementLine = index == item.cleaned.count - 1
        return isFinalReplacementLine && !finalLineHadEnding ? line : line + newline
      }
      return Edit(originalRange: item.original, replacementLines: replacement)
    }

    let resultingSelections: [EditorRange]
    if target.isWholeBuffer {
      let cleanedLines = cleanedTargets[0].cleaned
      let carets = selections.isEmpty
        ? [EditorPosition(line: 0, column: 0)]
        : selections.map(\.start)
      resultingSelections = carets.map { caret in
        let position = mappedPosition(
          caret,
          originalLines: contentLines,
          cleanedLines: cleanedLines
        )
        return EditorRange(start: position, end: position)
      }
    } else {
      var precedingLineDelta = 0
      let mappedTargets = zip(cleanedTargets, edits).map { item, edit in
        defer { precedingLineDelta += edit.replacementLines.count - item.original.count }
        return (
          original: item.original,
          selection: selection(
            startingAt: item.original.lowerBound + precedingLineDelta,
            covering: item.cleaned
          )
        )
      }

      var emittedRanges: [Range<Int>] = []
      resultingSelections = selections.compactMap { originalSelection in
        if originalSelection.isEmpty {
          let position = mappedPosition(
            originalSelection.start,
            through: cleanedTargets,
            originalLines: contentLines
          )
          return EditorRange(start: position, end: position)
        }

        guard let range = lineRange(for: originalSelection, lineCount: originalLines.count),
              let mappedTarget = mappedTargets.first(where: {
                $0.original.lowerBound <= range.lowerBound
                  && range.upperBound <= $0.original.upperBound
              }),
              !emittedRanges.contains(mappedTarget.original)
        else { return nil }
        emittedRanges.append(mappedTarget.original)
        return mappedTarget.selection
      }
    }

    return Self(edits: edits, resultingSelections: resultingSelections)
  }

  // MARK: - Selection

  private struct Target {
    var ranges: [Range<Int>]
    var isWholeBuffer: Bool
  }

  private static func target(for selections: [EditorRange], lineCount: Int) -> Target {
    let nonEmpty = selections.filter { !$0.isEmpty }
    guard !nonEmpty.isEmpty else {
      return Target(ranges: [0..<lineCount], isWholeBuffer: true)
    }

    let ranges = nonEmpty.compactMap { lineRange(for: $0, lineCount: lineCount) }

    let merged = ranges.sorted { $0.lowerBound < $1.lowerBound }
      .reduce(into: [Range<Int>]()) { merged, range in
        if let last = merged.last, range.lowerBound <= last.upperBound {
          merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
        } else {
          merged.append(range)
        }
      }
    return Target(ranges: merged, isWholeBuffer: false)
  }

  private static func lineRange(
    for selection: EditorRange,
    lineCount: Int
  ) -> Range<Int>? {
    let start = max(0, selection.start.line)
    var end = selection.end.line
    if selection.end.column == 0 && end > start { end -= 1 }
    end = min(end, lineCount - 1)
    guard start <= end, start < lineCount else { return nil }
    return start..<(end + 1)
  }

  private static func selection(startingAt line: Int, covering lines: [String]) -> EditorRange {
    // Every non-empty source range produces at least one cleaned line: code is
    // retained, and an all-blank range is normalized to one blank line.
    let last = lines[lines.index(before: lines.endIndex)]
    return EditorRange(
      start: EditorPosition(line: line, column: 0),
      end: EditorPosition(line: line + lines.count - 1, column: last.utf16.count)
    )
  }

  /// Keeps a caret attached to the same logical line when blank lines before
  /// it are removed. Non-blank text is stable under cleaning after horizontal
  /// whitespace is ignored, so a single forward alignment identifies every
  /// retained source line without guessing from line-count deltas.
  private static func mappedPosition(
    _ position: EditorPosition,
    originalLines: [String],
    cleanedLines: [String]
  ) -> EditorPosition {
    guard !cleanedLines.isEmpty else { return EditorPosition(line: 0, column: 0) }

    let originalLine = min(max(position.line, 0), originalLines.count - 1)
    var mappings = Array<Int?>(repeating: nil, count: originalLines.count)
    var sourceIndex = 0
    var resultIndex = 0

    while sourceIndex < originalLines.count, resultIndex < cleanedLines.count {
      if comparableContent(originalLines[sourceIndex]) == comparableContent(cleanedLines[resultIndex]) {
        mappings[sourceIndex] = resultIndex
        sourceIndex += 1
        resultIndex += 1
      } else {
        sourceIndex += 1
      }
    }

    if let mappedLine = mappings[originalLine] {
      return EditorPosition(
        line: mappedLine,
        column: mappedColumn(
          position.column,
          from: originalLines[originalLine],
          to: cleanedLines[mappedLine]
        )
      )
    }

    if let nextLine = mappings[(originalLine + 1)...].compactMap({ $0 }).first {
      return EditorPosition(line: nextLine, column: 0)
    }
    let previousLine = mappings[..<originalLine].reversed().compactMap { $0 }.first
      ?? cleanedLines.count - 1
    return EditorPosition(
      line: previousLine,
      column: cleanedLines[previousLine].utf16.count
    )
  }

  /// Moves a caret through the selected edits while leaving unedited text in
  /// place. A caret inside an edit uses the same logical-line and indentation
  /// mapping as whole-buffer cleanup; a caret after it only receives its line
  /// count delta.
  private static func mappedPosition(
    _ position: EditorPosition,
    through cleanedTargets: [(original: Range<Int>, cleaned: [String])],
    originalLines: [String]
  ) -> EditorPosition {
    let originalLine = min(max(position.line, 0), originalLines.count - 1)
    var precedingLineDelta = 0

    for target in cleanedTargets {
      if originalLine < target.original.lowerBound { break }
      if originalLine >= target.original.upperBound {
        precedingLineDelta += target.cleaned.count - target.original.count
        continue
      }

      let localPosition = EditorPosition(
        line: originalLine - target.original.lowerBound,
        column: position.column
      )
      let mapped = mappedPosition(
        localPosition,
        originalLines: Array(originalLines[target.original]),
        cleanedLines: target.cleaned
      )
      return EditorPosition(
        line: target.original.lowerBound + precedingLineDelta + mapped.line,
        column: mapped.column
      )
    }

    return EditorPosition(
      line: originalLine + precedingLineDelta,
      column: min(max(position.column, 0), originalLines[originalLine].utf16.count)
    )
  }

  /// Keeps a caret attached to the same character in the code body when the
  /// cleaner rewrites leading whitespace. Columns inside indentation remain
  /// inside the rewritten indentation, and trailing-whitespace positions clamp
  /// to the cleaned line end.
  private static func mappedColumn(
    _ column: Int,
    from originalLine: String,
    to cleanedLine: String
  ) -> Int {
    let sourceColumn = min(max(column, 0), originalLine.utf16.count)
    let sourceIndent = leadingWhitespaceUTF16Count(originalLine)
    let cleanedIndent = leadingWhitespaceUTF16Count(cleanedLine)
    guard sourceColumn >= sourceIndent else { return min(sourceColumn, cleanedIndent) }
    return min(cleanedIndent + sourceColumn - sourceIndent, cleanedLine.utf16.count)
  }

  private static func leadingWhitespaceUTF16Count(_ line: String) -> Int {
    line.prefix { $0 == " " || $0 == "\t" }.utf16.count
  }

  private static func comparableContent(_ line: String) -> String {
    line.trimmingCharacters(in: .whitespaces)
  }

  // MARK: - Line endings

  private static func strippingLineEnding(_ line: String) -> String {
    guard let last = line.last, last.isNewline else { return line }
    return String(line.dropLast())
  }

  private static func lineEnding(of lines: [String]) -> String? {
    for line in lines {
      if line.hasSuffix("\r\n") { return "\r\n" }
      if line.hasSuffix("\n") { return "\n" }
      if line.hasSuffix("\r") { return "\r" }
    }
    return nil
  }
}

/// Minimal editor boundary shared by the XcodeKit adapter and integration tests.
protocol CleanPastedCodeBuffer: AnyObject {
  var lines: [String] { get }
  var selections: [EditorRange] { get }
  var indentationStyle: IndentationStyle { get }

  func replaceLines(in range: Range<Int>, with replacementLines: [String])
  func replaceSelections(with selections: [EditorRange])
}

/// Applies one cleaning transaction to an editor buffer.
enum CleanPastedCodeEditor {
  @discardableResult
  static func clean(_ buffer: any CleanPastedCodeBuffer) -> Bool {
    guard let plan = CleanPastedCodePlan.make(
      lines: buffer.lines,
      selections: buffer.selections,
      style: buffer.indentationStyle
    ) else { return false }

    // Later ranges first so earlier line indexes stay valid for the transaction.
    for edit in plan.edits.reversed() {
      buffer.replaceLines(in: edit.originalRange, with: edit.replacementLines)
    }
    buffer.replaceSelections(with: plan.resultingSelections)
    return true
  }
}

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

  /// Deterministic work counters used by performance regression tests.
  struct PerformanceMetrics: Equatable {
    fileprivate(set) var lexicalLinesScanned = 0
    fileprivate(set) var lineMappingBuildCount = 0
    fileprivate(set) var lineMappingSourceLineCount = 0
    fileprivate(set) var positionQueryCount = 0
    fileprivate(set) var selectionTargetAssignmentCount = 0
    fileprivate(set) var selectionResultLookupCount = 0
    fileprivate(set) var selectiveIndexLineCount = 0
  }

  var edits: [Edit]
  var resultingSelections: [EditorRange]

  static func make(
    lines originalLines: [String],
    selections: [EditorRange],
    style: IndentationStyle
  ) -> Self? {
    build(
      lines: originalLines,
      selections: selections,
      style: style,
      recorder: nil
    )
  }

  static func makeWithMetrics(
    lines originalLines: [String],
    selections: [EditorRange],
    style: IndentationStyle
  ) -> (plan: Self, metrics: PerformanceMetrics)? {
    let recorder = PerformanceRecorder()
    guard let plan = build(
      lines: originalLines,
      selections: selections,
      style: style,
      recorder: recorder
    ) else { return nil }
    return (plan, recorder.metrics)
  }

  private static func build(
    lines originalLines: [String],
    selections: [EditorRange],
    style: IndentationStyle,
    recorder: PerformanceRecorder?
  ) -> Self? {
    guard !originalLines.isEmpty else { return nil }

    let target = target(
      for: selections,
      lineCount: originalLines.count,
      recorder: recorder
    )
    guard !target.ranges.isEmpty else { return nil }

    let contentLines = originalLines.map(strippingLineEnding)
    let defaultNewline = lineEnding(of: originalLines) ?? "\n"
    var lexicalStateCursor = CodeCleaner.LexicalStateCursor()
    let startingStates = target.ranges.map {
      lexicalStateCursor.state(before: $0.lowerBound, in: contentLines)
    }
    recorder?.recordLexicalLines(scanned: lexicalStateCursor.scannedLineCount)
    let cleanedTargets = zip(target.ranges, startingStates).map { range, startingState in
      let selectedLines = Array(contentLines[range])
      let cleanedLines = CodeCleaner.clean(
        lines: selectedLines,
        style: style,
        startingLexicalState: startingState
      )
      return CleanedTarget(
        original: range,
        cleaned: cleanedLines,
        mapping: LineMapping(
          originalLines: selectedLines,
          cleanedLines: cleanedLines,
          recorder: recorder
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
      let mapping = cleanedTargets[0].mapping
      let carets = selections.isEmpty
        ? [EditorPosition(line: 0, column: 0)]
        : selections.map(\.start)
      resultingSelections = carets.map { caret in
        let position = mapping.position(for: caret)
        return EditorRange(start: position, end: position)
      }
    } else {
      var precedingLineDelta = 0
      var selectionByRange: [Range<Int>: EditorRange] = [:]
      selectionByRange.reserveCapacity(cleanedTargets.count)
      for (item, edit) in zip(cleanedTargets, edits) {
        defer { precedingLineDelta += edit.replacementLines.count - item.original.count }
        selectionByRange[item.original] = selection(
          startingAt: item.original.lowerBound + precedingLineDelta,
          covering: item.cleaned
        )
      }

      let positionMapping = selections.contains(where: \.isEmpty)
        ? SelectivePositionMapping(
          targets: cleanedTargets,
          originalLines: contentLines,
          recorder: recorder
        )
        : nil
      var emittedRanges = Set<Range<Int>>()
      resultingSelections = selections.enumerated().compactMap { index, originalSelection in
        recorder?.recordSelectionResultLookup()
        if originalSelection.isEmpty {
          guard let positionMapping else { return nil }
          let position = positionMapping.position(for: originalSelection.start)
          return EditorRange(start: position, end: position)
        }

        guard let range = target.rangeBySelectionIndex[index],
              let mappedSelection = selectionByRange[range],
              emittedRanges.insert(range).inserted
        else { return nil }
        return mappedSelection
      }
    }

    return Self(edits: edits, resultingSelections: resultingSelections)
  }

  // MARK: - Selection

  private struct Target {
    var ranges: [Range<Int>]
    var isWholeBuffer: Bool
    var rangeBySelectionIndex: [Range<Int>?]
  }

  private struct IndexedRange {
    var selectionIndex: Int
    var range: Range<Int>
  }

  private struct MergedRange {
    var range: Range<Int>
    var selectionIndices: [Int]
  }

  private static func target(
    for selections: [EditorRange],
    lineCount: Int,
    recorder: PerformanceRecorder?
  ) -> Target {
    guard selections.contains(where: { !$0.isEmpty }) else {
      return Target(
        ranges: [0..<lineCount],
        isWholeBuffer: true,
        rangeBySelectionIndex: Array(repeating: nil, count: selections.count)
      )
    }

    let indexedRanges = selections.enumerated().compactMap { index, selection -> IndexedRange? in
      guard !selection.isEmpty,
            let range = lineRange(for: selection, lineCount: lineCount)
      else { return nil }
      return IndexedRange(selectionIndex: index, range: range)
    }

    guard !indexedRanges.isEmpty else {
      return Target(
        ranges: [],
        isWholeBuffer: false,
        rangeBySelectionIndex: Array(repeating: nil, count: selections.count)
      )
    }

    let sortedRanges = indexedRanges.sorted {
      if $0.range.lowerBound == $1.range.lowerBound {
        return $0.range.upperBound < $1.range.upperBound
      }
      return $0.range.lowerBound < $1.range.lowerBound
    }
    var merged: [MergedRange] = []
    merged.reserveCapacity(sortedRanges.count)
    for item in sortedRanges {
      if let last = merged.last, item.range.lowerBound <= last.range.upperBound {
        merged[merged.count - 1].range = last.range.lowerBound..<max(
          last.range.upperBound,
          item.range.upperBound
        )
        merged[merged.count - 1].selectionIndices.append(item.selectionIndex)
      } else {
        merged.append(MergedRange(
          range: item.range,
          selectionIndices: [item.selectionIndex]
        ))
      }
    }

    var rangeBySelectionIndex = Array<Range<Int>?>(repeating: nil, count: selections.count)
    for item in merged {
      for selectionIndex in item.selectionIndices {
        rangeBySelectionIndex[selectionIndex] = item.range
        recorder?.recordSelectionTargetAssignment()
      }
    }
    return Target(
      ranges: merged.map(\.range),
      isWholeBuffer: false,
      rangeBySelectionIndex: rangeBySelectionIndex
    )
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

  /// A source-to-cleaned line alignment built once per edit and shared by every
  /// caret query. Nearest retained lines are precomputed so deleted blank-line
  /// carets also map in constant time.
  private struct LineMapping {
    private let originalLines: [String]
    private let cleanedLines: [String]
    private let mappedLineByOriginal: [Int?]
    private let nextMappedLine: [Int?]
    private let previousMappedLine: [Int?]
    private let recorder: PerformanceRecorder?

    init(
      originalLines: [String],
      cleanedLines: [String],
      recorder: PerformanceRecorder?
    ) {
      self.originalLines = originalLines
      self.cleanedLines = cleanedLines
      self.recorder = recorder

      var mappings = Array<Int?>(repeating: nil, count: originalLines.count)
      var sourceIndex = 0
      var resultIndex = 0
      while sourceIndex < originalLines.count, resultIndex < cleanedLines.count {
        if CleanPastedCodePlan.comparableContent(originalLines[sourceIndex])
          == CleanPastedCodePlan.comparableContent(cleanedLines[resultIndex]) {
          mappings[sourceIndex] = resultIndex
          resultIndex += 1
        }
        sourceIndex += 1
      }
      mappedLineByOriginal = mappings

      var nextMappings = Array<Int?>(repeating: nil, count: originalLines.count)
      var next: Int?
      for index in originalLines.indices.reversed() {
        nextMappings[index] = next
        if let mapped = mappings[index] { next = mapped }
      }
      nextMappedLine = nextMappings

      var previousMappings = Array<Int?>(repeating: nil, count: originalLines.count)
      var previous: Int?
      for index in originalLines.indices {
        previousMappings[index] = previous
        if let mapped = mappings[index] { previous = mapped }
      }
      previousMappedLine = previousMappings
      recorder?.recordLineMapping(sourceLineCount: originalLines.count)
    }

    func position(for position: EditorPosition) -> EditorPosition {
      recorder?.recordPositionQuery()
      guard !cleanedLines.isEmpty else { return EditorPosition(line: 0, column: 0) }

      let originalLine = min(max(position.line, 0), originalLines.count - 1)
      if let mappedLine = mappedLineByOriginal[originalLine] {
        return EditorPosition(
          line: mappedLine,
          column: CleanPastedCodePlan.mappedColumn(
            position.column,
            from: originalLines[originalLine],
            to: cleanedLines[mappedLine]
          )
        )
      }

      if let nextLine = nextMappedLine[originalLine] {
        return EditorPosition(line: nextLine, column: 0)
      }
      let previousLine = previousMappedLine[originalLine] ?? cleanedLines.count - 1
      return EditorPosition(
        line: previousLine,
        column: cleanedLines[previousLine].utf16.count
      )
    }
  }

  private struct CleanedTarget {
    var original: Range<Int>
    var cleaned: [String]
    var mapping: LineMapping
  }

  /// Indexes every original line once so mixed empty carets do not rescan the
  /// edit list. A query then performs only array lookups plus one shared mapping.
  private struct SelectivePositionMapping {
    private let targets: [CleanedTarget]
    private let originalLines: [String]
    private let targetIndexByLine: [Int?]
    private let precedingLineDeltaByLine: [Int]
    private let recorder: PerformanceRecorder?

    init(
      targets: [CleanedTarget],
      originalLines: [String],
      recorder: PerformanceRecorder?
    ) {
      self.targets = targets
      self.originalLines = originalLines
      self.recorder = recorder

      var targetIndexes = Array<Int?>(repeating: nil, count: originalLines.count)
      for (targetIndex, target) in targets.enumerated() {
        for line in target.original {
          targetIndexes[line] = targetIndex
        }
      }
      targetIndexByLine = targetIndexes

      var deltas = Array(repeating: 0, count: originalLines.count)
      var targetIndex = 0
      var precedingDelta = 0
      for line in originalLines.indices {
        while targetIndex < targets.count,
              targets[targetIndex].original.upperBound <= line {
          let target = targets[targetIndex]
          precedingDelta += target.cleaned.count - target.original.count
          targetIndex += 1
        }
        deltas[line] = precedingDelta
      }
      precedingLineDeltaByLine = deltas
      recorder?.recordSelectiveIndex(lineCount: originalLines.count)
    }

    func position(for position: EditorPosition) -> EditorPosition {
      let originalLine = min(max(position.line, 0), originalLines.count - 1)
      let precedingLineDelta = precedingLineDeltaByLine[originalLine]
      guard let targetIndex = targetIndexByLine[originalLine] else {
        recorder?.recordPositionQuery()
        return EditorPosition(
          line: originalLine + precedingLineDelta,
          column: min(max(position.column, 0), originalLines[originalLine].utf16.count)
        )
      }

      let target = targets[targetIndex]
      let mapped = target.mapping.position(for: EditorPosition(
        line: originalLine - target.original.lowerBound,
        column: position.column
      ))
      return EditorPosition(
        line: target.original.lowerBound + precedingLineDelta + mapped.line,
        column: mapped.column
      )
    }
  }

  private final class PerformanceRecorder {
    private(set) var metrics = PerformanceMetrics()

    func recordLexicalLines(scanned count: Int) {
      metrics.lexicalLinesScanned += count
    }

    func recordLineMapping(sourceLineCount: Int) {
      metrics.lineMappingBuildCount += 1
      metrics.lineMappingSourceLineCount += sourceLineCount
    }

    func recordPositionQuery() {
      metrics.positionQueryCount += 1
    }

    func recordSelectionTargetAssignment() {
      metrics.selectionTargetAssignmentCount += 1
    }

    func recordSelectionResultLookup() {
      metrics.selectionResultLookupCount += 1
    }

    func recordSelectiveIndex(lineCount: Int) {
      metrics.selectiveIndexLineCount += lineCount
    }
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

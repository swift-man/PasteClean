//
//  CleanPastedCodeCommand.swift
//  PasteCleanExtension
//
//  Created by 김승진 on 2026. 8. 19.
//

import Foundation
import XcodeKit

/// Tidies up the whitespace of the selected lines.
///
/// With nothing selected the command falls back to cleaning the whole file.
final class CleanPastedCodeCommand: NSObject, XCSourceEditorCommand {

  func perform(
    with invocation: XCSourceEditorCommandInvocation,
    completionHandler: @escaping (Error?) -> Void
  ) {
    let buffer = invocation.buffer
    let originalLines = buffer.lines.compactMap { $0 as? String }
    let style = IndentationStyle(
      usesTabs: buffer.usesTabsForIndentation,
      indentationWidth: buffer.indentationWidth,
      tabWidth: buffer.tabWidth
    )
    let originalSelections = buffer.selections.compactMap { $0 as? XCSourceTextRange }
    let selections = originalSelections.map {
      EditorRange(
        start: EditorPosition(line: $0.start.line, column: $0.start.column),
        end: EditorPosition(line: $0.end.line, column: $0.end.column)
      )
    }
    guard let plan = CleanPastedCodePlan.make(
      lines: originalLines,
      selections: selections,
      style: style
    ) else { return completionHandler(nil) }

    // Later ranges first: editing them leaves the line numbers of the
    // earlier ranges — and of everything the prefix scan looks at — intact.
    for edit in plan.edits.reversed() {
      buffer.lines.replaceObjects(
        in: NSRange(location: edit.originalRange.lowerBound, length: edit.originalRange.count),
        withObjectsFrom: edit.replacementLines
      )
    }

    buffer.selections.setArray(plan.resultingSelections.map {
      XCSourceTextRange(
        start: XCSourceTextPosition(line: $0.start.line, column: $0.start.column),
        end: XCSourceTextPosition(line: $0.end.line, column: $0.end.column)
      )
    })
    completionHandler(nil)
  }
}

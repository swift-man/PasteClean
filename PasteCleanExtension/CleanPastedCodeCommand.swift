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
    CleanPastedCodeEditor.clean(XcodeSourceBufferAdapter(buffer: invocation.buffer))
    completionHandler(nil)
  }
}

private final class XcodeSourceBufferAdapter: CleanPastedCodeBuffer {
  private let buffer: XCSourceTextBuffer

  init(buffer: XCSourceTextBuffer) {
    self.buffer = buffer
  }

  var lines: [String] {
    buffer.lines.compactMap { $0 as? String }
  }

  var selections: [EditorRange] {
    buffer.selections.compactMap { value in
      guard let range = value as? XCSourceTextRange else { return nil }
      return EditorRange(
        start: EditorPosition(line: range.start.line, column: range.start.column),
        end: EditorPosition(line: range.end.line, column: range.end.column)
      )
    }
  }

  var indentationStyle: IndentationStyle {
    IndentationStyle(
      usesTabs: buffer.usesTabsForIndentation,
      indentationWidth: buffer.indentationWidth,
      tabWidth: buffer.tabWidth
    )
  }

  func replaceLines(in range: Range<Int>, with replacementLines: [String]) {
    buffer.lines.replaceObjects(
      in: NSRange(location: range.lowerBound, length: range.count),
      withObjectsFrom: replacementLines
    )
  }

  func replaceSelections(with selections: [EditorRange]) {
    buffer.selections.setArray(selections.map {
      XCSourceTextRange(
        start: XCSourceTextPosition(line: $0.start.line, column: $0.start.column),
        end: XCSourceTextPosition(line: $0.end.line, column: $0.end.column)
      )
    })
  }
}

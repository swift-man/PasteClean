//
//  CleanPastedCodePlannerTests.swift
//  PasteCleanTests
//
//  Created by 김승진 on 2026. 8. 21.
//

import Testing

@Suite("Clean Pasted Code 편집 계획")
struct CleanPastedCodePlannerTests {

  @Test("빈 버퍼나 유효하지 않은 선택은 편집하지 않는다")
  func rejectsEmptyBufferAndInvalidSelection() {
    #expect(CleanPastedCodePlan.make(lines: [], selections: [], style: .default) == nil)

    let invalid = range(from: (9, 0), to: (10, 1))
    #expect(CleanPastedCodePlan.make(
      lines: ["let value = 1\n"],
      selections: [invalid],
      style: .default
    ) == nil)
  }

  @Test("커서만 있으면 전체 버퍼를 정리하고 마지막 줄의 개행 상태를 보존한다")
  func cleansWholeBufferAndPreservesUnterminatedFinalLine() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: ["let a = 1  \n", "\n", "let b = 2  "],
      selections: [range(from: (10, 0), to: (10, 0))],
      style: .default
    ))

    #expect(plan.edits == [
      CleanPastedCodePlan.Edit(
        originalRange: 0..<3,
        replacementLines: ["let a = 1\n", "let b = 2"]
      )
    ])
    #expect(plan.resultingSelections == [range(from: (1, 0), to: (1, 0))])
  }

  @Test("선택 배열이 비어 있어도 전체 버퍼를 정리하고 첫 줄에 커서를 둔다")
  func cleansWholeBufferWhenSelectionsAreMissing() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: ["let value = 1  "],
      selections: [],
      style: .default
    ))

    #expect(plan.edits.first?.replacementLines == ["let value = 1"])
    #expect(plan.resultingSelections == [range(from: (0, 0), to: (0, 0))])
  }

  @Test("column 0 끝과 버퍼 경계를 적용해 선택을 온전한 줄 범위로 만든다")
  func normalizesSelectionToWholeLines() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: ["a\n", "b\n", "c\n", "d\n"],
      selections: [
        range(from: (1, 1), to: (3, 0)),
        range(from: (99, 0), to: (100, 1)),
      ],
      style: .default
    ))

    #expect(plan.edits.map { $0.originalRange } == [1..<3])
    #expect(plan.resultingSelections == [range(from: (1, 0), to: (2, 1))])
  }

  @Test("선택 끝 열은 이모지와 결합 문자를 UTF-16 단위로 계산한다", arguments: ["🙂", "e\u{301}"])
  func usesUTF16ColumnsForResultSelection(_ value: String) throws {
    let line = "let value = \"\(value)\""
    let plan = try #require(CleanPastedCodePlan.make(
      lines: [line + "  \n"],
      selections: [range(from: (0, 0), to: (0, line.utf16.count + 2))],
      style: .default
    ))

    #expect(plan.resultingSelections == [
      range(from: (0, 0), to: (0, line.utf16.count))
    ])
  }

  @Test("전체 정리에서 커서 앞의 빈 줄 제거량을 반영한다")
  func mapsCaretsAcrossBlankRemoval() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: ["a\n", "\n", "b\n", "\n", "c\n", "d\n"],
      selections: [
        range(from: (2, 1), to: (2, 1)),
        range(from: (4, 1), to: (4, 1)),
      ],
      style: .default
    ))

    #expect(plan.resultingSelections == [
      range(from: (1, 1), to: (1, 1)),
      range(from: (2, 1), to: (2, 1)),
    ])
  }

  @Test("커서 뒤에서만 빈 줄이 제거되면 커서 위치를 유지한다")
  func doesNotShiftCaretForBlankRemovalAfterIt() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: ["a\n", "b\n", "c\n", "\n", "d\n", "\n", "e\n", "\n", "f\n"],
      selections: [range(from: (1, 1), to: (1, 1))],
      style: .default
    ))

    #expect(plan.resultingSelections == [range(from: (1, 1), to: (1, 1))])
  }

  @Test("범위 선택과 섞인 빈 커서는 편집 전후의 논리 위치를 유지한다")
  func preservesCaretsMixedWithRangeSelections() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: [
        "before\n",
        "let a = 1\n", "\n", "let b = 2\n",
        "middle\n",
        "let c = 3\n", "\n", "let d = 4\n",
        "after\n",
      ],
      selections: [
        range(from: (0, 3), to: (0, 3)),
        range(from: (1, 0), to: (3, 9)),
        range(from: (4, 2), to: (4, 2)),
        range(from: (5, 0), to: (7, 9)),
        range(from: (8, 2), to: (8, 2)),
      ],
      style: .default
    ))

    #expect(plan.resultingSelections == [
      range(from: (0, 3), to: (0, 3)),
      range(from: (1, 0), to: (2, 9)),
      range(from: (3, 2), to: (3, 2)),
      range(from: (4, 0), to: (5, 9)),
      range(from: (6, 2), to: (6, 2)),
    ])
  }

  @Test("선택 범위 안의 빈 커서도 들여쓰기 변환 뒤 같은 토큰을 가리킨다")
  func mapsCaretInsideRangeSelectionAcrossIndentationChange() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: [
        "func f() {\n",
        "    if ready {\n",
        "        value()\n",
        "    }\n",
        "}\n",
      ],
      selections: [
        range(from: (0, 0), to: (4, 1)),
        range(from: (2, 8), to: (2, 8)),
        range(from: (2, 10), to: (2, 10)),
      ],
      style: IndentationStyle(usesTabs: false, indentationWidth: 2, tabWidth: 4)
    ))

    #expect(plan.resultingSelections == [
      range(from: (0, 0), to: (4, 1)),
      range(from: (2, 4), to: (2, 4)),
      range(from: (2, 6), to: (2, 6)),
    ])
  }

  @Test("정리 중 삭제된 빈 줄의 커서는 다음 줄, 없으면 이전 줄로 이동한다")
  func mapsCaretsWhoseBlankLinesAreRemoved() throws {
    let nextLinePlan = try #require(CleanPastedCodePlan.make(
      lines: ["a\n", "\n", "\n", "b\n", "c\n"],
      selections: [
        range(from: (0, 0), to: (4, 1)),
        range(from: (2, 0), to: (2, 0)),
      ],
      style: .default
    ))
    #expect(nextLinePlan.resultingSelections == [
      range(from: (0, 0), to: (3, 1)),
      range(from: (2, 0), to: (2, 0)),
    ])

    let previousLinePlan = try #require(CleanPastedCodePlan.make(
      lines: ["a\n", "b\n", "\n", "\n"],
      selections: [
        range(from: (0, 0), to: (3, 1)),
        range(from: (3, 0), to: (3, 0)),
      ],
      style: .default
    ))
    #expect(previousLinePlan.resultingSelections == [
      range(from: (0, 0), to: (2, 0)),
      range(from: (2, 0), to: (2, 0)),
    ])
  }

  @Test("전체 정리의 커서는 스페이스 폭 변경과 탭 변환 뒤 같은 토큰을 가리킨다")
  func mapsWholeBufferCaretsAcrossIndentationChanges() throws {
    let spacesPlan = try #require(CleanPastedCodePlan.make(
      lines: [
        "func f() {\n",
        "    if ready {\n",
        "        value()\n",
        "    }\n",
        "}\n",
      ],
      selections: [
        range(from: (1, 4), to: (1, 4)),
        range(from: (2, 8), to: (2, 8)),
        range(from: (2, 10), to: (2, 10)),
      ],
      style: IndentationStyle(usesTabs: false, indentationWidth: 2, tabWidth: 4)
    ))
    #expect(spacesPlan.resultingSelections == [
      range(from: (1, 2), to: (1, 2)),
      range(from: (2, 4), to: (2, 4)),
      range(from: (2, 6), to: (2, 6)),
    ])

    let tabsPlan = try #require(CleanPastedCodePlan.make(
      lines: ["func f() {\n", "  value()\n", "}\n"],
      selections: [
        range(from: (1, 2), to: (1, 2)),
        range(from: (1, 4), to: (1, 4)),
      ],
      style: IndentationStyle(usesTabs: true, indentationWidth: 4, tabWidth: 4)
    ))
    #expect(tabsPlan.resultingSelections == [
      range(from: (1, 1), to: (1, 1)),
      range(from: (1, 3), to: (1, 3)),
    ])
  }

  @Test("겹치거나 맞닿은 선택은 합치고 떨어진 선택의 이동량을 보정한다")
  func mergesRangesAndShiftsLaterSelections() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: [
        "let a = 1\n", "\n", "let b = 2\n", "keep\n",
        "let c = 3\n", "\n", "let d = 4\n",
      ],
      selections: [
        range(from: (0, 0), to: (1, 1)),
        range(from: (2, 0), to: (2, 9)),
        range(from: (4, 0), to: (6, 9)),
      ],
      style: .default
    ))

    #expect(plan.edits.map { $0.originalRange } == [0..<3, 4..<7])
    #expect(plan.edits.map { $0.replacementLines } == [
      ["let a = 1\n", "let b = 2\n"],
      ["let c = 3\n", "let d = 4\n"],
    ])
    #expect(plan.resultingSelections == [
      range(from: (0, 0), to: (1, 9)),
      range(from: (3, 0), to: (4, 9)),
    ])
  }

  @Test("각 선택은 자신의 raw 여러 줄 문자열 상태를 이어받는다")
  func inheritsRawMultilineStateForEachSelection() throws {
    let literalLines = [
      "let template = #\"\"\"\n",
      "    \"\"\"   \n",
      "\n",
      "\n",
      "    value   \n",
      "    \"\"\"#\n",
    ]
    let plan = try #require(CleanPastedCodePlan.make(
      lines: literalLines,
      selections: [range(from: (1, 0), to: (5, 0))],
      style: .default
    ))

    #expect(plan.edits == [
      CleanPastedCodePlan.Edit(
        originalRange: 1..<5,
        replacementLines: Array(literalLines[1..<5])
      )
    ])
  }

  @Test("블록 주석 안에서 시작하는 선택은 이후 실제 문자열 상태를 정확히 잇는다")
  func inheritsBlockCommentStateForSelection() throws {
    let lines = [
      "/*\n",
      "    \"\"\"\n",
      "*/\n",
      "let payload = \"\"\"\n",
      "    keep   \n",
      "    \"\"\"\n",
    ]
    let plan = try #require(CleanPastedCodePlan.make(
      lines: lines,
      selections: [range(from: (2, 0), to: (5, 0))],
      style: .default
    ))

    #expect(plan.edits == [
      CleanPastedCodePlan.Edit(
        originalRange: 2..<5,
        replacementLines: Array(lines[2..<5])
      )
    ])
  }

  @Test("LF, CRLF, CR과 개행 없는 마지막 줄을 그대로 보존한다", arguments: ["\n", "\r\n", "\r", ""])
  func preservesLineEnding(_ ending: String) throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: ["let value = 1  " + ending],
      selections: [range(from: (0, 0), to: (0, 13))],
      style: .default
    ))

    #expect(plan.edits.first?.replacementLines == ["let value = 1" + ending])
  }

  @Test("서로 다른 줄바꿈을 쓰는 떨어진 선택은 각각의 형식을 유지한다")
  func preservesPerRangeMixedLineEndings() throws {
    let plan = try #require(CleanPastedCodePlan.make(
      lines: ["let a = 1  \n", "keep\r\n", "let b = 2  \r\n"],
      selections: [
        range(from: (0, 0), to: (0, 11)),
        range(from: (2, 0), to: (2, 11)),
      ],
      style: .default
    ))

    #expect(plan.edits.map { $0.replacementLines } == [
      ["let a = 1\n"],
      ["let b = 2\r\n"],
    ])
  }

  @Test("대형 파일의 여러 선택 prefix는 각 줄을 한 번만 전진 스캔한다")
  func scansLargeFilePrefixesOnce() {
    let lines = (0..<5_000).map { index in
      switch index % 20 {
      case 0: "let text = #\"\"\""
      case 19: "    \"\"\"#"
      default: "    value \(index)   "
      }
    }
    let checkpoints = Array(stride(from: 0, to: lines.count, by: 97))
    var cursor = CodeCleaner.LexicalStateCursor()

    for checkpoint in checkpoints {
      let actual = cursor.state(before: checkpoint, in: lines)
      let expected = CodeCleaner.lexicalState(after: lines[..<checkpoint])
      #expect(actual == expected)
    }

    #expect(cursor.scannedLineCount == checkpoints.last ?? 0)
  }

  @Test("전체 플래너의 다중 커서와 선택 매핑 작업량은 입력 크기에 선형이다")
  func keepsEndToEndPlanningWorkLinear() throws {
    let lineCount = 5_000
    let lines = (0..<lineCount).map { "let value\($0) = \($0)  \n" }
    let wholeBufferCarets = stride(from: 0, to: lineCount, by: 5).map {
      range(from: ($0, 4), to: ($0, 4))
    }

    let wholeBuffer = try #require(CleanPastedCodePlan.makeWithMetrics(
      lines: lines,
      selections: wholeBufferCarets,
      style: .default
    ))
    #expect(wholeBuffer.plan.resultingSelections.count == wholeBufferCarets.count)
    #expect(wholeBuffer.metrics.lexicalLinesScanned == 0)
    #expect(wholeBuffer.metrics.lineMappingBuildCount == 1)
    #expect(wholeBuffer.metrics.lineMappingSourceLineCount == lineCount)
    #expect(wholeBuffer.metrics.positionQueryCount == wholeBufferCarets.count)
    #expect(wholeBuffer.metrics.selectiveIndexLineCount == 0)

    var mixedSelections: [EditorRange] = []
    mixedSelections.reserveCapacity(lineCount / 5)
    for line in stride(from: 0, to: lineCount, by: 10) {
      mixedSelections.append(range(from: (line, 0), to: (line, 1)))
      mixedSelections.append(range(from: (line + 1, 4), to: (line + 1, 4)))
    }

    let selective = try #require(CleanPastedCodePlan.makeWithMetrics(
      lines: lines,
      selections: mixedSelections,
      style: .default
    ))
    let selectedRangeCount = mixedSelections.count / 2
    #expect(selective.plan.resultingSelections.count == mixedSelections.count)
    #expect(selective.metrics.lexicalLinesScanned == lineCount - 10)
    #expect(selective.metrics.lineMappingBuildCount == selectedRangeCount)
    #expect(selective.metrics.lineMappingSourceLineCount == selectedRangeCount)
    #expect(selective.metrics.positionQueryCount == selectedRangeCount)
    #expect(selective.metrics.selectionTargetAssignmentCount == selectedRangeCount)
    #expect(selective.metrics.selectionResultLookupCount == mixedSelections.count)
    #expect(selective.metrics.selectiveIndexLineCount == lineCount)
  }

  @Test("편집 버퍼 경계는 뒤 범위부터 적용하고 selection을 한 번 갱신한다")
  func appliesOneEditorBufferTransaction() {
    let buffer = InMemoryEditorBuffer(
      lines: [
        "let a = 1  \n", "\n", "let b = 2  \n", "keep\n",
        "let c = 3  \n", "\n", "let d = 4  \n",
      ],
      selections: [
        range(from: (0, 0), to: (2, 11)),
        range(from: (4, 0), to: (6, 11)),
      ],
      indentationStyle: .default
    )

    #expect(CleanPastedCodeEditor.clean(buffer))
    #expect(buffer.replacedRanges == [4..<7, 0..<3])
    #expect(buffer.lines == [
      "let a = 1\n", "let b = 2\n", "keep\n", "let c = 3\n", "let d = 4\n",
    ])
    #expect(buffer.selections == [
      range(from: (0, 0), to: (1, 9)),
      range(from: (3, 0), to: (4, 9)),
    ])
    #expect(buffer.selectionReplacementCount == 1)
  }

  @Test("편집 계획이 없으면 버퍼를 변경하지 않는다")
  func leavesInvalidEditorBufferUnchanged() {
    let invalidSelection = range(from: (9, 0), to: (10, 1))
    let buffer = InMemoryEditorBuffer(
      lines: ["let value = 1\n"],
      selections: [invalidSelection],
      indentationStyle: .default
    )

    #expect(!CleanPastedCodeEditor.clean(buffer))
    #expect(buffer.lines == ["let value = 1\n"])
    #expect(buffer.selections == [invalidSelection])
    #expect(buffer.replacedRanges.isEmpty)
    #expect(buffer.selectionReplacementCount == 0)
  }

  private func range(
    from start: (line: Int, column: Int),
    to end: (line: Int, column: Int)
  ) -> EditorRange {
    EditorRange(
      start: EditorPosition(line: start.line, column: start.column),
      end: EditorPosition(line: end.line, column: end.column)
    )
  }
}

private final class InMemoryEditorBuffer: CleanPastedCodeBuffer {
  var lines: [String]
  var selections: [EditorRange]
  let indentationStyle: IndentationStyle
  private(set) var replacedRanges: [Range<Int>] = []
  private(set) var selectionReplacementCount = 0

  init(
    lines: [String],
    selections: [EditorRange],
    indentationStyle: IndentationStyle
  ) {
    self.lines = lines
    self.selections = selections
    self.indentationStyle = indentationStyle
  }

  func replaceLines(in range: Range<Int>, with replacementLines: [String]) {
    replacedRanges.append(range)
    lines.replaceSubrange(range, with: replacementLines)
  }

  func replaceSelections(with selections: [EditorRange]) {
    selectionReplacementCount += 1
    self.selections = selections
  }
}

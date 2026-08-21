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

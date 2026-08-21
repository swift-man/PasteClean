//
//  CodeCleanerTests.swift
//  PasteCleanTests
//
//  Created by 김승진 on 2026. 8. 19.
//

import Testing

/// `CodeCleaner`는 XcodeKit에 의존하지 않으므로 소스를 테스트 타깃에 직접
/// 컴파일해 호스트 앱 없이 검증합니다.
@Suite("CodeCleaner")
struct CodeCleanerTests {

  // MARK: - 빈 줄

  @Suite("빈 줄")
  struct BlankLines {

    @Test("한 줄 걸러 빈 줄이 들어가면 빈 줄 1개는 지운다")
    func removesSingleBlankLinesWhenDoubleSpaced() {
      let result = CodeCleaner.clean(
        lines: [
          "let a = 1",
          "",
          "let b = 2",
          "",
          "let c = 3",
        ],
        style: .default
      )

      #expect(result == ["let a = 1", "let b = 2", "let c = 3"])
    }

    @Test("일반적인 코드에서는 의도한 빈 줄 1개를 남긴다")
    func keepsDeliberateBlankLineInNormalCode() {
      let result = CodeCleaner.clean(
        lines: [
          "let a = 1",
          "",
          "let b = 2",
          "let c = 3",
          "let d = 4",
        ],
        style: .default
      )

      #expect(result == ["let a = 1", "", "let b = 2", "let c = 3", "let d = 4"])
    }

    @Test("연속된 빈 줄은 1줄로 줄인다")
    func collapsesConsecutiveBlankLines() {
      let result = CodeCleaner.clean(
        lines: [
          "let a = 1",
          "",
          "",
          "",
          "let b = 2",
          "let c = 3",
          "let d = 4",
        ],
        style: .default
      )

      #expect(result == ["let a = 1", "", "let b = 2", "let c = 3", "let d = 4"])
      #expect(result.filter(\.isEmpty).count <= CodeCleaner.maximumConsecutiveBlankLines)
    }

    @Test("한 줄 걸러 빈 줄이 들어가도 문단 구분은 살아남는다")
    func keepsParagraphBreakWhileDoubleSpaced() {
      let result = CodeCleaner.clean(
        lines: [
          "let a = 1",
          "",
          "let b = 2",
          "",
          "let c = 3",
          "",
          "",
          "",
          "let d = 4",
        ],
        style: .default
      )

      #expect(result == ["let a = 1", "let b = 2", "let c = 3", "", "let d = 4"])
    }

    @Test("앞뒤에 붙은 빈 줄도 1줄까지만 남긴다")
    func collapsesLeadingAndTrailingBlankRuns() {
      let result = CodeCleaner.clean(
        lines: [
          "",
          "let a = 1",
          "let b = 2",
          "let c = 3",
          "",
          "",
        ],
        style: .default
      )

      #expect(result == ["", "let a = 1", "let b = 2", "let c = 3", ""])
    }

    @Test("공백만 있는 줄은 빈 줄로 취급한다")
    func treatsWhitespaceOnlyLineAsBlank() {
      let result = CodeCleaner.clean(
        lines: [
          "let a = 1",
          "    ",
          "let b = 2",
          "let c = 3",
          "let d = 4",
        ],
        style: .default
      )

      #expect(result == ["let a = 1", "", "let b = 2", "let c = 3", "let d = 4"])
    }

    @Test("빈 입력은 빈 결과가 된다")
    func emptyInput() {
      #expect(CodeCleaner.clean(lines: [], style: .default).isEmpty)
    }
  }

  // MARK: - 줄 끝 공백

  @Suite("줄 끝 공백")
  struct TrailingWhitespace {

    @Test("줄 끝의 스페이스와 탭을 지운다")
    func removesTrailingSpacesAndTabs() {
      let result = CodeCleaner.clean(
        lines: [
          "let title = \"Hello\"   ",
          "let subtitle = \"World\"\t",
          "let footnote = \"!\"  ",
        ],
        style: .default
      )

      #expect(result == ["let title = \"Hello\"", "let subtitle = \"World\"", "let footnote = \"!\""])
    }
  }

  // MARK: - 여러 줄 문자열 리터럴

  @Suite("여러 줄 문자열 리터럴")
  struct MultilineStringLiterals {

    @Test("리터럴 안쪽은 빈 줄도 줄 끝 공백도 건드리지 않는다")
    func leavesLiteralContentsAlone() {
      let result = CodeCleaner.clean(
        lines: [
          "let query = \"\"\"",
          "    SELECT *",
          "",
          "    FROM users   ",
          "    \"\"\"",
          "",
          "",
          "let after = 1",
        ],
        style: .default
      )

      #expect(result == [
        "let query = \"\"\"",
        "    SELECT *",
        "",
        "    FROM users   ",
        "    \"\"\"",
        "",
        "let after = 1",
      ])
    }

    @Test("리터럴 한가운데서 시작한 선택 영역은 그대로 둔다")
    func keepsFragmentThatStartsInsideLiteral() {
      let fragment = ["    SELECT *", "", "    FROM users"]

      let untouched = CodeCleaner.clean(
        lines: fragment,
        style: .default,
        startsInsideMultilineString: true
      )
      #expect(untouched == fragment)

      // 같은 줄이라도 리터럴 밖이라면 평범한 코드로 정리됩니다.
      let cleaned = CodeCleaner.clean(
        lines: fragment,
        style: .default,
        startsInsideMultilineString: false
      )
      #expect(cleaned == ["    SELECT *", "    FROM users"])
    }

    @Test("선택 영역 위쪽을 훑어 리터럴 안인지 판단한다")
    func detectsWhetherSelectionStartsInsideLiteral() {
      #expect(CodeCleaner.isInsideMultilineString(after: []) == false)
      #expect(CodeCleaner.isInsideMultilineString(after: ["let q = \"\"\""]))
      #expect(CodeCleaner.isInsideMultilineString(
        after: ["let q = \"\"\"", "  SELECT *", "  \"\"\""]
      ) == false)
    }

    @Test("백슬래시로 이스케이프한 구분자는 리터럴을 열지 않는다")
    func ignoresEscapedDelimiter() {
      // 원시 문자열의 실제 내용은 `let s = "\"""` 입니다.
      #expect(CodeCleaner.isInsideMultilineString(after: [#"let s = "\""""#]) == false)
    }

    @Test("raw 리터럴 안의 맨 따옴표 구분자는 닫힘으로 오인하지 않는다")
    func keepsBareDelimiterInsideRawLiteral() {
      let lines = [
        "let template = #\"\"\"",
        "    first",
        "    \"\"\"   ",
        "",
        "",
        "    last   ",
        "    \"\"\"#",
        "let after = 1   ",
      ]

      let result = CodeCleaner.clean(lines: lines, style: .default)

      #expect(result == [
        "let template = #\"\"\"",
        "    first",
        "    \"\"\"   ",
        "",
        "",
        "    last   ",
        "    \"\"\"#",
        "let after = 1",
      ])
      #expect(CodeCleaner.multilineStringHashCount(after: Array(lines.prefix(6))) == 1)
    }

    @Test("plain 이스케이프 닫힘과 두 개 hash raw 닫힘을 구분한다")
    func distinguishesEscapedAndMultiHashClosers() {
      let plain = [
        "let value = \"\"\"",
        "    \\\"\"\"   ",
        "",
        "    text   ",
        "    \"\"\"",
      ]
      #expect(CodeCleaner.clean(lines: plain, style: .default) == plain)

      let raw = [
        "let value = ##\"\"\"",
        "    \"\"\"#   ",
        "",
        "    text   ",
        "    \"\"\"##",
      ]
      #expect(CodeCleaner.clean(lines: raw, style: .default) == raw)
    }
  }

  // MARK: - 들여쓰기

  @Suite("들여쓰기")
  struct Indentation {

    @Test("중첩 단계를 편집기의 들여쓰기 폭으로 다시 쓴다", arguments: [2, 3, 4, 8])
    func rescalesNestingToConfiguredWidth(_ width: Int) {
      let result = CodeCleaner.clean(
        lines: [
          "func f() {",
          "    if x {",
          "        y()",
          "    }",
          "}",
        ],
        style: IndentationStyle(usesTabs: false, indentationWidth: width, tabWidth: 4)
      )

      let one = String(repeating: " ", count: width)
      let two = String(repeating: " ", count: width * 2)
      #expect(result == ["func f() {", one + "if x {", two + "y()", one + "}", "}"])
    }

    @Test("선택 영역의 기준 들여쓰기는 그대로 둔다")
    func keepsBaseIndentationOfSelection() {
      let result = CodeCleaner.clean(
        lines: [
          "        for item in items {",
          "            total += item",
          "        }",
        ],
        style: IndentationStyle(usesTabs: false, indentationWidth: 2, tabWidth: 4)
      )

      #expect(result == [
        "        for item in items {",
        "          total += item",
        "        }",
      ])
    }

    @Test("이어지는 줄의 정렬은 열 위치 그대로 유지한다")
    func keepsContinuationAlignment() {
      // README의 예시 그대로입니다.
      let result = CodeCleaner.clean(
        lines: [
          "make.left.right.equalToSuperview().inset(22)",
          "",
          "// 1000 : 313 비율",
          "",
          "make.height.equalTo(bannerView.snp.width)",
          "",
          "  .multipliedBy(313.0 / 1000.0)",
          "",
          "make.bottom.equalToSuperview().offset(-20)",
        ],
        style: .default
      )

      #expect(result == [
        "make.left.right.equalToSuperview().inset(22)",
        "// 1000 : 313 비율",
        "make.height.equalTo(bannerView.snp.width)",
        "  .multipliedBy(313.0 / 1000.0)",
        "make.bottom.equalToSuperview().offset(-20)",
      ])
    }

    @Test("앞 줄의 쉼표와 여는 괄호로 이어지는 정렬을 구조 들여쓰기로 세지 않는다")
    func detectsContinuationFromPreviousLineEnding() {
      let result = CodeCleaner.clean(
        lines: [
          "func f() {",
          "    call(",
          "          first,",
          "          second",
          "    )",
          "}",
        ],
        style: IndentationStyle(usesTabs: false, indentationWidth: 2, tabWidth: 4)
      )

      #expect(result == [
        "func f() {",
        "  call(",
        "      first,",
        "      second",
        "  )",
        "}",
      ])
    }

    @Test("단위를 확신할 수 없으면 들여쓰기를 손대지 않는다")
    func leavesMixedIndentationAlone() {
      let lines = [
        "func f() {",
        "    let a = 1",
        "      let b = 2",
        "}",
      ]

      let result = CodeCleaner.clean(
        lines: lines,
        style: IndentationStyle(usesTabs: false, indentationWidth: 2, tabWidth: 4)
      )

      #expect(result == lines)
    }

    @Test("탭을 쓰는 편집기에서는 탭으로 다시 쓴다")
    func writesTabsWhenEditorPrefersThem() {
      let result = CodeCleaner.clean(
        lines: [
          "func f() {",
          "  if x {",
          "    y()",
          "  }",
          "}",
        ],
        style: IndentationStyle(usesTabs: true, indentationWidth: 4, tabWidth: 4)
      )

      #expect(result == ["func f() {", "\tif x {", "\t\ty()", "\t}", "}"])
    }

    @Test("붙여넣은 탭은 탭 너비만큼의 열로 재어 스페이스로 바꾼다")
    func measuresPastedTabsWithTabWidth() {
      let result = CodeCleaner.clean(
        lines: [
          "func f() {",
          "\tif x {",
          "\t\ty()",
          "\t}",
          "}",
        ],
        style: IndentationStyle(usesTabs: false, indentationWidth: 4, tabWidth: 4)
      )

      #expect(result == ["func f() {", "    if x {", "        y()", "    }", "}"])
    }

    @Test("탭 너비의 배수가 아닌 들여쓰기는 탭 뒤에 스페이스로 채운다")
    func padsTabIndentationRemainderWithSpaces() {
      let result = CodeCleaner.clean(
        lines: ["func f() {", "  value()", "}"],
        style: IndentationStyle(usesTabs: true, indentationWidth: 6, tabWidth: 4)
      )

      #expect(result == ["func f() {", "\t  value()", "}"])
    }
  }

  // MARK: - IndentationStyle

  @Suite("IndentationStyle")
  struct Style {

    @Test("기본값은 스페이스 4칸이다")
    func defaultStyle() {
      #expect(IndentationStyle.default.usesTabs == false)
      #expect(IndentationStyle.default.indentationWidth == 4)
      #expect(IndentationStyle.default.tabWidth == 4)
    }

    @Test("지원 범위를 벗어난 폭은 1...16으로 제한한다", arguments: [-8, 0, 17, Int.max])
    func clampsUnsupportedWidths(_ width: Int) {
      let style = IndentationStyle(usesTabs: false, indentationWidth: width, tabWidth: width)

      let expected = min(max(width, 1), 16)
      #expect(style.indentationWidth == expected)
      #expect(style.tabWidth == expected)
    }
  }
}

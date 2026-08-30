//
//  BundledDocumentView.swift
//  PasteClean
//

import SwiftUI

enum BundledDocument: String, CaseIterable, Identifiable {
  case privacyPolicy
  case lesserGeneralPublicLicense
  case generalPublicLicense

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .privacyPolicy:
      "Privacy Policy"
    case .lesserGeneralPublicLicense:
      "GNU LGPL v3"
    case .generalPublicLicense:
      "GNU GPL v3"
    }
  }

  fileprivate var resource: (name: String, extension: String?) {
    switch self {
    case .privacyPolicy:
      ("PRIVACY", "md")
    case .lesserGeneralPublicLicense:
      ("LICENSE", nil)
    case .generalPublicLicense:
      ("COPYING", nil)
    }
  }
}

struct BundledDocumentView: View {
  let document: BundledDocument
  private let contents: String?

  init(
    document: BundledDocument,
    bundle: Bundle = .main,
    locale: Locale = .current
  ) {
    self.document = document
    let resource = document.resource
    let loadedContents = bundle.url(
      forResource: resource.name,
      withExtension: resource.extension
    ).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    if document == .privacyPolicy, let loadedContents {
      contents = MarkdownDocument.localizedPrivacyContents(
        loadedContents,
        languageCode: locale.language.languageCode?.identifier
      )
    } else {
      contents = loadedContents
    }
  }

  var body: some View {
    Group {
      if let contents {
        ScrollView {
          documentText(contents)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
      } else {
        ContentUnavailableView(
          "Document Unavailable",
          systemImage: "doc.badge.ellipsis",
          description: Text("PasteClean could not load this bundled document.")
        )
      }
    }
    .background(Color(nsColor: .textBackgroundColor))
  }

  @ViewBuilder
  private func documentText(_ contents: String) -> some View {
    if document == .privacyPolicy {
      MarkdownDocumentView(markdown: contents)
    } else {
      Text(verbatim: contents)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }
  }
}

struct MarkdownDocument {
  enum Block: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
  }

  static func blocks(from markdown: String) -> [Block] {
    let lines =
      markdown
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
    var blocks: [Block] = []
    var index = 0

    while index < lines.count {
      let line = lines[index].trimmingCharacters(in: .whitespaces)
      guard !line.isEmpty else {
        index += 1
        continue
      }

      if let heading = heading(from: line) {
        blocks.append(heading)
        index += 1
        continue
      }

      let isBullet = line.hasPrefix("- ")
      var parts = [String(line.dropFirst(isBullet ? 2 : 0))]
      index += 1
      while index < lines.count {
        let continuation = lines[index].trimmingCharacters(in: .whitespaces)
        guard !continuation.isEmpty,
          heading(from: continuation) == nil,
          !continuation.hasPrefix("- ")
        else { break }
        parts.append(continuation)
        index += 1
      }

      let text = parts.joined(separator: " ")
      blocks.append(isBullet ? .bullet(text) : .paragraph(text))
    }

    return blocks
  }

  static func localizedPrivacyContents(
    _ contents: String,
    languageCode: String?
  ) -> String {
    let englishMarker = "## English"
    let koreanMarker = "## 한국어"
    guard let englishRange = contents.range(of: englishMarker),
      let koreanRange = contents.range(of: koreanMarker)
    else { return contents }

    let sourceDateLine =
      contents
      .split(whereSeparator: \.isNewline)
      .map(String.init)
      .first { $0.hasPrefix("Effective date / 시행일:") }
    let usesKorean = languageCode?.lowercased().hasPrefix("ko") == true
    let dateLine = sourceDateLine.map {
      localizedDateLine(from: $0, usesKorean: usesKorean)
    }
    let section: Substring
    if usesKorean {
      section = contents[koreanRange.upperBound...]
    } else {
      section = contents[englishRange.upperBound..<koreanRange.lowerBound]
    }

    return [dateLine, String(section).trimmingCharacters(in: .whitespacesAndNewlines)]
      .compactMap { $0 }
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")
  }

  private static func localizedDateLine(
    from source: String,
    usesKorean: Bool
  ) -> String {
    let prefix = "Effective date / 시행일:"
    let dates =
      source
      .dropFirst(prefix.count)
      .trimmingCharacters(in: .whitespaces)
      .components(separatedBy: " / ")
    guard dates.count == 2 else { return source }
    return usesKorean
      ? "시행일: \(dates[1])"
      : "Effective date: \(dates[0])"
  }

  private static func heading(from line: String) -> Block? {
    let prefix = line.prefix { $0 == "#" }
    guard !prefix.isEmpty,
      prefix.count <= 3,
      line.dropFirst(prefix.count).first == " "
    else { return nil }
    return .heading(
      level: prefix.count,
      text: String(line.dropFirst(prefix.count + 1))
    )
  }
}

private struct MarkdownDocumentView: View {
  let markdown: String

  var body: some View {
    LazyVStack(alignment: .leading, spacing: 12) {
      ForEach(
        Array(MarkdownDocument.blocks(from: markdown).enumerated()),
        id: \.offset
      ) { _, block in
        switch block {
        case .heading(let level, let text):
          inlineText(text)
            .font(headingFont(level))
            .padding(.top, level == 1 ? 0 : 8)
        case .paragraph(let text):
          inlineText(text)
        case .bullet(let text):
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
            inlineText(text)
          }
          .padding(.leading, 4)
        }
      }
    }
    .textSelection(.enabled)
  }

  private func inlineText(_ markdown: String) -> Text {
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    guard
      let attributed = try? AttributedString(
        markdown: markdown,
        options: options
      )
    else { return Text(verbatim: markdown) }
    return Text(attributed)
  }

  private func headingFont(_ level: Int) -> Font {
    switch level {
    case 1: .title2.bold()
    case 2: .title3.bold()
    default: .headline
    }
  }
}

struct LicenseDocumentsView: View {
  @State private var selection = BundledDocument.lesserGeneralPublicLicense

  var body: some View {
    VStack(spacing: 0) {
      Picker("License Document", selection: $selection) {
        Text(BundledDocument.lesserGeneralPublicLicense.title)
          .tag(BundledDocument.lesserGeneralPublicLicense)
        Text(BundledDocument.generalPublicLicense.title)
          .tag(BundledDocument.generalPublicLicense)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal, 16)
      .padding(.top, 16)

      Text("LGPL v3 incorporates GPL v3; the GPL text is included for reference.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

      Divider()

      BundledDocumentView(document: selection)
        .id(selection)
    }
  }
}

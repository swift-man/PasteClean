//
//  CodeTextView.swift
//  PasteClean
//
//  Created by 김승진 on 2026. 8. 19.
//

import AppKit
import SwiftUI

/// A monospaced text view with an optional line-number gutter.
///
/// `TextEditor` cannot host a gutter that stays in step with scrolling, so the
/// editor is an `NSTextView` and the gutter an `NSRulerView` — the same pairing
/// AppKit uses for its own code editors.
struct CodeTextView: NSViewRepresentable {
  @Binding var text: String
  var showsLineNumbers: Bool

  func makeNSView(context: Context) -> NSScrollView {
    let textView = NSTextView()
    textView.delegate = context.coordinator
    textView.font = Self.font
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.allowsUndo = true
    textView.drawsBackground = false
    textView.textContainerInset = NSSize(width: 4, height: 6)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.containerSize = NSSize(
      width: 0,
      height: CGFloat.greatestFiniteMagnitude
    )

    let scrollView = NSScrollView()
    scrollView.documentView = textView
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder

    let ruler = LineNumberRulerView(textView: textView)
    scrollView.verticalRulerView = ruler
    scrollView.hasVerticalRuler = true
    scrollView.rulersVisible = showsLineNumbers

    context.coordinator.observe(textView: textView, scrollView: scrollView, ruler: ruler)
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    if textView.string != text {
      textView.string = text
      scrollView.verticalRulerView?.needsDisplay = true
    }
    if scrollView.rulersVisible != showsLineNumbers {
      scrollView.rulersVisible = showsLineNumbers
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

  static let fontSize: CGFloat = 12
  static let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

  final class Coordinator: NSObject, NSTextViewDelegate {
    private let text: Binding<String>
    private var observers: [NSObjectProtocol] = []

    init(text: Binding<String>) { self.text = text }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      text.wrappedValue = textView.string
      textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }

    /// Redraws the gutter whenever the text scrolls or the view resizes.
    func observe(textView: NSTextView, scrollView: NSScrollView, ruler: NSRulerView) {
      let clipView = scrollView.contentView
      clipView.postsBoundsChangedNotifications = true
      let center = NotificationCenter.default
      observers = [
        center.addObserver(forName: NSView.boundsDidChangeNotification, object: clipView, queue: .main) { _ in
          ruler.needsDisplay = true
        },
        center.addObserver(forName: NSView.frameDidChangeNotification, object: textView, queue: .main) { _ in
          ruler.needsDisplay = true
        }
      ]
      textView.postsFrameChangedNotifications = true
    }
  }
}

/// Draws one right-aligned number per line of the client text view.
final class LineNumberRulerView: NSRulerView {
  private let numberFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)

  init(textView: NSTextView) {
    super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
    clientView = textView
    ruleThickness = 38
  }

  required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func drawHashMarksAndLabels(in rect: NSRect) {
    guard let textView = clientView as? NSTextView,
          let layoutManager = textView.layoutManager,
          let container = textView.textContainer,
          let clipView = scrollView?.contentView
    else { return }

    let content = textView.string as NSString
    let visibleRect = clipView.bounds
    let inset = textView.textContainerInset.height
    let attributes: [NSAttributedString.Key: Any] = [
      .font: numberFont,
      .foregroundColor: NSColor.tertiaryLabelColor
    ]

    func draw(_ number: Int, in lineRect: NSRect) {
      let label = "\(number)" as NSString
      let size = label.size(withAttributes: attributes)
      let y = lineRect.minY + inset - visibleRect.minY + (lineRect.height - size.height) / 2
      label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: y), withAttributes: attributes)
    }

    // An empty document has no glyphs, so its only line lives in the extra
    // fragment; using a zero-height rect here would pin the number to the top.
    guard content.length > 0 else {
      draw(1, in: layoutManager.extraLineFragmentRect)
      return
    }

    let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
    let visible = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

    let firstVisibleCharacter = min(visible.location, content.length - 1)
    let firstParagraph = content.paragraphRange(
      for: NSRange(location: firstVisibleCharacter, length: 0)
    )
    var number = 1
    if firstParagraph.location > 0 {
      content.enumerateSubstrings(
        in: NSRange(location: 0, length: firstParagraph.location),
        options: [.byLines, .substringNotRequired]
      ) { _, _, _, _ in number += 1 }
    }

    var location = firstParagraph.location
    while location < content.length {
      let paragraph = content.paragraphRange(for: NSRange(location: location, length: 0))
      let glyphIndex = layoutManager.glyphIndexForCharacter(at: paragraph.location)
      draw(number, in: layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil))
      number += 1
      let next = NSMaxRange(paragraph)
      if next <= location { break }
      location = next
      if location > NSMaxRange(visible) { return }
    }

    // Any trailing line terminator leaves the caret on one more, empty line.
    if textView.string.last?.isNewline == true {
      draw(number, in: layoutManager.extraLineFragmentRect)
    }
  }
}

//
//  SourceEditorExtension.swift
//  PasteCleanExtension
//
//  Created by 김승진 on 2026. 8. 19.
//

import Foundation
import XcodeKit

/// Entry point of the source editor extension.
///
/// The commands are declared here rather than in `Info.plist`; Xcode reads this
/// property in preference to the plist definitions.
class SourceEditorExtension: NSObject, XCSourceEditorExtension {

  func extensionDidFinishLaunching() {
    NSLog("[PasteClean] extensionDidFinishLaunching")
  }

  var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
    [
      [
        .classNameKey: "PasteCleanExtension.CleanPastedCodeCommand",
        .identifierKey: "PasteCleanExtension.CleanPastedCodeCommand",
        .nameKey: "Clean Pasted Code"
      ]
    ]
  }
}

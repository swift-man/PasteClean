# PasteClean

PasteClean is both a standalone macOS code-cleaning editor and an Xcode source
editor extension. Both clean up code pasted from a rendered Markdown code
block — the blank line between every line, the trailing whitespace, and
indentation that doesn't match your project.

In the app, Output controls choose tabs or spaces and their widths. In Xcode,
indentation follows the editor's own settings. Both preserve continuation-line
alignment and multi-line string literals. The app cleans when you choose Paste
or Clean, and the extension runs only as an Editor menu command; neither changes
paste behavior in other apps or uses the Accessibility API.

## Install

1. Put `PasteClean.app` in `/Applications` and open it once.
2. Turn PasteClean on in System Settings ▸ General ▸ Login Items & Extensions ▸ Xcode Source Editor.
3. Restart Xcode.

## Use

Select the code and run **Editor ▸ PasteClean ▸ Clean Pasted Code**. No keyboard
shortcut is required for the menu to appear or work. Optionally assign one in
Xcode ▸ Settings ▸ Shortcuts — `⌥O` is recommended.

With nothing selected it cleans the whole file, and `⌘Z` undoes it. Multiple
selections are cleaned independently and remain selected.

The app works on its own too: paste or edit on the left, then choose **Clean**
(`⌥O`) and take the result from the right. `⌘V` pastes at the cursor or replaces
the selected text in the focused editor, with standard `⌘Z` undo. The **Paste**
button (`⇧⌘V`) replaces all of Input with the clipboard and cleans it at once.
Handy when the code isn't headed for Xcode. The output controls let you choose
spaces or tabs and set the tab and indentation widths; choose **Clean** to apply
changed settings. Output remains editable and is not overwritten just by
changing a setting. Toggle line numbers with `⇧⌘L`.

For a walkthrough, open **Help ▸ PasteClean Help**. Its three-step guide
shows what gets fixed, how to use the app, and then hands off directly to the
Xcode extension setup guide.

## Build

```bash
xcodebuild -project PasteClean.xcodeproj -scheme PasteClean -configuration Release build
```

Run the unit tests with:

```bash
xcodebuild -project PasteClean.xcodeproj -scheme PasteCleanTests -destination 'platform=macOS' test
```

The suite includes deterministic large-file work counters for end-to-end
multi-selection planning and an in-memory editor-buffer integration test that
verifies edit ordering and resulting selections. Xcode extension discovery and
the host's native undo UI still require a manual check inside Xcode.

For TestFlight and App Store distribution, archive the shared **PasteClean**
scheme, which builds the host app and its embedded extension. The extension
target must **Embed & Sign** `XcodeKit.framework`, not just link it. Check that
the archived and exported app contains
`Contents/PlugIns/PasteCleanExtension.appex/Contents/Frameworks/XcodeKit.framework`.
After installing the new TestFlight build, enable the extension, restart Xcode,
and verify the Editor menu command with a source file open and no shortcut set.

Localized in English and Korean.

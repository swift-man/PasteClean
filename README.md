# PasteClean

![Swift](https://img.shields.io/badge/Swift-white.svg?style=flat-square&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-001b87.svg?style=flat-square&logo=swift&logoColor=white)
[![Version: 1.0](https://img.shields.io/badge/Version-1.0-1177AA?style=flat-square)](VERSION.txt)
![Platform: macOS 14.0+](https://img.shields.io/badge/platform-macOS%2014.0%2B-yellow?style=flat-square)
![Xcode Source Editor Extension](https://img.shields.io/badge/Xcode-Source%20Editor%20Extension-1575F9?style=flat-square&logo=xcode&logoColor=white)
[![License: LGPL-3.0-or-later](https://img.shields.io/badge/license-LGPL--3.0--or--later-black?style=flat-square)](LICENSE)

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
2. In System Settings, search for Extensions if needed, choose Xcode Source
   Editor, and turn PasteClean on.
3. Restart Xcode.

## Use

Select the code and run **Editor ▸ PasteClean ▸ Clean Pasted Code**. No keyboard
shortcut is required for the menu to appear or work. Optionally assign one in
Xcode ▸ Settings ▸ Key Bindings — `⌥O` is recommended.

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

For a walkthrough, open **Help ▸ PasteClean Help**. The two-step app guide
shows what gets fixed and how to use the editor. Open **Help ▸ Set up and use
the Xcode extension** for its separate two-step setup and usage guide.

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

## Support

For app questions, bug reports, and feature suggestions, see
[PasteClean Support](SUPPORT.md). The support page provides the public contact
address and the information to include with a report.

## Privacy

PasteClean processes editor, clipboard, and Xcode content on your Mac. It has
no account, analytics, advertising, telemetry, or cloud sync, and it does not
collect or transmit that content. See the bilingual [Privacy Policy](PRIVACY.md)
for details.

## License

PasteClean, including the standalone macOS editor and Xcode Source Editor
Extension, is free software: you can redistribute it and/or modify it under
the terms of the GNU Lesser General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version (`LGPL-3.0-or-later`).

PasteClean is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE. See [LICENSE](LICENSE) for the LGPL v3 terms and
[COPYING](COPYING) for the GPL v3 terms incorporated by LGPL v3.

Third-party components, including Apple's `XcodeKit.framework`, remain subject
to their respective licenses; this license does not replace those terms.

Before submitting a release, use the [App Store release checklist](APP_STORE_RELEASE_CHECKLIST.md)
to verify the public policy and support URLs, App Privacy answers, bundled
license notices, metadata, and extension review steps.

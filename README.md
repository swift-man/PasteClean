# PasteClean

An Xcode source editor extension that cleans up code pasted from a rendered
Markdown code block — the blank line between every line, the trailing
whitespace, the indentation that doesn't match your project.

Indentation is rewritten using your project's own Xcode settings (tabs or
spaces, and the width), while continuation-line alignment and multi-line string
literals are left alone. Nothing intercepts ⌘V and no Accessibility API is
involved — it runs as an Editor menu command.

## Install

1. Put `PasteClean.app` in `/Applications` and open it once.
2. Turn PasteClean on in System Settings ▸ General ▸ Login Items & Extensions ▸ Xcode Source Editor.
3. Restart Xcode.

## Use

Select the code and run **Editor ▸ PasteClean ▸ Clean Pasted Code**. Assign a
shortcut in Xcode ▸ Settings ▸ Shortcuts — `⌥O` is recommended.

With nothing selected it cleans the whole file, and `⌘Z` undoes it.

The app works on its own too: paste on the left, take the cleaned result from
the right. Handy when the code isn't headed for Xcode.

## Build

```bash
xcodebuild -project PasteClean.xcodeproj -scheme PasteClean -configuration Release build
```

Localized in English and Korean.

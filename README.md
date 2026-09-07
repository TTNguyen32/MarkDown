# MarkDown

Scan a page of a book, get its key points filed into a mindmap of that book, and
export the whole thing as Obsidian-flavoured Markdown.

## The idea

1. Add a book (type a title, or scan the cover — metadata comes from Google Books).
2. **Scan the table of contents.** Claude turns it into the outline: parts →
   chapters → sections, each with a start page. This is the mindmap skeleton.
3. **Scan any page.** On-device OCR reads it, the app works out the printed page
   number, and Claude extracts 3–8 atomic points and files them under whichever
   outline node owns that page range. Each note keeps a `p. 47` back-reference.
4. Review / re-parent in the outline view; preview as a mindmap (markmap).
5. Export `.md` to the share sheet or straight into your Obsidian vault folder.

Extraction defaults to **summarised points**; flip a note to **verbatim** when you
want the exact wording (a definition, a quotable line).

## Requirements

- Xcode 16+, iOS 17 SDK (SwiftData + Observation). The checked-in `.xcodeproj`
  uses file-system-synchronized groups (Xcode 16), so new files under `Sources/`
  are picked up automatically — no project regeneration step.
- An Anthropic API key (Settings → paste key). This is the "solo / TestFlight"
  path — see `ARCHITECTURE.md` for the hosted-proxy plan before any public release.

## Build

```bash
cd MarkDown
./Scripts/fetch-vendor.sh      # downloads d3 + markmap into Resources/
open MarkDown.xcodeproj
```

Then set your **Team** on the target's Signing & Capabilities tab (or
`DEVELOPMENT_TEAM` in the target build settings). If you are not using iCloud
sync, remove `CODE_SIGN_ENTITLEMENTS` from the target build settings and delete
`Resources/MarkDown.entitlements`.

Command line: `xcodebuild -scheme MarkDown -destination 'generic/platform=iOS Simulator' build`.

## Layout

```
Sources/
  App/         app entry, SwiftData container (local / optional CloudKit)
  Models/      Book, OutlineNode (self-referential tree), Scan
  Services/
    LLM/       provider protocol, Anthropic HTTP impl, prompts, model list
    Scanning/  VisionKit doc scanner, Vision OCR, page-number detection
    Outline/   TOC import, page ingest, page-range placement
    Export/    Markdown / markmap serialisers
  Views/       Library, AddBook, BookDetail, OutlineTree, Mindmap, ScanFlow, Settings
Resources/     Info.plist, entitlements, markmap.html, d3/markmap *.min.js (gitignored)
```

The `.xcodeproj` is hand-written and small: two synchronized groups (`Sources`,
`Resources`) feeding one app target, plus Debug/Release configs and a shared
scheme. Adding a Swift file = just create it under `Sources/`.

## Status

Scaffold. The service layer (placement, export, prompts, provider) is real; the
views are functional but intentionally plain. See `ARCHITECTURE.md` for what is
deliberately deferred.

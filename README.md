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

- Xcode 15+, iOS 17 SDK (SwiftData + Observation).
- [XcodeGen](https://github.com/yonyz/XcodeGen) to generate the project:
  `brew install xcodegen`
- An Anthropic API key (Settings → paste key). This is the "solo / TestFlight"
  path — see `ARCHITECTURE.md` for the hosted-proxy plan before any public release.

## Build

```bash
cd MarkDown
./Scripts/fetch-vendor.sh      # downloads d3 + markmap into Resources/vendor/
xcodegen generate
open MarkDown.xcodeproj
```

Set `DEVELOPMENT_TEAM` in `project.yml` (or the target's Signing tab). If you are
not using iCloud sync, delete the `entitlements` block from `project.yml` and
`Resources/MarkDown.entitlements`.

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
Resources/     Info.plist, entitlements, markmap.html, vendor/ (gitignored)
```

## Status

Scaffold. The service layer (placement, export, prompts, provider) is real; the
views are functional but intentionally plain. See `ARCHITECTURE.md` for what is
deliberately deferred.

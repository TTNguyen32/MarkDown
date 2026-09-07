# Architecture

## Decisions locked in

| Area | Choice |
|---|---|
| LLM access | Pluggable `LLMProvider`. Ships with `AnthropicProvider` (direct HTTPS, user's key in Keychain). A `HostedProxyProvider` slots in later without touching call sites. |
| Mindmap render | `markmap` inside a `WKWebView`. Markdown in → interactive mindmap out; matches the Obsidian markmap plugin and gives SVG export nearly free. |
| Extraction | Summary bullets by default; per-note `isVerbatim` toggle for exact wording. |
| Persistence | SwiftData, local by default. `Settings → iCloud sync` switches the `ModelConfiguration` to `.private` CloudKit (needs app relaunch). Models are CloudKit-safe: every attribute has a default, every relationship is optional, no `.unique`. |

## Data model

`Book 1—* OutlineNode` and `Book 1—* Scan`.

`OutlineNode` is one self-referential tree (`parent` / `children`). `kind`
discriminates structural nodes (`part`, `chapter`, `section`) from `note` leaves.
A note carries `noteText`, `sourcePage`, `sourceScanID`, `isVerbatim`.
Structural nodes carry `startPage` / `endPage`.

Keeping notes in the same tree (rather than a separate `Note` entity) means the
outline view, drag-to-reparent, and the exporter all walk one structure.

## The page → outline placement

After TOC import, structural nodes have `startPage`. Sorting them by
`(startPage, depth-first order)` yields page **ranges**: a node owns
`[startPage, nextStructuralStartPage)`.

`PageIngestService.ingest(scan:)`:

1. **Page number** — `PageNumberDetector` scans OCR observations in the top and
   bottom ~12% margins for a bare number / `Page N` / roman numeral. Miss →
   `scan.detectedPage = nil`; the UI asks the user (or auto-increments from the
   last confirmed scan). `book.bodyPageOffset` maps "printed page 1" to a sheet.
2. **Target node** — `OutlinePlacement.node(for: page, in: book)` returns the
   deepest structural node whose range contains `page`.
3. **Extract** — `LLMProvider.complete` with the outline path as context + the
   OCR text (image fallback when OCR confidence is low). Returns
   `{ bullets: [{text, verbatim}], sectionHint }`.
4. **Insert** — bullets become `note` children of the target node. `sectionHint`
   ("this page begins section X") is surfaced as a suggestion to correct ranges,
   never auto-applied.

Everything runs off a queue (`Scan.status = queued/processing/done/failed`), so a
batch of scans taken offline drains when the network returns.

## LLM calls

Two prompts, both in `Prompts.swift`, both returning strict JSON (parsed
leniently — code-fence tolerant).

- **TOC parse**: image(s) → `[{title, level, startPage}]`.
- **Page extract**: outline-path text + page text → bullets + optional section
  hint. Runs at `output_config.effort = low`.

Default model is `claude-opus-5`; Settings exposes a picker (Opus 5 / Sonnet 5 /
Haiku 4.5) with a per-scan cost note, since the user pays for their own key.
Direct-from-device calls are fine for solo/TestFlight; for App Store, put a proxy
in front (holds the key, adds auth + a credit/subscription meter) and register it
as another `LLMProvider`.

## Deliberately deferred

- Obsidian Canvas (`.canvas` JSON) export.
- Direct vault write via security-scoped bookmark (MVP = share sheet + document picker).
- Conflict UI for CloudKit (SwiftData's last-writer-wins is acceptable at first).
- OCR-confidence-driven automatic image fallback (MVP: manual "re-run with photo").
- Spaced-review / flashcard mode.

## Known sharp edges

- **Book gutter distortion** wrecks OCR near the spine. VisionKit's perspective
  correction helps; onboarding should tell users to flatten the book.
- **Page-number detection** is heuristic. The "confirm page" tap removes the risk
  for v1; sequential auto-increment is the fallback.
- **Copyright** — verbatim capture is opt-in and length-capped in the prompt to
  keep extraction transformative.

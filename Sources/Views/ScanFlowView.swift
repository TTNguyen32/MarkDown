import SwiftUI
import SwiftData

struct ScanFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let book: Book
    let mode: ScanKind
    var onFinish: (String?) -> Void

    @State private var phase: Phase = .scanning
    @State private var pages: [UIImage] = []
    @State private var working = false
    @State private var error: String?

    // page-mode state
    @State private var stagedScans: [Scan] = []
    @State private var cursor = 0
    @State private var pageField = ""

    enum Phase { case scanning, confirmPage, processing, summary }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(mode == .toc ? "Scan Contents" : "Scan Page")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { onFinish(nil); dismiss() }
                    }
                }
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .scanning:
            DocumentScannerView(
                onComplete: { imgs in
                    pages = imgs
                    Task { await handleCaptured() }
                },
                onCancel: { dismiss() }
            )
            .ignoresSafeArea()

        case .confirmPage:
            confirmPageForm

        case .processing:
            VStack(spacing: 12) {
                ProgressView()
                Text("Reading the page and placing it…").foregroundStyle(.secondary)
            }

        case .summary:
            summaryView
        }
    }

    // MARK: TOC

    private func handleCaptured() async {
        guard !pages.isEmpty else { dismiss(); return }
        if mode == .toc {
            phase = .processing
            do {
                let svc = TOCImportService(provider: LLMProviderFactory.current(), context: context)
                try await svc.importTOC(images: pages, into: book)
                onFinish("Outline imported: \(book.rootStructuralNodes.count) top-level entries.")
                dismiss()
            } catch {
                self.error = describe(error)
                phase = .summary
            }
        } else {
            // Stage every captured page, then confirm numbers one by one.
            let svc = PageIngestService(provider: LLMProviderFactory.current(), context: context)
            var previous = (book.scans ?? [])
                .filter { $0.kind == .page }
                .sorted { $0.createdAt < $1.createdAt }
                .last
            do {
                for img in pages {
                    let scan = try await svc.stage(image: img, in: book, autoIncrementFrom: previous)
                    stagedScans.append(scan)
                    previous = scan
                }
                cursor = 0
                loadPageField()
                phase = .confirmPage
            } catch {
                self.error = describe(error)
                phase = .summary
            }
        }
    }

    // MARK: Page confirm

    private var confirmPageForm: some View {
        let scan = stagedScans[cursor]
        return Form {
            Section {
                if let data = scan.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 240)
                }
            }
            Section("Printed page number") {
                TextField("e.g. 47", text: $pageField)
                    .keyboardType(.numberPad)
                if scan.detectedPage != nil {
                    Text("Detected automatically — correct it if wrong.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let target = previewTarget {
                    Text("Will file under: \(target.breadcrumb)")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            Section {
                Button(cursor == stagedScans.count - 1 ? "Extract" : "Next page") {
                    commitPageAndAdvance()
                }
            }
        }
    }

    private var previewTarget: OutlineNode? {
        Int(pageField).flatMap { OutlinePlacement.node(for: $0, in: book) }
    }

    private func loadPageField() {
        pageField = stagedScans[cursor].effectivePage.map(String.init) ?? ""
    }

    private func commitPageAndAdvance() {
        stagedScans[cursor].confirmedPage = Int(pageField)
        try? context.save()
        if cursor < stagedScans.count - 1 {
            cursor += 1
            loadPageField()
        } else {
            Task { await processStaged() }
        }
    }

    private func processStaged() async {
        phase = .processing
        let svc = PageIngestService(provider: LLMProviderFactory.current(), context: context)
        var added = 0
        var failures = 0
        for scan in stagedScans {
            do {
                let outcome = try await svc.process(scan)
                added += outcome.addedNotes.count
            } catch {
                failures += 1
                self.error = describe(error)
            }
        }
        onFinish("Added \(added) notes\(failures > 0 ? " · \(failures) page(s) failed" : "").")
        if failures == 0 { dismiss() } else { phase = .summary }
    }

    // MARK: Summary / error

    private var summaryView: some View {
        VStack(spacing: 16) {
            Image(systemName: error == nil ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(error == nil ? .green : .orange)
            if let error {
                Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            Button("Done") { onFinish(error); dismiss() }
        }
        .padding()
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }
}

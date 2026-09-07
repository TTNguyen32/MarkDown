import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var book: Book

    @State private var scanMode: ScanKind?
    @State private var showMindmap = false
    @State private var exportURL: ExportDoc?
    @State private var banner: String?

    private var hasOutline: Bool { !book.rootStructuralNodes.isEmpty }

    var body: some View {
        List {
            if let banner {
                Section {
                    Text(banner).font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    scanMode = .toc
                } label: {
                    Label(hasOutline ? "Re-scan contents page" : "Scan contents page",
                          systemImage: "list.bullet.rectangle")
                }
                Button {
                    scanMode = .page
                } label: {
                    Label("Scan a page", systemImage: "doc.text.viewfinder")
                }
                .disabled(!hasOutline)
            } footer: {
                if !hasOutline {
                    Text("Scan the table of contents first — it becomes the mindmap skeleton.")
                }
            }

            if hasOutline {
                Section("Outline") {
                    OutlineTreeView(book: book)
                }
            }
        }
        .navigationTitle(book.title.isEmpty ? "Untitled" : book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showMindmap = true } label: { Image(systemName: "circle.hexagongrid") }
                    .disabled(!hasOutline)
                Menu {
                    Button("Obsidian Markdown") { export(.obsidian) }
                    Button("markmap Markdown") { export(.markmap) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(!hasOutline)
            }
        }
        .fullScreenCover(item: $scanMode) { mode in
            ScanFlowView(book: book, mode: mode) { message in
                banner = message
            }
        }
        .sheet(isPresented: $showMindmap) {
            NavigationStack {
                MindmapWebView(markdown: MarkdownExporter.export(book, style: .markmap))
                    .navigationTitle("Mindmap")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $exportURL) { doc in
            ShareSheet(items: [doc.url])
        }
    }

    private func export(_ style: MarkdownExporter.Style) {
        let text = MarkdownExporter.export(book, style: style)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(MarkdownExporter.fileName(for: book))
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            exportURL = ExportDoc(url: url)
        } catch {
            banner = "Export failed: \(error.localizedDescription)"
        }
    }
}

extension ScanKind: Identifiable { var id: String { rawValue } }

private struct ExportDoc: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

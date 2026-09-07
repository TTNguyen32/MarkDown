import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [BookMetadata] = []
    @State private var searching = false
    @State private var manualTitle = ""
    @State private var manualAuthor = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    HStack {
                        TextField("Title or author", text: $query)
                            .onSubmit(runSearch)
                        Button("Go", action: runSearch).disabled(query.isEmpty)
                    }
                    if searching { ProgressView() }
                    ForEach(Array(results.enumerated()), id: \.offset) { _, meta in
                        Button { add(from: meta) } label: {
                            VStack(alignment: .leading) {
                                Text(meta.title).font(.body)
                                if !meta.author.isEmpty {
                                    Text(meta.author).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Or add manually") {
                    TextField("Title", text: $manualTitle)
                    TextField("Author", text: $manualAuthor)
                    Button("Add book") {
                        let book = Book(title: manualTitle, author: manualAuthor)
                        insert(book)
                    }
                    .disabled(manualTitle.isEmpty)
                }
            }
            .navigationTitle("Add Book")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func runSearch() {
        guard !query.isEmpty else { return }
        searching = true
        Task {
            defer { searching = false }
            results = (try? await BookMetadataService.search(query)) ?? []
        }
    }

    private func add(from meta: BookMetadata) {
        let book = Book(title: meta.title, author: meta.author)
        book.isbn = meta.isbn
        book.coverURLString = meta.coverURL
        book.pageCount = meta.pageCount ?? 0
        insert(book)
    }

    private func insert(_ book: Book) {
        context.insert(book)
        try? context.save()
        dismiss()
    }
}

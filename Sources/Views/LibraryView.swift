import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    @State private var showAddBook = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "No books yet",
                        systemImage: "books.vertical",
                        description: Text("Add a book, then scan its contents page to start the mindmap.")
                    )
                } else {
                    List {
                        ForEach(books) { book in
                            NavigationLink(value: book) {
                                BookRow(book: book)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("MarkDown")
            .navigationDestination(for: Book.self) { BookDetailView(book: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddBook = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddBook) { AddBookView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for i in offsets { context.delete(books[i]) }
        try? context.save()
    }
}

private struct BookRow: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(book.title.isEmpty ? "Untitled" : book.title).font(.headline)
            if !book.author.isEmpty {
                Text(book.author).font(.subheadline).foregroundStyle(.secondary)
            }
            Text("\(structuralCount) sections · \(noteCount) notes")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private var structuralCount: Int {
        (book.nodes ?? []).filter { $0.kind.isStructural }.count
    }
    private var noteCount: Int {
        (book.nodes ?? []).filter { $0.kind == .note }.count
    }
}

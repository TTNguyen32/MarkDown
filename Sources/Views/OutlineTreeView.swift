import SwiftUI
import SwiftData

/// Collapsible outline. Editing happens here: rename, delete, flip a note to
/// verbatim, re-parent via the context menu. (Drag-to-reparent is a later pass.)
struct OutlineTreeView: View {
    @Environment(\.modelContext) private var context
    let book: Book

    var body: some View {
        ForEach(book.rootStructuralNodes) { node in
            NodeDisclosure(node: node)
        }
    }
}

private struct NodeDisclosure: View {
    @Environment(\.modelContext) private var context
    @Bindable var node: OutlineNode
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(node.noteChildren) { note in
                NoteRow(note: note)
            }
            ForEach(node.structuralChildren) { child in
                NodeDisclosure(node: child)
            }
        } label: {
            HStack {
                Text(node.title).font(.subheadline.weight(.semibold))
                Spacer()
                if let p = node.startPage {
                    Text("p.\(p)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .contextMenu {
            Button("Rename") { rename() }
            Button("Delete", role: .destructive) {
                context.delete(node); try? context.save()
            }
        }
    }

    private func rename() {
        // Placeholder: wire a rename alert/sheet. Kept minimal in the scaffold.
    }
}

private struct NoteRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var note: OutlineNode

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: note.isVerbatim ? "quote.opening" : "circle.fill")
                .font(.system(size: note.isVerbatim ? 10 : 5))
                .foregroundStyle(note.isVerbatim ? Color.accentColor : .secondary)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.noteText ?? note.title)
                    .font(.callout)
                    .italic(note.isVerbatim)
                if let p = note.sourcePage {
                    Text("p. \(p)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                context.delete(note); try? context.save()
            }
            Button(note.isVerbatim ? "Summary" : "Verbatim") {
                note.isVerbatim.toggle(); try? context.save()
            }
            .tint(.indigo)
        }
    }
}

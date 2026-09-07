import SwiftUI
import SwiftData

@main
struct MarkDownApp: App {
    @State private var container: ModelContainer

    init() {
        _container = State(initialValue: PersistenceController.makeContainer())
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(container)
    }
}

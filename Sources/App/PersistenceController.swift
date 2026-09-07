import Foundation
import SwiftData

/// Builds the SwiftData container. Local store by default; when the user opts
/// into iCloud sync (Settings) the store is reconfigured for CloudKit on the
/// next launch.
enum PersistenceController {
    static let iCloudSyncDefaultsKey = "settings.icloudSyncEnabled"

    static var schema: Schema {
        Schema([Book.self, OutlineNode.self, Scan.self])
    }

    static func makeContainer() -> ModelContainer {
        let syncEnabled = UserDefaults.standard.bool(forKey: iCloudSyncDefaultsKey)
        let config: ModelConfiguration

        if syncEnabled {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.example.MarkDown")
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A schema/store mismatch during early development shouldn't brick
            // the app — fall back to an in-memory store and surface it in logs.
            assertionFailure("ModelContainer failed: \(error)")
            let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [mem])
        }
    }
}

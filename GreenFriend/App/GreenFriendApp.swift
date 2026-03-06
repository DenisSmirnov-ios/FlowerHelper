import SwiftUI
import SwiftData

@main
struct GreenFriendApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Plant.self,
            CareLog.self,
            DiagnosisRecord.self
        ])

        let modelConfiguration = ModelConfiguration(
            "GreenFriendStore",
            schema: schema,
            url: storeURL
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If schema migration fails on a real device after model changes,
            // reset local store once and recreate container to avoid launch crash.
            resetStoreFiles(at: storeURL)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(sharedModelContainer)
    }

    private static var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport.appendingPathComponent("GreenFriend.store")
    }

    private static func resetStoreFiles(at url: URL) {
        let fm = FileManager.default
        let basePath = url.path
        let related = [basePath, "\(basePath)-shm", "\(basePath)-wal"]

        for path in related where fm.fileExists(atPath: path) {
            try? fm.removeItem(atPath: path)
        }
    }
}

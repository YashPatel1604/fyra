//
//  FyraApp.swift
//  Fyra
//

import SwiftUI
import SwiftData

@main
struct FyraApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([CheckIn.self, UserSettings.self, ProgressPeriod.self, WorkoutSession.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

//
//  AppRootView.swift
//  Fyra
//

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CheckInView()
                .tabItem {
                    Label("Check-In", systemImage: "plus.circle.fill")
                }
                .tag(0)

            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .tag(1)

            CompareView()
                .tabItem {
                    Label("Compare", systemImage: "square.split.2x2")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(.accentColor)
        .onAppear {
            if settingsList.isEmpty {
                modelContext.insert(UserSettings())
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [CheckIn.self, UserSettings.self], inMemory: true)
}

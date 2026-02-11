//
//  AppRootView.swift
//  Fyra
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsList: [UserSettings]
    @Query(sort: \ProgressPeriod.startDate, order: .forward) private var periods: [ProgressPeriod]
    @State private var selectedTab = 0
    @State private var showSplash = true

    private var preferredColorScheme: ColorScheme? {
        switch settingsList.first?.appearanceMode ?? .system {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        ZStack {
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
        .tint(NeonTheme.accent)
        .toolbarBackground(NeonTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
                if settingsList.isEmpty {
                    modelContext.insert(UserSettings())
                    try? modelContext.save()
                }
                if let settings = settingsList.first {
                    _ = ProgressPeriodService.ensureActivePeriodIfNeeded(
                        settings: settings,
                        periods: periods,
                        modelContext: modelContext
                    )
                    try? modelContext.save()
                    if settings.notificationRemindersEnabled {
                        Task { @MainActor in
                            let ok = await ReminderNotificationService.syncReminderNotifications(
                                enabled: true,
                                reminderTime: settings.reminderTime
                            )
                            if !ok {
                                settings.notificationRemindersEnabled = false
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
            .task(id: settingsList.first?.appleHealthWorkoutImportEnabled ?? false) {
                let enabled = settingsList.first?.appleHealthWorkoutImportEnabled ?? false
                if enabled {
                    await configureWorkoutAutoImport()
                    await importWorkoutsIfEnabled()
                } else {
                    await HealthSyncService.stopWorkoutObserver()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { @MainActor in
                    await importWorkoutsIfEnabled()
                }
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            guard showSplash else { return }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }

    @MainActor
    private func importWorkoutsIfEnabled() async {
        guard let settings = settingsList.first, settings.appleHealthWorkoutImportEnabled else { return }
        _ = await WorkoutImportService.importFromAppleHealth(
            modelContext: modelContext,
            settings: settings
        )
    }

    @MainActor
    private func configureWorkoutAutoImport() async {
        _ = await HealthSyncService.startWorkoutObserver {
            await importWorkoutsIfEnabled()
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: [CheckIn.self, UserSettings.self, ProgressPeriod.self, WorkoutSession.self], inMemory: true)
}

extension View {
    func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

private struct SplashView: View {
    @State private var reveal = false
    @State private var breathe = false
    @State private var ring = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            Circle()
                .strokeBorder(Color.accentColor.opacity(0.14), lineWidth: 2)
                .frame(width: 180, height: 180)

            Circle()
                .strokeBorder(Color.accentColor.opacity(0.28), lineWidth: 2)
                .frame(width: 170, height: 170)
                .scaleEffect(ring ? 1.35 : 0.9)
                .opacity(ring ? 0 : 0.35)
                .blur(radius: ring ? 0 : 2)
                .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: ring)

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .scaleEffect(reveal ? 1.0 : 0.86)
                .opacity(reveal ? 1 : 0)
                .rotationEffect(.degrees(reveal ? 0 : -4))
                .offset(y: breathe ? -3 : 3)
                .shadow(color: Color.black.opacity(0.16), radius: breathe ? 16 : 20, y: breathe ? 6 : 10)
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: breathe)
        }
        .task {
            ring = true
            withAnimation(.easeOut(duration: 0.9)) {
                reveal = true
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
            breathe = true
        }
    }
}

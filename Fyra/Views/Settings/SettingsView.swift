//
//  SettingsView.swift
//  Fyra
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .forward) private var allCheckIns: [CheckIn]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkouts: [WorkoutSession]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \ProgressPeriod.startDate, order: .forward) private var periods: [ProgressPeriod]

    @State private var showExportCompareSheet = false
    @State private var permissionAlertMessage: String?

    private var settings: UserSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    if let settings {
                        VStack(spacing: 20) {
                            storageCard
                            exportCard(settings: settings)
                            weightUnitCard(settings: settings)
                            appearanceCard(settings: settings)
                            reminderSettingsCard(settings: settings)
                            healthSyncCard(settings: settings)
                            photoSettingsCard(settings: settings)
                            goalCard(settings: settings)
                            progressPeriodCard(settings: settings)
                            whyStartedCard(settings: settings)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                    }
                }
            }
            .background(NeonTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if let settings {
                    _ = ProgressPeriodService.ensureActivePeriodIfNeeded(
                        settings: settings,
                        periods: periods,
                        modelContext: modelContext
                    )
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showExportCompareSheet) {
                ExportCompareImageSheet(
                    checkIns: allCheckIns,
                    weightUnit: weightUnit,
                    onExport: {
                        if let s = settingsList.first {
                            s.lastExportDate = Date()
                            try? modelContext.save()
                        }
                    }
                )
            }
            .alert("Permission Required", isPresented: Binding(
                get: { permissionAlertMessage != nil },
                set: { if !$0 { permissionAlertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { permissionAlertMessage = nil }
            } message: {
                Text(permissionAlertMessage ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(NeonTheme.textPrimary)
            Text("Customize your experience")
                .font(.subheadline)
                .foregroundStyle(NeonTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .background(NeonTheme.surface)
        .overlay(
            Rectangle()
                .fill(NeonTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var storageCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("🔒")
                .font(.title3)
            VStack(alignment: .leading, spacing: 6) {
                Text("Private & Secure")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NeonTheme.accent)
                Text("All data is stored locally on your device")
                    .font(.subheadline)
                    .foregroundStyle(NeonTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .neonCard(
            background: NeonTheme.surface,
            border: NeonTheme.accent.opacity(0.3),
            shadowColor: NeonTheme.accent.opacity(0.2)
        )
    }

    private func exportCard(settings: UserSettings) -> some View {
        let lastExportText = settings.lastExportDate.map { "Last export: \(formattedDate($0))" }
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "tray.and.arrow.down", size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Data")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NeonTheme.textPrimary)
                    if let lastExportText {
                        Text(lastExportText)
                            .font(.caption)
                            .foregroundStyle(NeonTheme.textTertiary)
                    }
                }
            }
            VStack(spacing: 10) {
                Button {
                    exportWeightCSV()
                } label: {
                    Text("Export Weight CSV")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(NeonTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                        .shadow(color: NeonTheme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                }

                Button {
                    showExportCompareSheet = true
                } label: {
                    Text("Export Compare Image")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NeonTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(NeonTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                                .stroke(NeonTheme.borderStrong, lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .neonCard()
    }

    private func weightUnitCard(settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "scalemass", size: 48)
                Text("Weight Unit")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
            }
            HStack(spacing: 12) {
                selectionButton(
                    title: "LB",
                    selected: settings.weightUnit == .lb
                ) {
                    applyWeightUnitChange(to: .lb, settings: settings)
                }
                selectionButton(
                    title: "KG",
                    selected: settings.weightUnit == .kg
                ) {
                    applyWeightUnitChange(to: .kg, settings: settings)
                }
            }
        }
        .padding(20)
        .neonCard()
    }

    private func appearanceCard(settings: UserSettings) -> some View {
        let currentMode = settings.appearanceMode ?? .system
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "paintpalette", size: 48)
                Text("Appearance")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
            }
            HStack(spacing: 12) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    selectionButton(title: mode.displayName, selected: currentMode == mode) {
                        settings.appearanceMode = mode
                        try? modelContext.save()
                    }
                }
            }
        }
        .padding(20)
        .neonCard()
    }

    private func reminderSettingsCard(settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "bell", size: 48)
                Text("Smart Reminders")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
            }

            HStack {
                Text("Daily reminder notification")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
                NeonToggle(isOn: Binding(
                    get: { settings.notificationRemindersEnabled },
                    set: { newValue in
                        settings.notificationRemindersEnabled = newValue
                        if newValue, settings.reminderTime == nil {
                            settings.reminderTime = Date()
                        }
                        try? modelContext.save()
                        Task { @MainActor in
                            let ok = await ReminderNotificationService.syncReminderNotifications(
                                enabled: newValue,
                                reminderTime: settings.reminderTime
                            )
                            if !ok {
                                settings.notificationRemindersEnabled = false
                                try? modelContext.save()
                                permissionAlertMessage = "Please allow notifications in iOS Settings to enable daily reminders."
                            }
                        }
                    }
                ))
            }
            .padding(14)
            .background(NeonTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .stroke(NeonTheme.borderStrong, lineWidth: 1)
            )

            DatePicker(
                "Reminder time",
                selection: Binding(
                    get: { settings.reminderTime ?? Date() },
                    set: { newValue in
                        settings.reminderTime = newValue
                        try? modelContext.save()
                        if settings.notificationRemindersEnabled {
                            Task { @MainActor in
                                _ = await ReminderNotificationService.syncReminderNotifications(
                                    enabled: true,
                                    reminderTime: newValue
                                )
                            }
                        }
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .disabled(!settings.notificationRemindersEnabled)
            .foregroundStyle(NeonTheme.textPrimary)
            .padding(14)
            .background(NeonTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .stroke(NeonTheme.borderStrong, lineWidth: 1)
            )

            HStack {
                Text("In-app adaptive nudges")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
                NeonToggle(isOn: Binding(
                    get: { settings.smartRemindersEnabled },
                    set: { newValue in
                        settings.smartRemindersEnabled = newValue
                        try? modelContext.save()
                    }
                ))
            }
            .padding(14)
            .background(NeonTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .stroke(NeonTheme.borderStrong, lineWidth: 1)
            )
        }
        .padding(20)
        .neonCard()
    }

    private func healthSyncCard(settings: UserSettings) -> some View {
        let isWeightSyncAvailable = HealthSyncService.isAvailable
        let isWorkoutImportAvailable = HealthSyncService.isWorkoutImportAvailable
        let workoutSyncDescription = settings.lastWorkoutImportDate.map { date in
            "Imported \(allWorkouts.count) workouts. Last import: \(formattedDate(date))"
        } ?? "Automatically import workouts from Apple Health (including WHOOP if WHOOP is connected to Health)."
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "heart.text.square", size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text("Sync weight and import workouts")
                        .font(.caption)
                        .foregroundStyle(NeonTheme.textTertiary)
                }
            }

            HStack {
                Text("Sync weight to Apple Health")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
                NeonToggle(isOn: Binding(
                    get: { settings.appleHealthSyncEnabled },
                    set: { newValue in
                        if !newValue {
                            settings.appleHealthSyncEnabled = false
                            try? modelContext.save()
                            return
                        }
                        Task { @MainActor in
                            let authorized = await HealthSyncService.requestWriteAccess()
                            settings.appleHealthSyncEnabled = authorized
                            try? modelContext.save()
                            if !authorized {
                                permissionAlertMessage = "Please allow Health access in iOS Settings to sync weight."
                            }
                            if authorized {
                                await syncAllWeightsToHealth(settings: settings)
                            }
                        }
                    }
                ))
            }
            .disabled(!isWeightSyncAvailable)
            .padding(14)
            .background(NeonTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .stroke(NeonTheme.borderStrong, lineWidth: 1)
            )

            HStack {
                Text("Import workouts from Apple Health")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
                NeonToggle(isOn: Binding(
                    get: { settings.appleHealthWorkoutImportEnabled },
                    set: { newValue in
                        if !newValue {
                            settings.appleHealthWorkoutImportEnabled = false
                            try? modelContext.save()
                            return
                        }
                        Task { @MainActor in
                            let authorized = await HealthSyncService.requestWorkoutReadAccess()
                            settings.appleHealthWorkoutImportEnabled = authorized
                            try? modelContext.save()
                            if !authorized {
                                permissionAlertMessage = "Please allow Health access in iOS Settings to import workouts."
                                return
                            }
                            await importWorkoutsFromHealth(settings: settings)
                        }
                    }
                ))
            }
            .disabled(!isWorkoutImportAvailable)
            .padding(14)
            .background(NeonTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .stroke(NeonTheme.borderStrong, lineWidth: 1)
            )

            Button {
                Task { @MainActor in
                    await importWorkoutsFromHealth(settings: settings)
                }
            } label: {
                HStack {
                    Text("Import Workouts Now")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                }
                .foregroundStyle(NeonTheme.textPrimary)
                .padding(12)
                .background(NeonTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                        .stroke(NeonTheme.borderStrong, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!settings.appleHealthWorkoutImportEnabled || !isWorkoutImportAvailable)

            Text(workoutSyncDescription)
                .font(.caption)
                .foregroundStyle(NeonTheme.textTertiary)

            if !isWeightSyncAvailable {
                Text("Apple Health weight sync is not available on this device.")
                    .font(.caption)
                    .foregroundStyle(NeonTheme.textTertiary)
            }
            if !isWorkoutImportAvailable {
                Text("Apple Health workout import is not available on this device.")
                    .font(.caption)
                    .foregroundStyle(NeonTheme.textTertiary)
            }
        }
        .padding(20)
        .neonCard()
    }

    private func photoSettingsCard(settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "camera", size: 48)
                Text("Photo Settings")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
            }

            HStack {
                Text("Photo alignment assist")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
                NeonToggle(isOn: Binding(
                    get: { settings.alignmentAssistEnabled },
                    set: { newValue in
                        settings.alignmentAssistEnabled = newValue
                        try? modelContext.save()
                    }
                ))
            }
            .padding(14)
            .background(NeonTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .stroke(NeonTheme.borderStrong, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Photo mode")
                    .font(.caption)
                    .foregroundStyle(NeonTheme.textTertiary)
                HStack(spacing: 12) {
                    selectionButton(
                        title: "Single",
                        selected: settings.photoMode == .single
                    ) {
                        settings.photoMode = .single
                        try? modelContext.save()
                    }
                    selectionButton(
                        title: "Three poses",
                        selected: settings.photoMode == .threePose
                    ) {
                        settings.photoMode = .threePose
                        try? modelContext.save()
                    }
                }
            }

            if settings.photoMode == .single {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Default pose")
                        .font(.caption)
                        .foregroundStyle(NeonTheme.textTertiary)
                    HStack(spacing: 8) {
                        ForEach(Pose.allCases, id: \.self) { pose in
                            selectionButton(
                                title: pose.displayName,
                                selected: settings.preferredPoseSingle == pose
                            ) {
                                settings.preferredPoseSingle = pose
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .neonCard()
    }

    private func goalCard(settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "scope", size: 48)
                Text("Your Goal")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
            }

            Menu {
                ForEach(GoalType.allCases, id: \.self) { goal in
                    Button(goal.displayName) {
                        updateGoalSetting {
                            settings.goalType = goal
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Goal type")
                        .font(.caption)
                        .foregroundStyle(NeonTheme.textTertiary)
                    Spacer()
                    Text(settings.goalType.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NeonTheme.accent)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NeonTheme.textTertiary)
                }
                .padding(14)
                .background(NeonTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                        .stroke(NeonTheme.borderStrong, lineWidth: 1)
                )
            }

            if settings.goalType != .none && settings.goalType != .recomposition {
                goalRangeFields(settings: settings)
            }
            paceRangeFields(settings: settings)
        }
        .padding(20)
        .neonCard()
    }

    private func progressPeriodCard(settings: UserSettings) -> some View {
        let activeText: String = {
            if let active = ProgressPeriodService.activePeriod(settings: settings, periods: periods) {
                return "Current period: \(formattedDate(active.startDate))"
            }
            return "No active progress period"
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "calendar", size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress Period")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text(activeText)
                        .font(.caption)
                        .foregroundStyle(NeonTheme.textTertiary)
                }
            }
            Button("Start New Period") {
                startNewProgressPeriod()
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(NeonTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            .shadow(color: NeonTheme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .padding(20)
        .neonCard()
    }

    private func whyStartedCard(settings: UserSettings) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "text.bubble", size: 48)
                Text("Why You Started")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
            }

            TextField(
                "What's motivating you?",
                text: Binding(
                    get: { settings.whyStarted },
                    set: { newValue in
                        settings.whyStarted = newValue
                        try? modelContext.save()
                    }
                ),
                axis: .vertical
            )
            .lineLimit(2...4)
            .padding(14)
            .background(NeonTheme.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .stroke(NeonTheme.borderStrong, lineWidth: 1)
            )
            .foregroundStyle(NeonTheme.textPrimary)
        }
        .padding(20)
        .neonCard()
    }

    private func selectionButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(selected ? Color.black : NeonTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                        .fill(selected ? NeonTheme.accent : NeonTheme.surfaceAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                        .stroke(selected ? Color.clear : NeonTheme.borderStrong, lineWidth: 1)
                )
                .shadow(color: selected ? NeonTheme.accent.opacity(0.25) : Color.clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func goalRangeFields(settings: UserSettings) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricField(
                title: "Target Min",
                value: Binding(
                    get: { settings.goalMinWeight ?? 0 },
                    set: { v in updateGoalSetting { settings.goalMinWeight = v } }
                ),
                unit: settings.weightUnit.rawValue
            )
            metricField(
                title: "Target Max",
                value: Binding(
                    get: { settings.goalMaxWeight ?? 0 },
                    set: { v in updateGoalSetting { settings.goalMaxWeight = v } }
                ),
                unit: settings.weightUnit.rawValue
            )
        }
    }

    private func paceRangeFields(settings: UserSettings) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricField(
                title: "Pace Min",
                value: Binding(
                    get: { settings.paceMinPerWeek ?? 0 },
                    set: { v in updateGoalSetting { settings.paceMinPerWeek = v } }
                ),
                unit: "\(settings.weightUnit.rawValue)/week"
            )
            metricField(
                title: "Pace Max",
                value: Binding(
                    get: { settings.paceMaxPerWeek ?? 0 },
                    set: { v in updateGoalSetting { settings.paceMaxPerWeek = v } }
                ),
                unit: "\(settings.weightUnit.rawValue)/week"
            )
        }
    }

    private func metricField(title: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(NeonTheme.textTertiary)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.title3.weight(.bold))
                .foregroundStyle(NeonTheme.textPrimary)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(NeonTheme.textTertiary)
        }
        .padding(12)
        .background(NeonTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                .stroke(NeonTheme.borderStrong, lineWidth: 1)
        )
    }

    private func updateGoalSetting(_ update: () -> Void) {
        guard let settings else { return }
        update()
        _ = ProgressPeriodService.handleGoalChange(
            settings: settings,
            periods: periods,
            modelContext: modelContext
        )
        try? modelContext.save()
    }

    private func startNewProgressPeriod() {
        guard let settings else { return }
        _ = ProgressPeriodService.startNewPeriod(
            settings: settings,
            periods: periods,
            modelContext: modelContext,
            closeExisting: true
        )
        try? modelContext.save()
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func exportWeightCSV() {
        guard let url = ExportService.writeWeightCSVToTempFile(checkIns: allCheckIns, unit: weightUnit) else { return }
        ExportService.shareFile(url, from: nil)
        if let s = settingsList.first {
            s.lastExportDate = Date()
            try? modelContext.save()
        }
    }

    private func applyWeightUnitChange(to newUnit: WeightUnit, settings: UserSettings) {
        let oldUnit = settings.weightUnit
        guard oldUnit != newUnit else { return }
        UnitConversionService.convertStoredValues(
            from: oldUnit,
            to: newUnit,
            checkIns: allCheckIns,
            settings: settings,
            periods: periods
        )
        try? modelContext.save()
    }

    @MainActor
    private func syncAllWeightsToHealth(settings: UserSettings) async {
        for checkIn in allCheckIns where checkIn.weight != nil {
            _ = await HealthSyncService.syncWeightIfNeeded(checkIn: checkIn, settings: settings)
        }
        try? modelContext.save()
    }

    @MainActor
    private func importWorkoutsFromHealth(settings: UserSettings) async {
        let result = await WorkoutImportService.importFromAppleHealth(
            modelContext: modelContext,
            settings: settings
        )
        switch result {
        case .imported(let count):
            if count > 0 {
                permissionAlertMessage = "Imported \(count) new workouts from Apple Health."
            }
        case .unauthorized:
            permissionAlertMessage = "Please allow Health access in iOS Settings to import workouts."
        case .unavailable:
            permissionAlertMessage = "Apple Health workout import is not available on this device."
        }
    }
}

struct ExportCompareImageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale
    let checkIns: [CheckIn]
    let weightUnit: WeightUnit
    let onExport: () -> Void

    @State private var fromCheckIn: CheckIn?
    @State private var toCheckIn: CheckIn?
    @State private var pose: Pose = .front
    @State private var caption: String = ""
    @State private var showFromPicker = false
    @State private var showToPicker = false

    private var canExport: Bool { fromCheckIn != nil && toCheckIn != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("From") {
                    Button(fromCheckIn.map { formattedDate($0.date) } ?? "Select") { showFromPicker = true }
                }
                Section("To") {
                    Button(toCheckIn.map { formattedDate($0.date) } ?? "Select") { showToPicker = true }
                }
                Section("Pose") {
                    Picker("Pose", selection: $pose) {
                        ForEach(Pose.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Caption (optional)") {
                    TextField("Caption", text: $caption)
                }
                Section {
                    Button("Export Image") {
                        exportCompareImage()
                        onExport()
                        dismiss()
                    }
                    .disabled(!canExport)
                }
            }
            .navigationTitle("Export Compare Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
            .sheet(isPresented: $showFromPicker) {
                CheckInPickerView(checkIns: checkIns, selected: $fromCheckIn, weightUnit: weightUnit)
            }
            .sheet(isPresented: $showToPicker) {
                CheckInPickerView(checkIns: checkIns, selected: $toCheckIn, weightUnit: weightUnit)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func exportCompareImage() {
        guard let from = fromCheckIn, let to = toCheckIn else { return }
        let fromPath = from.photoPath(for: pose)
        let toPath = to.photoPath(for: pose)
        let cap = caption.isEmpty ? nil : caption
        guard let image = ExportService.compareImage(
            fromPath: fromPath,
            toPath: toPath,
            fromLabel: formattedDate(from.date),
            toLabel: formattedDate(to.date),
            caption: cap,
            scale: displayScale
        ) else { return }
        ExportService.shareImage(image, from: nil)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [CheckIn.self, UserSettings.self, ProgressPeriod.self, WorkoutSession.self], inMemory: true)
}

//
//  SettingsView.swift
//  Fyra
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .forward) private var allCheckIns: [CheckIn]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \ProgressPeriod.startDate, order: .forward) private var periods: [ProgressPeriod]

    @State private var showExportCompareSheet = false

    private var settings: UserSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }

    var body: some View {
        NavigationStack {
            Form {
                if let settings {
                    Section("Storage") {
                        Text("Photos are stored locally on this device by default.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Section("Export") {
                        Button {
                            exportWeightCSV()
                        } label: {
                            Label("Export Weight CSV", systemImage: "doc.text")
                        }
                        .accessibilityHint("Exports all weight entries with date and unit")

                        Button {
                            showExportCompareSheet = true
                        } label: {
                            Label("Export Compare Image", systemImage: "square.split.2x2")
                        }
                        .accessibilityHint("Export a side-by-side comparison image")

                        if let last = settings.lastExportDate {
                            Text("Last export: \(formattedDate(last))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Section("Weight") {
                        Picker("Unit", selection: Binding(
                            get: { settings.weightUnit },
                            set: { settings.weightUnit = $0; try? modelContext.save() }
                        )) {
                            ForEach(WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue.uppercased()).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Appearance") {
                        Picker("Theme", selection: Binding(
                            get: { settings.appearanceMode ?? .system },
                            set: { settings.appearanceMode = $0; try? modelContext.save() }
                        )) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Photos") {
                        Toggle("Photo-first mode", isOn: Binding(
                            get: { settings.photoFirstMode },
                            set: { settings.photoFirstMode = $0; try? modelContext.save() }
                        ))
                        Text("When on, weight is hidden on Check-In; use \"Add weight\" to log.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Photo mode", selection: Binding(
                            get: { settings.photoMode },
                            set: { settings.photoMode = $0; try? modelContext.save() }
                        )) {
                            Text("Single pose").tag(PhotoMode.single)
                            Text("Three poses").tag(PhotoMode.threePose)
                        }

                        if settings.photoMode == .single {
                            Picker("Default pose", selection: Binding(
                                get: { settings.preferredPoseSingle },
                                set: { settings.preferredPoseSingle = $0; try? modelContext.save() }
                            )) {
                                ForEach(Pose.allCases, id: \.self) { pose in
                                    Text(pose.displayName).tag(pose)
                                }
                            }
                        }
                    }

                    Section("Compare") {
                        Toggle("Hide weight change", isOn: Binding(
                            get: { settings.hideWeightDeltaInCompare },
                            set: { settings.hideWeightDeltaInCompare = $0; try? modelContext.save() }
                        ))
                    }

                    Section("Goal (for context only)") {
                        Picker("Goal", selection: Binding(
                            get: { settings.goalType },
                            set: { newValue in updateGoalSetting { settings.goalType = newValue } }
                        )) {
                            ForEach(GoalType.allCases, id: \.self) { goal in
                                Text(goal.displayName).tag(goal)
                            }
                        }
                        if settings.goalType != .none && settings.goalType != .recomposition {
                            goalRangeFields(settings: settings)
                        }
                        paceRangeFields(settings: settings)
                    }

                    Section("Progress period") {
                        if let active = ProgressPeriodService.activePeriod(settings: settings, periods: periods) {
                            Text("Current period started \(formattedDate(active.startDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No active progress period yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Start new progress period") {
                            startNewProgressPeriod()
                        }
                    }

                    Section("Why you started") {
                        TextField("One sentence (shown only in Compare)", text: Binding(
                            get: { settings.whyStarted },
                            set: { settings.whyStarted = $0; try? modelContext.save() }
                        ), axis: .vertical)
                        .lineLimit(2...4)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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
        }
    }

    private func goalRangeFields(settings: UserSettings) -> some View {
        Group {
            HStack {
                Text("Target min")
                Spacer()
                TextField("Min", value: Binding(
                    get: { settings.goalMinWeight ?? 0 },
                    set: { v in updateGoalSetting { settings.goalMinWeight = v } }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            }
            HStack {
                Text("Target max")
                Spacer()
                TextField("Max", value: Binding(
                    get: { settings.goalMaxWeight ?? 0 },
                    set: { v in updateGoalSetting { settings.goalMaxWeight = v } }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            }
        }
    }

    private func paceRangeFields(settings: UserSettings) -> some View {
        Group {
            HStack {
                Text("Pace min (\(settings.weightUnit.rawValue)/week)")
                Spacer()
                TextField("Min", value: Binding(
                    get: { settings.paceMinPerWeek ?? 0 },
                    set: { v in updateGoalSetting { settings.paceMinPerWeek = v } }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            }
            HStack {
                Text("Pace max (\(settings.weightUnit.rawValue)/week)")
                Spacer()
                TextField("Max", value: Binding(
                    get: { settings.paceMaxPerWeek ?? 0 },
                    set: { v in updateGoalSetting { settings.paceMaxPerWeek = v } }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            }
        }
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
}

struct ExportCompareImageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
            caption: cap
        ) else { return }
        ExportService.shareImage(image, from: nil)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [CheckIn.self, UserSettings.self, ProgressPeriod.self], inMemory: true)
}

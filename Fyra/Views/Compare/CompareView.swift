//
//  CompareView.swift
//  Fyra
//

import SwiftUI
import SwiftData

struct CompareView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .forward) private var allCheckIns: [CheckIn]
    @Query private var settingsList: [UserSettings]
    @Query(sort: \ProgressPeriod.startDate, order: .forward) private var periods: [ProgressPeriod]

    @State private var fromCheckIn: CheckIn?
    @State private var toCheckIn: CheckIn?
    @State private var selectedPose: Pose = .front
    @State private var showFromPicker = false
    @State private var showToPicker = false
    @State private var showCompareNudge = false
    @State private var lightingDiffers = false
    @State private var showTimelapseSheet = false

    private var settings: UserSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }
    private var hideWeightDelta: Bool {
        (settings?.hideWeightDeltaInCompare ?? false) || (settings?.photoFirstMode ?? false)
    }
    private var presetService: ComparePresetService {
        ComparePresetService(checkIns: allCheckIns, baselineCheckInID: settings?.baselineCheckInID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    if !(settings?.whyStarted.isEmpty ?? true) {
                        whyStartedCard
                    }
                    if showCompareNudge {
                        compareNudgeBanner
                    }
                    presetButtons
                    timelapseCard
                    posePicker
                    if hideWeightDelta {
                        Text("Weight change hidden")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    datePickers
                    if fromCheckIn != nil && toCheckIn != nil {
                        if lightingDiffers {
                            lightingDisclaimer
                        }
                        comparisonContent
                    } else {
                        emptyPrompt
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                recordCompareOpen()
                updateCompareNudge()
            }
            .onChange(of: fromCheckIn) { _, _ in updateLightingDiffers() }
            .onChange(of: toCheckIn) { _, _ in updateLightingDiffers() }
            .onChange(of: selectedPose) { _, _ in updateLightingDiffers() }
            .sheet(isPresented: $showFromPicker) {
                CheckInPickerView(checkIns: allCheckIns, selected: $fromCheckIn, weightUnit: weightUnit)
            }
            .sheet(isPresented: $showToPicker) {
                CheckInPickerView(checkIns: allCheckIns, selected: $toCheckIn, weightUnit: weightUnit)
            }
            .sheet(isPresented: $showTimelapseSheet) {
                TimelapseGeneratorView(checkIns: allCheckIns, settings: settings, periods: periods)
            }
        }
    }

    private func recordCompareOpen() {
        guard let s = settingsList.first else { return }
        _ = EngagementService.recordCompareOpen(settings: s)
        try? modelContext.save()
        updateCompareNudge()
    }

    private func updateCompareNudge() {
        showCompareNudge = settingsList.first.map { EngagementService.shouldShowCompareNudge(settings: $0) } ?? false
    }

    private func dismissCompareNudge() {
        guard let s = settingsList.first else { return }
        EngagementService.dismissCompareNudge(settings: s)
        try? modelContext.save()
        showCompareNudge = false
    }

    private var compareNudgeBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Progress shows best over weeks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Dismiss") {
                dismissCompareNudge()
            }
            .font(.caption.weight(.medium))
            .frame(minWidth: AppTheme.minTapTarget, minHeight: AppTheme.minTapTarget)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
    }

    private func updateLightingDiffers() {
        guard let from = fromCheckIn, let to = toCheckIn else {
            lightingDiffers = false
            return
        }
        let fromPath = from.photoPath(for: selectedPose)
        let toPath = to.photoPath(for: selectedPose)
        let img1 = fromPath.flatMap { ImageStore.shared.load(path: $0) }
        let img2 = toPath.flatMap { ImageStore.shared.load(path: $0) }
        lightingDiffers = LightingAnalyzer.hasSignificantLightingDifference(image1: img1, image2: img2)
    }

    private var lightingDisclaimer: some View {
        Text("Lighting differs — changes may appear stronger or weaker.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var whyStartedCard: some View {
        Group {
            if let why = settings?.whyStarted, !why.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    AppTheme.sectionLabel("Why you started")
                    Text(why)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.cardPadding)
                .background(AppTheme.cardBackground)
            }
        }
    }

    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionLabel("Presets")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button("First vs Latest") { applyPreset { presetService.firstVsLatest() } }
                        .buttonStyle(.borderedProminent)
                    Button("30 days vs Today") { applyPreset { presetService.todayVs30DaysAgo() } }
                        .buttonStyle(.bordered)
                }
                HStack(spacing: 10) {
                    Button("Month start vs end") { applyPreset { presetService.thisMonthStartVsEnd() } }
                        .buttonStyle(.bordered)
                    Button("Week start vs end") { applyPreset { presetService.thisWeekStartVsEnd() } }
                        .buttonStyle(.bordered)
                }
                Button("Best visual change this month") {
                    applyPreset { presetService.bestVisualChangeThisMonth(pose: selectedPose) }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
                if settings?.baselineCheckInID != nil {
                    Button("Baseline vs Today") {
                        applyPreset { presetService.baselineVsToday(pose: selectedPose) }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timelapseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppTheme.sectionLabel("Progress timelapse")
            Text("Create a simple video from your progress photos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Create Timelapse") {
                showTimelapseSheet = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
    }

    private func applyPreset(_ result: () -> (from: CheckIn, to: CheckIn)?) {
        if let (from, to) = result() {
            fromCheckIn = from
            toCheckIn = to
        }
    }

    private var posePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppTheme.sectionLabel("Pose")
            Picker("Pose", selection: $selectedPose) {
                ForEach(Pose.allCases, id: \.self) { pose in
                    Text(pose.displayName).tag(pose)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var datePickers: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionLabel("Select check-ins")
            Button {
                showFromPicker = true
            } label: {
                HStack {
                    Label(fromCheckIn.map { formattedDate($0.date) } ?? "From", systemImage: "calendar")
                    Spacer()
                    if fromCheckIn != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(AppTheme.cardPadding)
                .background(AppTheme.cardBackground)
            }
            .buttonStyle(.plain)

            Button {
                showToPicker = true
            } label: {
                HStack {
                    Label(toCheckIn.map { formattedDate($0.date) } ?? "To", systemImage: "calendar")
                    Spacer()
                    if toCheckIn != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(AppTheme.cardPadding)
                .background(AppTheme.cardBackground)
            }
            .buttonStyle(.plain)
        }
    }

    private var comparisonContent: some View {
        Group {
            if let from = fromCheckIn, let to = toCheckIn {
                let fromPath = from.photoPath(for: selectedPose)
                let toPath = to.photoPath(for: selectedPose)

                if fromPath != nil || toPath != nil {
                    VStack(spacing: 16) {
                        // Stats
                        comparisonStats(from: from, to: to)

                        // Side by side
                        HStack(alignment: .top, spacing: 16) {
                            comparisonPhoto(path: fromPath, label: formattedDate(from.date))
                            comparisonPhoto(path: toPath, label: formattedDate(to.date))
                        }
                    }
                } else {
                    Text("No \(selectedPose.displayName.lowercased()) photos for one or both dates.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
    }

    private func comparisonStats(from: CheckIn, to: CheckIn) -> some View {
        let days = Calendar.current.dateComponents([.day], from: from.date, to: to.date).day ?? 0
        let weightDelta: Double? = hideWeightDelta ? nil : (from.weight.flatMap { w1 in to.weight.map { w2 in w2 - w1 } })

        return HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Days between")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(days)")
                    .font(.title2.weight(.semibold))
            }
            if let delta = weightDelta {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight change")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(delta >= 0 ? "+" : "")\(formatWeight(delta)) \(weightUnit.rawValue)")
                        .font(.title2.weight(.semibold))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
    }

    private func comparisonPhoto(path: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let path, let img = ImageStore.shared.loadImage(path: path) {
                img
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            } else {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(Color(.tertiarySystemFill))
                    .frame(minHeight: 180)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.quaternary)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyPrompt: some View {
        ContentUnavailableView {
            Label("Select two check-ins", systemImage: "square.split.2x2")
        } description: {
            Text("Choose \"From\" and \"To\" dates to compare photos and weight.")
        }
        .padding(.vertical, 32)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatWeight(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct CheckInPickerView: View {
    let checkIns: [CheckIn]
    @Binding var selected: CheckIn?
    let weightUnit: WeightUnit
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(checkIns) { checkIn in
                    Button {
                        selected = checkIn
                        dismiss()
                    } label: {
                        HStack {
                            if let path = checkIn.primaryPhotoPath, let img = ImageStore.shared.loadImage(path: path) {
                                img
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formattedDate(checkIn.date))
                                    .font(.headline)
                                if let w = checkIn.weight {
                                    Text("\(formatWeight(w)) \(weightUnit.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selected?.id == checkIn.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatWeight(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

#Preview {
    CompareView()
        .modelContainer(for: [CheckIn.self, UserSettings.self, ProgressPeriod.self], inMemory: true)
}

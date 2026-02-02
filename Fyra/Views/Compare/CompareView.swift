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
    @State private var showInsights = false

    private var settings: UserSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }
    private var hasCompareInsights: Bool {
        showCompareNudge || !(settings?.whyStarted.isEmpty ?? true)
    }
    private var presetService: ComparePresetService {
        ComparePresetService(checkIns: allCheckIns, baselineCheckInID: settings?.baselineCheckInID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: 20) {
                        if hasCompareInsights {
                            compareInsightsCard
                        }
                        presetButtons
                        timelapseCard
                        posePicker
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
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .background(NeonTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                recordCompareOpen()
                updateCompareNudge()
                if showCompareNudge {
                    showInsights = true
                }
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
        Text("✨ Best results with similar lighting")
            .font(.caption)
            .foregroundStyle(NeonTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var compareInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $showInsights) {
                VStack(spacing: 10) {
                    if showCompareNudge {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NeonTheme.accent)
                            Text("Progress comparisons are clearer across multi-week gaps.")
                                .font(.subheadline)
                                .foregroundStyle(NeonTheme.textSecondary)
                            Spacer(minLength: 8)
                            Button {
                                dismissCompareNudge()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(NeonTheme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(NeonTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                    }

                    if let why = settings?.whyStarted, !why.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Text("💪")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Why You Started")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(NeonTheme.textPrimary)
                                Text(why)
                                    .font(.subheadline)
                                    .foregroundStyle(NeonTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(NeonTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 10) {
                    NeonIconBadge(systemName: "lightbulb", size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Insights")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(NeonTheme.textPrimary)
                        Text("Quick context before you compare")
                            .font(.caption)
                            .foregroundStyle(NeonTheme.textTertiary)
                    }
                    Spacer()
                }
            }
            .tint(NeonTheme.textSecondary)
        }
        .padding(18)
        .neonCard()
    }

    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Compare")
                .font(.headline.weight(.bold))
                .foregroundStyle(NeonTheme.textPrimary)
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    presetChip("First vs Latest") {
                        applyPreset { presetService.firstVsLatest() }
                    }
                    presetChip("30d vs Today") {
                        applyPreset { presetService.todayVs30DaysAgo() }
                    }
                }

                GridRow {
                    presetChip("Month start/end") {
                        applyPreset { presetService.thisMonthStartVsEnd() }
                    }
                    presetChip("Week start/end") {
                        applyPreset { presetService.thisWeekStartVsEnd() }
                    }
                }

                if settings?.baselineCheckInID != nil {
                    GridRow {
                        presetChip("Best visual (month)") {
                            applyPreset { presetService.bestVisualChangeThisMonth(pose: selectedPose) }
                        }
                        presetChip("Baseline vs Today", highlight: true) {
                            applyPreset { presetService.baselineVsToday(pose: selectedPose) }
                        }
                    }
                } else {
                    GridRow {
                        presetChip("Best visual (month)") {
                            applyPreset { presetService.bestVisualChangeThisMonth(pose: selectedPose) }
                        }
                        .gridCellColumns(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .neonCard()
    }

    private var timelapseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "film", size: 48, background: Color.black.opacity(0.1), foreground: .black)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress Timelapse")
                        .font(.headline.weight(.bold))
                    Text("Animate your transformation")
                        .font(.caption)
                        .foregroundStyle(Color.black.opacity(0.7))
                }
            }
            Button {
                showTimelapseSheet = true
            } label: {
                Text("Create Timelapse")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(NeonTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                            .stroke(NeonTheme.border, lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .background(NeonTheme.accent)
        .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerLarge, style: .continuous))
        .shadow(color: NeonTheme.accent.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    private func applyPreset(_ result: () -> (from: CheckIn, to: CheckIn)?) {
        if let (from, to) = result() {
            fromCheckIn = from
            toCheckIn = to
        }
    }

    private func presetChip(_ title: String, highlight: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(NeonChipStyle(highlight: highlight))
    }

    private var posePicker: some View {
        HStack(spacing: 8) {
            ForEach(Pose.allCases, id: \.self) { pose in
                Button {
                    selectedPose = pose
                } label: {
                    Text(pose.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selectedPose == pose ? Color.black : NeonTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                                .fill(selectedPose == pose ? NeonTheme.accent : NeonTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                                .stroke(selectedPose == pose ? Color.clear : NeonTheme.border, lineWidth: 1)
                        )
                        .shadow(color: selectedPose == pose ? NeonTheme.accent.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var datePickers: some View {
        HStack(spacing: 12) {
            datePickerCard(
                title: "From",
                value: fromCheckIn.map { formattedDate($0.date) } ?? "Select date",
                isSelected: fromCheckIn != nil
            ) { showFromPicker = true }
            datePickerCard(
                title: "To",
                value: toCheckIn.map { formattedDate($0.date) } ?? "Select date",
                isSelected: toCheckIn != nil
            ) { showToPicker = true }
        }
    }

    private var comparisonContent: some View {
        Group {
            if let from = fromCheckIn, let to = toCheckIn {
                let fromPath = from.photoPath(for: selectedPose)
                let toPath = to.photoPath(for: selectedPose)

                if fromPath != nil || toPath != nil {
                    VStack(spacing: 16) {
                        comparisonStats(from: from, to: to)
                        HStack(alignment: .top, spacing: 16) {
                            comparisonPhoto(path: fromPath, label: formattedDate(from.date), subtitle: "Before", highlight: false)
                            comparisonPhoto(path: toPath, label: formattedDate(to.date), subtitle: "After", highlight: true)
                        }
                    }
                } else {
                    Text("No \(selectedPose.displayName.lowercased()) photos for one or both dates.")
                        .font(.subheadline)
                        .foregroundStyle(NeonTheme.textTertiary)
                        .padding(16)
                }
            }
        }
    }

    @ViewBuilder
    private func comparisonStats(from: CheckIn, to: CheckIn) -> some View {
        let days = Calendar.current.dateComponents([.day], from: from.date, to: to.date).day ?? 0
        let weightDelta: Double? = from.weight.flatMap { w1 in to.weight.map { w2 in w2 - w1 } }

        if let delta = weightDelta {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard(title: "Days Between", value: "\(days)", highlight: false)
                statCard(
                    title: "Weight Change",
                    value: "\(delta >= 0 ? "+" : "")\(formatWeight(delta)) \(weightUnit.rawValue)",
                    highlight: true
                )
            }
        } else {
            statCard(title: "Days Between", value: "\(days)", highlight: false)
        }
    }

    private func comparisonPhoto(path: String?, label: String, subtitle: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let path, let img = ImageStore.shared.loadImage(path: path) {
                img
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: highlight ? [NeonTheme.lime500, NeonTheme.lime600] : [NeonTheme.surfaceStrong, NeonTheme.surfaceAlt],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(minHeight: 200)
            }
            VStack(alignment: .center, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(highlight ? NeonTheme.accent : NeonTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(highlight ? NeonTheme.accent.opacity(0.7) : NeonTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .padding(12)
        .neonCard(
            background: NeonTheme.surface,
            border: highlight ? NeonTheme.accent.opacity(0.5) : NeonTheme.border
        )
    }

    private var emptyPrompt: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NeonTheme.surfaceAlt)
                    .frame(width: 80, height: 80)
                Image(systemName: "calendar")
                    .font(.title)
                    .foregroundStyle(NeonTheme.textTertiary)
            }
            Text("Select two check-ins")
                .font(.headline.weight(.bold))
                .foregroundStyle(NeonTheme.textPrimary)
            Text("Use quick presets or tap the date selectors above")
                .font(.subheadline)
                .foregroundStyle(NeonTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .neonCard()
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

private extension CompareView {
    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Compare")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(NeonTheme.textPrimary)
            Text("See your transformation")
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

    func datePickerCard(title: String, value: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    NeonIconBadge(systemName: "calendar", size: 40)
                    Text(title.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NeonTheme.textTertiary)
                }
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .neonCard(
                background: NeonTheme.surface,
                border: isSelected ? NeonTheme.accent : NeonTheme.border,
                shadowColor: isSelected ? NeonTheme.accent.opacity(0.2) : Color.black.opacity(0.3)
            )
        }
        .buttonStyle(.plain)
    }

    func statCard(title: String, value: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(highlight ? NeonTheme.accent : NeonTheme.textTertiary)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(highlight ? NeonTheme.accent : NeonTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .neonCard(
            background: NeonTheme.surface,
            border: highlight ? NeonTheme.accent.opacity(0.3) : NeonTheme.border,
            shadowColor: highlight ? NeonTheme.accent.opacity(0.2) : Color.black.opacity(0.3)
        )
    }
}

private struct NeonChipStyle: ButtonStyle {
    var highlight: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(highlight ? Color.black : NeonTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                Capsule()
                    .fill(highlight ? NeonTheme.accent : NeonTheme.surfaceAlt)
            )
            .overlay(
                Capsule()
                    .stroke(highlight ? Color.clear : NeonTheme.borderStrong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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

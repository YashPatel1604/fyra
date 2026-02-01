//
//  CheckInView.swift
//  Fyra
//

import SwiftUI
import SwiftData
import PhotosUI

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .reverse) private var allCheckIns: [CheckIn]
    @Query private var settingsList: [UserSettings]
    @FocusState private var focusedInput: FocusInput?

    @State private var currentCheckIn: CheckIn?
    @State private var isNewCheckIn: Bool = false
    @State private var weightText: String = ""
    @State private var noteText: String = ""
    @State private var waistText: String = ""
    @State private var selectedTagRawValues: Set<String> = []
    @State private var customTagText: String = ""
    @State private var selectedFront: PhotosPickerItem?
    @State private var selectedSide: PhotosPickerItem?
    @State private var selectedBack: PhotosPickerItem?
    @State private var hasChanges: Bool = false
    @State private var loggedToast: Bool = false
    @State private var showWeightSheet: Bool = false
    @State private var showFluctuationBanner: Bool = false
    @State private var showReturnBanner: Bool = false
    @State private var showInsights = false
    @State private var showOptionalDetails = false

    private enum FocusInput {
        case weight
        case waist
        case sheetWeight
    }

    private var settings: UserSettings? { settingsList.first }
    private var lastCheckInDate: Date? {
        allCheckIns.first(where: { $0.hasAnyContent })?.date
    }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }
    private var photoMode: PhotoMode { settings?.photoMode ?? .single }
    private var photoFirstMode: Bool { settings?.photoFirstMode ?? false }
    private var alignmentAssistEnabled: Bool { settings?.alignmentAssistEnabled ?? true }
    private var smartRemindersEnabled: Bool { settings?.smartRemindersEnabled ?? true }
    private var lastWeight: Double? {
        allCheckIns.first(where: { $0.weight != nil })?.weight
    }
    private var previousDayWeight: Double? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return allCheckIns.first(where: { calendar.startOfDay(for: $0.date) < startOfToday && $0.weight != nil })?.weight
    }
    private var streakStats: StreakStats {
        ProgressSupportService.streakStats(checkIns: allCheckIns)
    }
    private var smartReminderMessage: String? {
        guard smartRemindersEnabled else { return nil }
        return ProgressSupportService.smartReminderMessage(
            checkIns: allCheckIns,
            reminderTime: settings?.reminderTime
        )
    }
    private var recoveryPlanStatus: RecoveryPlanStatus? {
        ProgressSupportService.recoveryPlanStatus(
            startDate: settings?.recoveryPlanStartDate,
            checkIns: allCheckIns
        )
    }
    private var hasInsightsContent: Bool {
        showReturnBanner || showFluctuationBanner || smartReminderMessage != nil || recoveryPlanStatus != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: 20) {
                        if hasInsightsContent {
                            insightsCard
                        }
                        if !photoFirstMode {
                            weightCard
                        }
                        photosCard
                        optionalDetailsCard
                        saveButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .background(NeonTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedInput = nil
                    }
                }
            }
            .onAppear {
                loadToday()
                updateReturnBanner()
                if showReturnBanner || showFluctuationBanner {
                    showInsights = true
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: currentCheckIn?.weight) { _, _ in updateFluctuationBanner() }
            .onChange(of: weightText) { _, _ in updateFluctuationBanner() }
            .overlay(alignment: .bottom) {
                if loggedToast { loggedToastView }
            }
            .sheet(isPresented: $showWeightSheet) {
                weightEntrySheet
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            NeonIconBadge(systemName: "chart.line.uptrend.xyaxis", size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("Track Your Progress")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(NeonTheme.textPrimary)
                Text(formattedToday)
                    .font(.subheadline)
                    .foregroundStyle(NeonTheme.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                streakHeaderBadge
                if photoFirstMode {
                    Button {
                        showWeightSheet = true
                    } label: {
                        Text("Add weight")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(NeonTheme.accent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
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

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private var streakHeaderBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.caption.weight(.bold))
            Text("\(streakStats.current)d")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NeonTheme.accent)
        .clipShape(Capsule())
    }

    private func smartReminderCard(message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.body)
                .foregroundStyle(NeonTheme.accent)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(NeonTheme.textSecondary)
            Spacer(minLength: 8)
        }
        .padding(16)
        .neonCard(background: NeonTheme.surface, border: NeonTheme.accent.opacity(0.25))
    }

    private func recoveryPlanCard(status: RecoveryPlanStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: status.isComplete ? "checkmark.seal.fill" : "heart.text.square.fill")
                    .font(.body)
                    .foregroundStyle(status.isComplete ? NeonTheme.accent : NeonTheme.textSecondary)
                Text(status.isComplete ? "Recovery plan complete" : "3-day recovery plan")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
            }
            HStack(spacing: 8) {
                ForEach(status.days) { day in
                    VStack(spacing: 6) {
                        Text(day.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(day.isComplete ? Color.black : NeonTheme.textTertiary)
                        Text(shortDate(day.date))
                            .font(.caption2)
                            .foregroundStyle(day.isComplete ? Color.black.opacity(0.7) : NeonTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: NeonTheme.cornerSmall, style: .continuous)
                            .fill(day.isComplete ? NeonTheme.accent : NeonTheme.surfaceAlt)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NeonTheme.cornerSmall, style: .continuous)
                            .stroke(day.isComplete ? Color.clear : NeonTheme.borderStrong, lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .neonCard(background: NeonTheme.surface, border: NeonTheme.accent.opacity(0.25))
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $showInsights) {
                VStack(spacing: 10) {
                    if showReturnBanner {
                        returnBanner
                    }
                    if showFluctuationBanner {
                        fluctuationBanner
                    }
                    if let smartReminderMessage {
                        smartReminderCard(message: smartReminderMessage)
                    }
                    if let recoveryPlanStatus {
                        recoveryPlanCard(status: recoveryPlanStatus)
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
                        Text("Helpful nudges and reminders")
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

    private var returnBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.wave")
                .font(.body)
                .foregroundStyle(NeonTheme.textSecondary)
            Text("Welcome back. Let's just log today.")
                .font(.subheadline)
                .foregroundStyle(NeonTheme.textSecondary)
            Spacer(minLength: 8)
            Button("Dismiss") {
                dismissReturnBanner()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(NeonTheme.textTertiary)
        }
        .padding(16)
        .neonCard(background: NeonTheme.surface, border: NeonTheme.border)
    }

    private func updateReturnBanner() {
        showReturnBanner = EngagementService.shouldShowReturnBanner(
            lastCheckInDate: lastCheckInDate,
            returnBannerDismissedAt: settings?.returnBannerDismissedAt
        )
    }

    private func dismissReturnBanner() {
        guard let s = settingsList.first else { return }
        s.returnBannerDismissedAt = Date()
        try? modelContext.save()
        showReturnBanner = false
    }

    private var fluctuationBanner: some View {
        let dismissed = settings?.fluctuationBannerDismissedDateStrings.contains(todayDateString) ?? false
        return Group {
            if !dismissed {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(NeonTheme.textSecondary)
                    Text(InsightService.fluctuationBannerMessage(unit: weightUnit))
                        .font(.subheadline)
                        .foregroundStyle(NeonTheme.textSecondary)
                    Spacer(minLength: 8)
                    Button("Dismiss") {
                        dismissFluctuationBanner()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NeonTheme.textTertiary)
                }
                .padding(16)
                .neonCard(background: NeonTheme.surface, border: NeonTheme.border)
            }
        }
    }

    private var weightEntrySheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.title2.weight(.medium))
                    .focused($focusedInput, equals: .sheetWeight)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .background(NeonTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                    .foregroundStyle(NeonTheme.textPrimary)
                Spacer()
            }
            .padding(24)
            .background(NeonTheme.background)
            .navigationTitle("Add weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showWeightSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        focusedInput = nil
                        hasChanges = true
                        showWeightSheet = false
                    }
                }
            }
        }
    }

    private var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func updateFluctuationBanner() {
        let todayRaw = Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines))
        let raw = todayRaw.flatMap { $0.isFinite ? $0 : nil }
        showFluctuationBanner = InsightService.shouldShowFluctuationBanner(
            todayRaw: raw ?? currentCheckIn?.weight,
            lastRaw: previousDayWeight,
            unit: weightUnit,
            dismissedDateString: settings?.fluctuationBannerDismissedDateStrings.contains(todayDateString) == true ? todayDateString : nil
        )
    }

    private func dismissFluctuationBanner() {
        guard let settings = settingsList.first else { return }
        if !settings.fluctuationBannerDismissedDateStrings.contains(todayDateString) {
            settings.fluctuationBannerDismissedDateStrings.append(todayDateString)
            try? modelContext.save()
        }
        showFluctuationBanner = false
    }

    private var weightCard: some View {
        HStack(alignment: .top, spacing: 14) {
            NeonIconBadge(systemName: "scalemass", size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text("Today's Weight")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeonTheme.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .bold))
                        .focused($focusedInput, equals: .weight)
                        .foregroundStyle(NeonTheme.textPrimary)
                        .onChange(of: weightText) { _, _ in hasChanges = true }
                    Text(weightUnit.rawValue)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(NeonTheme.textTertiary)
                }
            }
            Spacer()
        }
        .padding(24)
        .neonCard()
    }

    private var photosCard: some View {
        let posesToShow: [Pose] = photoMode == .threePose ? Pose.allCases : [settings?.preferredPoseSingle ?? .front]
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: max(1, min(3, posesToShow.count)))

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "camera", size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress Photos")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text("Capture your transformation")
                        .font(.caption)
                        .foregroundStyle(NeonTheme.textTertiary)
                }
            }

            if alignmentAssistEnabled {
                Text("Alignment assist on - keep camera angle and distance similar.")
                    .font(.caption)
                    .foregroundStyle(NeonTheme.textTertiary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(posesToShow, id: \.self) { pose in
                    photoTile(pose: pose, selectedItem: binding(for: pose))
                }
            }
        }
        .padding(24)
        .neonCard()
    }

    private func photoTile(pose: Pose, selectedItem: Binding<PhotosPickerItem?>) -> some View {
        let path = currentCheckIn?.photoPath(for: pose)
        let previousPath = alignmentAssistEnabled ? previousPhotoPath(for: pose) : nil

        return PhotosPicker(
            selection: selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .fill(NeonTheme.surfaceAlt)
                    .overlay {
                        if path == nil {
                            RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundStyle(NeonTheme.borderStrong)
                        }
                    }

                if let path, let img = ImageStore.shared.loadImage(path: path) {
                    img
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                        .overlay {
                            if alignmentAssistEnabled {
                                alignmentGrid
                                    .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                                    .opacity(0.22)
                            }
                        }
                } else if let previousPath, let reference = ImageStore.shared.loadImage(path: previousPath) {
                    reference
                        .resizable()
                        .scaledToFill()
                        .opacity(0.18)
                        .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                    if alignmentAssistEnabled {
                        alignmentGrid
                            .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                            .opacity(0.35)
                    }
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.title2)
                            .foregroundStyle(NeonTheme.textTertiary)
                        Text(pose.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(NeonTheme.textTertiary)
                        Text("Align to last shot")
                            .font(.caption2)
                            .foregroundStyle(NeonTheme.textTertiary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.title2)
                            .foregroundStyle(NeonTheme.textTertiary)
                        Text(pose.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(NeonTheme.textTertiary)
                    }
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .onChange(of: selectedItem.wrappedValue) { _, newItem in
            if newItem != nil { hasChanges = true }
            Task { await processPhoto(for: pose, item: newItem) }
        }
        .contextMenu {
            if path != nil {
                Button("Remove") {
                    removePhoto(for: pose)
                }
            }
        }
    }

    private var alignmentGrid: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            Path { path in
                for step in 1...2 {
                    let x = width * CGFloat(step) / 3
                    let y = height * CGFloat(step) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(NeonTheme.borderStrong.opacity(0.65), lineWidth: 1)
        }
    }

    private func previousPhotoPath(for pose: Pose) -> String? {
        guard let currentDate = currentCheckIn?.date else { return nil }
        return allCheckIns
            .filter { $0.id != currentCheckIn?.id && $0.date < currentDate }
            .sorted { $0.date > $1.date }
            .compactMap { $0.photoPath(for: pose) }
            .first
    }

    private var optionalDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $showOptionalDetails) {
                VStack(alignment: .leading, spacing: 18) {
                    winsSection
                    Divider().overlay(NeonTheme.borderStrong)
                    measurementsSection
                    Divider().overlay(NeonTheme.borderStrong)
                    noteSection
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 10) {
                    NeonIconBadge(systemName: "slider.horizontal.3", size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Optional Details")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(NeonTheme.textPrimary)
                        Text("Wins, measurements, and notes")
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

    private var winsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Non-Scale Wins")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NeonTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(CheckInTag.allCases.filter { $0 != .custom }, id: \.self) { tag in
                    let raw = tag.rawValue
                    let selected = selectedTagRawValues.contains(raw)
                    Button {
                        if selected { selectedTagRawValues.remove(raw) } else { selectedTagRawValues.insert(raw) }
                        hasChanges = true
                    } label: {
                        Text(tag.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected ? Color.black : NeonTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule().fill(selected ? NeonTheme.accent : NeonTheme.surfaceAlt)
                            )
                            .overlay(
                                Capsule().stroke(selected ? Color.clear : NeonTheme.borderStrong, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Other", text: $customTagText)
                .font(.subheadline)
                .padding(12)
                .background(NeonTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                        .stroke(NeonTheme.borderStrong, lineWidth: 1)
                )
                .foregroundStyle(NeonTheme.textPrimary)
                .onChange(of: customTagText) { _, _ in hasChanges = true }
        }
    }

    private var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Measurements")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NeonTheme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Waist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NeonTheme.textTertiary)
                HStack {
                    TextField("0", text: $waistText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.bold))
                        .focused($focusedInput, equals: .waist)
                        .foregroundStyle(NeonTheme.textPrimary)
                        .onChange(of: waistText) { _, _ in hasChanges = true }
                    Spacer()
                    Text(weightUnit.rawValue)
                        .font(.caption)
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
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NeonTheme.textPrimary)
            TextField("Add a note", text: $noteText, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(NeonTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                        .stroke(NeonTheme.borderStrong, lineWidth: 1)
                )
                .foregroundStyle(NeonTheme.textPrimary)
                .onChange(of: noteText) { _, _ in hasChanges = true }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save Today's Progress")
                .font(.headline.weight(.bold))
                .foregroundStyle(hasChanges ? Color.black : NeonTheme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(hasChanges ? NeonTheme.accent : NeonTheme.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous))
                .shadow(color: hasChanges ? NeonTheme.accent.opacity(0.4) : Color.clear, radius: 16, x: 0, y: 8)
        }
        .disabled(!hasChanges)
    }

    private var loggedToastView: some View {
        Text("Logged")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(NeonTheme.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(NeonTheme.surface)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
            .padding(.bottom, 40)
    }

    private func loadToday() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        if let existing = allCheckIns.first(where: { $0.date >= startOfToday && $0.date < endOfToday }) {
            currentCheckIn = existing
            weightText = existing.weight.map { formatWeight($0) } ?? ""
            noteText = existing.note ?? ""
            waistText = existing.waistMeasurement.map { formatWeight($0) } ?? ""
            selectedTagRawValues = Set(existing.tagRawValues)
            customTagText = existing.tagRawValues.first(where: { $0.hasPrefix("custom:") }).map { String($0.dropFirst(7)) } ?? ""
            if let last = lastWeight, existing.weight == nil {
                weightText = formatWeight(last)
            }
            updateFluctuationBanner()
        } else {
            let new = CheckIn(date: startOfToday)
            currentCheckIn = new
            isNewCheckIn = true
            weightText = lastWeight.map { formatWeight($0) } ?? ""
            noteText = ""
            waistText = ""
            selectedTagRawValues = []
            customTagText = ""
            hasChanges = true
        }
    }

    private func formatWeight(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func processPhoto(for pose: Pose, item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let checkIn = currentCheckIn else { return }
        if let oldPath = checkIn.photoPath(for: pose) {
            ImageStore.shared.delete(path: oldPath)
        }
        if let path = ImageStore.shared.save(imageData: data, checkinID: checkIn.id, pose: pose) {
            await MainActor.run {
                checkIn.setPhotoPath(path, for: pose)
                hasChanges = true
            }
        }
    }

    private func removePhoto(for pose: Pose) {
        guard let checkIn = currentCheckIn, let path = checkIn.photoPath(for: pose) else { return }
        ImageStore.shared.delete(path: path)
        checkIn.setPhotoPath(nil, for: pose)
        switch pose {
        case .front: selectedFront = nil
        case .side: selectedSide = nil
        case .back: selectedBack = nil
        }
        hasChanges = true
    }

    private func binding(for pose: Pose) -> Binding<PhotosPickerItem?> {
        switch pose {
        case .front: return $selectedFront
        case .side: return $selectedSide
        case .back: return $selectedBack
        }
    }

    private func save() {
        focusedInput = nil
        guard let checkIn = currentCheckIn else { return }
        if isNewCheckIn {
            modelContext.insert(checkIn)
            isNewCheckIn = false
        }
        let weight: Double? = Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines))
        checkIn.weight = weight?.isFinite == true ? weight : nil
        checkIn.note = noteText.isEmpty ? nil : noteText
        checkIn.waistMeasurement = Double(waistText.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isFinite ? $0 : nil }
        checkIn.tagRawValues = Array(selectedTagRawValues) + (customTagText.isEmpty ? [] : ["custom:\(customTagText)"])
        maybeStartRecoveryPlan()
        try? modelContext.save()
        if settings?.appleHealthSyncEnabled == true {
            Task { @MainActor in
                let synced = await HealthSyncService.syncWeightIfNeeded(checkIn: checkIn, settings: settings)
                if synced {
                    try? modelContext.save()
                }
            }
        }
        hasChanges = false
        showReturnBanner = false
        showLoggedFeedback()
        updateReturnBanner()
    }

    private func maybeStartRecoveryPlan() {
        guard let settings else { return }
        let shouldStart = ProgressSupportService.shouldStartRecoveryPlan(
            lastCheckInDate: lastCheckInDate,
            existingStartDate: settings.recoveryPlanStartDate
        )
        if shouldStart {
            settings.recoveryPlanStartDate = Calendar.current.startOfDay(for: Date())
        }
    }

    private func showLoggedFeedback() {
        loggedToast = true
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { loggedToast = false }
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    CheckInView()
        .modelContainer(for: [CheckIn.self, UserSettings.self], inMemory: true)
}

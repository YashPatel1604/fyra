//
//  CheckInView.swift
//  Fyra
//

import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .reverse) private var allCheckIns: [CheckIn]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allWorkouts: [WorkoutSession]
    @Query private var settingsList: [UserSettings]
    @FocusState private var focusedInput: FocusInput?

    @State private var currentCheckIn: CheckIn?
    @State private var isNewCheckIn: Bool = false
    @State private var weightText: String = ""
    @State private var noteText: String = ""
    @State private var waistText: String = ""
    @State private var selectedTagRawValues: Set<String> = []
    @State private var customTagText: String = ""
    @State private var poseForPhotoSource: Pose?
    @State private var poseForImagePicker: Pose?
    @State private var pickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showImagePicker: Bool = false
    @State private var showCameraPermissionAlert: Bool = false
    @State private var showCameraUnavailableAlert: Bool = false
    @State private var hasChanges: Bool = false
    @State private var loggedToast: Bool = false
    @State private var showFluctuationBanner: Bool = false
    @State private var showReturnBanner: Bool = false
    @State private var showInsights = false
    @State private var showOptionalDetails = false
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var weekOffset: Int = 0

    private enum FocusInput {
        case weight
        case waist
    }

    private var calendar: Calendar { .current }
    private var mondayCalendar: Calendar {
        var c = calendar
        c.firstWeekday = 2
        return c
    }
    private var settings: UserSettings? { settingsList.first }
    private var lastCheckInDate: Date? {
        allCheckIns.first(where: { $0.hasAnyContent })?.date
    }
    private var isSelectedDateToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: Date())
    }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }
    private var photoMode: PhotoMode { settings?.photoMode ?? .single }
    private var alignmentAssistEnabled: Bool { settings?.alignmentAssistEnabled ?? true }
    private var smartRemindersEnabled: Bool { settings?.smartRemindersEnabled ?? true }
    private var loggedCheckInDays: Set<Date> {
        Set(allCheckIns.filter(\.hasAnyContent).map { calendar.startOfDay(for: $0.date) })
    }
    private var startOfCurrentWeek: Date {
        weekStart(for: Date())
    }
    private var displayedWeekStart: Date {
        calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfCurrentWeek) ?? startOfCurrentWeek
    }
    private var weekDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: displayedWeekStart) }
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
        isSelectedDateToday && (showReturnBanner || showFluctuationBanner || smartReminderMessage != nil || recoveryPlanStatus != nil)
    }
    private var workoutsForCurrentDay: [WorkoutSession] {
        guard let date = currentCheckIn?.date else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return allWorkouts.filter { $0.date >= start && $0.date < end }
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
                        weightCard
                        workoutsCard
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
                        dismissKeyboard()
                    }
                }
            }
            .onAppear {
                selectedDate = calendar.startOfDay(for: Date())
                weekOffset = 0
                loadCheckIn(for: selectedDate)
                updateReturnBanner()
                if hasInsightsContent {
                    showInsights = true
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: selectedDate) { _, newValue in
                loadCheckIn(for: newValue)
                updateReturnBanner()
                showInsights = isSelectedDateToday && hasInsightsContent
            }
            .onChange(of: currentCheckIn?.weight) { _, _ in updateFluctuationBanner() }
            .onChange(of: weightText) { _, _ in updateFluctuationBanner() }
            .overlay(alignment: .bottom) {
                if loggedToast { loggedToastView }
            }
            .sheet(isPresented: $showImagePicker, onDismiss: {
                poseForImagePicker = nil
            }) {
                if let poseForImagePicker {
                    SystemImagePicker(sourceType: pickerSourceType) { image in
                        processPickedImage(image, for: poseForImagePicker)
                        self.poseForImagePicker = nil
                    } onCancel: {
                        self.poseForImagePicker = nil
                    }
                }
            }
            .confirmationDialog(
                "Add Progress Photo",
                isPresented: Binding(
                    get: { poseForPhotoSource != nil },
                    set: { isPresented in
                        if !isPresented { poseForPhotoSource = nil }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let poseForPhotoSource {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take \(poseForPhotoSource.displayName) Photo") {
                            presentCamera(for: poseForPhotoSource)
                        }
                    }
                    Button("Choose from Library") {
                        presentLibrary(for: poseForPhotoSource)
                    }
                    if currentCheckIn?.photoPath(for: poseForPhotoSource) != nil {
                        Button("Remove Photo", role: .destructive) {
                            removePhoto(for: poseForPhotoSource)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let poseForPhotoSource {
                    Text("Select how to add your \(poseForPhotoSource.displayName.lowercased()) photo.")
                }
            }
            .alert("Camera Access Needed", isPresented: $showCameraPermissionAlert) {
                Button("Not now", role: .cancel) {}
                Button("Open Settings") {
                    openAppSettings()
                }
            } message: {
                Text("Allow camera access in Settings to take progress photos in-app.")
            }
            .alert("Camera Unavailable", isPresented: $showCameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This device does not have an available camera.")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "chart.line.uptrend.xyaxis", size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track Your Progress")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text(formattedSelectedDate)
                        .font(.subheadline)
                        .foregroundStyle(NeonTheme.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    streakHeaderBadge
                }
            }

            weekTimelineHeader
            weekTimelineStrip
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

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
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

    private var weekTimelineStrip: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let itemWidth = max(42, (proxy.size.width - spacing * 6) / 7)

            HStack(spacing: spacing) {
                ForEach(weekDates, id: \.self) { day in
                    weekDayCell(for: day)
                        .frame(width: itemWidth)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 90)
    }

    private var weekTimelineHeader: some View {
        HStack(spacing: 12) {
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(NeonTheme.surfaceAlt)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(NeonTheme.borderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(weekRangeLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NeonTheme.textSecondary)

            Spacer()

            Button {
                shiftWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NeonTheme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(NeonTheme.surfaceAlt)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(NeonTheme.borderStrong, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(weekOffset == 0)
            .opacity(weekOffset == 0 ? 0.45 : 1)
        }
    }

    private func weekDayCell(for day: Date) -> some View {
        let dayStart = calendar.startOfDay(for: day)
        let isSelected = calendar.isDate(dayStart, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(dayStart)
        let isFuture = dayStart > calendar.startOfDay(for: Date())
        let isLogged = loggedCheckInDays.contains(dayStart)
        let ringColor: Color = isLogged ? NeonTheme.accent : (isSelected ? NeonTheme.borderStrong : NeonTheme.border)

        return Button {
            selectedDate = dayStart
        } label: {
            VStack(spacing: 8) {
                Text(weekdayShortLabel(dayStart))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? NeonTheme.textPrimary : NeonTheme.textTertiary)

                ZStack {
                    Circle()
                        .stroke(
                            ringColor.opacity(isFuture ? 0.5 : 1.0),
                            style: StrokeStyle(lineWidth: 2, dash: isLogged || isSelected || isFuture ? [] : [4, 4])
                        )
                        .frame(width: 38, height: 38)

                    Text(dayNumberString(dayStart))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isFuture ? NeonTheme.textTertiary : NeonTheme.textPrimary)
                }
                .overlay(alignment: .bottomTrailing) {
                    if isToday {
                        Circle()
                            .fill(NeonTheme.accent)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: 2)
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .fill(isSelected ? NeonTheme.background : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                    .stroke(isSelected ? NeonTheme.borderStrong : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.55 : 1)
    }

    private func weekdayShortLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayNumberString(_ date: Date) -> String {
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }

    private var weekRangeLabel: String {
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: displayedWeekStart) else { return "" }
        let start = shortDate(displayedWeekStart)
        let end: String
        if calendar.component(.month, from: displayedWeekStart) == calendar.component(.month, from: weekEnd) {
            end = "\(calendar.component(.day, from: weekEnd))"
        } else {
            end = shortDate(weekEnd)
        }
        return "\(start) - \(end)"
    }

    private func weekStart(for date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        return mondayCalendar.date(from: mondayCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day)) ?? day
    }

    private func shiftWeek(by delta: Int) {
        let newOffset = min(0, weekOffset + delta)
        guard newOffset != weekOffset else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            weekOffset = newOffset
        }

        guard let shifted = calendar.date(byAdding: .day, value: delta * 7, to: selectedDate) else {
            selectedDate = calendar.startOfDay(for: Date())
            return
        }

        let shiftedStart = calendar.startOfDay(for: shifted)
        let todayStart = calendar.startOfDay(for: Date())
        selectedDate = shiftedStart > todayStart ? todayStart : shiftedStart
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
        guard isSelectedDateToday else {
            showReturnBanner = false
            return
        }
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

    private var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func updateFluctuationBanner() {
        guard isSelectedDateToday else {
            showFluctuationBanner = false
            return
        }
        let todayRaw = Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines))
        let raw = todayRaw.flatMap { $0.isFinite ? $0 : nil }
        showFluctuationBanner = InsightService.shouldShowFluctuationBanner(
            todayRaw: raw ?? currentCheckIn?.weight,
            lastRaw: previousWeight(before: selectedDate),
            unit: weightUnit,
            dismissedDateString: settings?.fluctuationBannerDismissedDateStrings.contains(todayDateString) == true ? todayDateString : nil
        )
    }

    private func dismissFluctuationBanner() {
        guard isSelectedDateToday else {
            showFluctuationBanner = false
            return
        }
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
                Text(weightCardTitle)
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

    private var weightCardTitle: String {
        isSelectedDateToday ? "Today's Weight" : "Weight for \(shortDate(selectedDate))"
    }

    private var workoutsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "figure.run", size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workouts")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text("Imported from Apple Health")
                        .font(.caption)
                        .foregroundStyle(NeonTheme.textTertiary)
                }
            }

            if workoutsForCurrentDay.isEmpty {
                Text("No workouts logged for this day yet.")
                    .font(.subheadline)
                    .foregroundStyle(NeonTheme.textTertiary)
            } else {
                VStack(spacing: 10) {
                    ForEach(workoutsForCurrentDay) { workout in
                        let activityName = displayActivityName(for: workout.activityName)
                        HStack(alignment: .top, spacing: 10) {
                            NeonIconBadge(systemName: workoutIconName(for: activityName), size: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(activityName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(NeonTheme.textPrimary)
                                Text(formattedWorkoutTime(workout.date))
                                    .font(.caption)
                                    .foregroundStyle(NeonTheme.textTertiary)
                                HStack(spacing: 8) {
                                    Text(workoutDurationText(workout.durationMinutes))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(NeonTheme.textSecondary)
                                    if let kcal = workout.activeEnergyKcal {
                                        Text("\(Int(kcal.rounded())) kcal")
                                            .font(.caption)
                                            .foregroundStyle(NeonTheme.textSecondary)
                                    }
                                    Text(workout.sourceName)
                                        .font(.caption2)
                                        .foregroundStyle(NeonTheme.textTertiary)
                                }
                            }
                            Spacer()
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
                    photoTile(pose: pose)
                }
            }
        }
        .padding(24)
        .neonCard()
    }

    private func photoTile(pose: Pose) -> some View {
        let path = currentCheckIn?.photoPath(for: pose)
        let previousPath = alignmentAssistEnabled ? previousPhotoPath(for: pose) : nil

        return Button {
            poseForPhotoSource = pose
        } label: {
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
        .contextMenu {
            Button("Take Photo") {
                presentCamera(for: pose)
            }
            Button("Choose from Library") {
                presentLibrary(for: pose)
            }
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

    private func presentLibrary(for pose: Pose) {
        poseForPhotoSource = nil
        openImagePicker(sourceType: .photoLibrary, for: pose)
    }

    private func presentCamera(for pose: Pose) {
        poseForPhotoSource = nil
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailableAlert = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            openImagePicker(sourceType: .camera, for: pose)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        openImagePicker(sourceType: .camera, for: pose)
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            showCameraPermissionAlert = true
        }
    }

    private func openImagePicker(sourceType: UIImagePickerController.SourceType, for pose: Pose) {
        poseForImagePicker = pose
        pickerSourceType = sourceType
        showImagePicker = true
    }

    private func processPickedImage(_ image: UIImage, for pose: Pose) {
        guard let checkIn = currentCheckIn else { return }
        if let oldPath = checkIn.photoPath(for: pose) {
            ImageStore.shared.delete(path: oldPath)
        }
        if let path = ImageStore.shared.save(image: image, checkinID: checkIn.id, pose: pose) {
            checkIn.setPhotoPath(path, for: pose)
            hasChanges = true
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
                    Text(weightUnit.waistUnitSymbol)
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
            Text(saveButtonTitle)
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

    private var saveButtonTitle: String {
        isSelectedDateToday ? "Save Today's Progress" : "Save Progress for \(shortDate(selectedDate))"
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

    private func loadCheckIn(for date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let priorWeight = previousWeight(before: dayStart)

        if let existing = allCheckIns.first(where: { $0.date >= dayStart && $0.date < dayEnd }) {
            currentCheckIn = existing
            isNewCheckIn = false
            weightText = existing.weight.map { formatWeight($0) } ?? ""
            noteText = existing.note ?? ""
            waistText = existing.waistMeasurement.map { formatWeight($0) } ?? ""
            selectedTagRawValues = Set(existing.tagRawValues)
            customTagText = existing.tagRawValues.first(where: { $0.hasPrefix("custom:") }).map { String($0.dropFirst(7)) } ?? ""
            if let priorWeight, existing.weight == nil {
                weightText = formatWeight(priorWeight)
            }
            hasChanges = false
        } else {
            let new = CheckIn(date: dayStart)
            currentCheckIn = new
            isNewCheckIn = true
            weightText = priorWeight.map { formatWeight($0) } ?? ""
            noteText = ""
            waistText = ""
            selectedTagRawValues = []
            customTagText = ""
            hasChanges = true
        }
        updateFluctuationBanner()
    }

    private func previousWeight(before day: Date) -> Double? {
        let dayStart = calendar.startOfDay(for: day)
        return allCheckIns.first(where: { checkIn in
            guard checkIn.weight != nil else { return false }
            return calendar.startOfDay(for: checkIn.date) < dayStart
        })?.weight
    }

    private func formatWeight(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func removePhoto(for pose: Pose) {
        guard let checkIn = currentCheckIn, let path = checkIn.photoPath(for: pose) else { return }
        ImageStore.shared.delete(path: path)
        checkIn.setPhotoPath(nil, for: pose)
        hasChanges = true
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

    private func workoutIconName(for activity: String) -> String {
        let name = activity.lowercased()
        if name.contains("run") { return "figure.run" }
        if name.contains("walk") || name.contains("hike") { return "figure.walk" }
        if name.contains("cycle") { return "bicycle" }
        if name.contains("swim") { return "figure.pool.swim" }
        if name.contains("row") { return "figure.rower" }
        if name.contains("yoga") { return "figure.yoga" }
        if name.contains("strength") { return "dumbbell" }
        return "figure.mixed.cardio"
    }

    private func displayActivityName(for activity: String) -> String {
        if activity.lowercased().contains("rawvalue") {
            return "Workout"
        }
        return activity
    }

    private func workoutDurationText(_ durationMinutes: Double) -> String {
        let hours = Int(durationMinutes) / 60
        let mins = Int(durationMinutes) % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    private func formattedWorkoutTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
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
        .modelContainer(for: [CheckIn.self, UserSettings.self, WorkoutSession.self], inMemory: true)
}

//
//  TimelineView.swift
//  Fyra
//

import SwiftUI
import SwiftData

struct TimelineView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query private var settingsList: [UserSettings]
    @State private var showDailyPoints: Bool = false
    @State private var selectedRange: WeightGraphRange = .thirtyDays

    private var settings: UserSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }
    private var photoFirstMode: Bool { settings?.photoFirstMode ?? false }
    private var weightTrendService: WeightTrendService {
        WeightTrendService(checkIns: checkIns.reversed(), unit: weightUnit)
    }
    private var rangeWeightedCheckIns: [CheckIn] {
        let end = Date()
        let start = selectedRange.startDate(ending: end) ?? Date.distantPast
        return checkIns.filter { $0.weight != nil && $0.date >= start && $0.date <= end }
    }
    private var rangeTrendService: WeightTrendService {
        WeightTrendService(checkIns: rangeWeightedCheckIns, unit: weightUnit)
    }
    private var trendPoints: [WeightGraphPoint] {
        guard rangeTrendService.count > 0 else { return [] }
        return (0..<rangeTrendService.count).compactMap { idx in
            guard let date = rangeTrendService.date(atIndex: idx),
                  let trend = rangeTrendService.trend(atIndex: idx) else { return nil }
            return WeightGraphPoint(date: date, value: trend)
        }
    }
    private var rawPoints: [WeightGraphPoint] {
        guard rangeTrendService.count > 0 else { return [] }
        return (0..<rangeTrendService.count).compactMap { idx in
            guard let date = rangeTrendService.date(atIndex: idx),
                  let raw = rangeTrendService.rawWeight(atIndex: idx) else { return nil }
            return WeightGraphPoint(date: date, value: raw)
        }
    }
    private var hasEnoughWeightData: Bool {
        trendPoints.count >= 2
    }
    private var weeklyRateText: String? {
        guard let rate = rangeTrendService.weeklyRatePerWeek(unit: weightUnit)?.value else { return nil }
        return WeightTrendService.formatWeeklyRate(rate, unit: weightUnit)
    }
    private var trendChangeText: String? {
        guard let change = rangeTrendService.trendChange() else { return nil }
        return "\(formatSignedChange(change)) \(weightUnit.rawValue)"
    }
    private var uniqueDaysLoggedThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now
        let days = Set(checkIns.filter { $0.hasAnyContent && $0.date >= startOfMonth && $0.date <= endOfMonth }.map { calendar.startOfDay(for: $0.date) })
        return days.count
    }
    private var consistencyLast7Days: Int {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: end)) ?? end
        let days = Set(checkIns.filter { $0.hasAnyContent && $0.date >= start && $0.date <= end }.map { calendar.startOfDay(for: $0.date) })
        return days.count
    }

    private var measurementNudgeMessage: String? {
        let withWaist: [(date: Date, waist: Double)] = checkIns
            .compactMap { c -> (date: Date, waist: Double)? in
                guard let w = c.waistMeasurement else { return nil }
                return (c.date, w)
            }
            .sorted { $0.date < $1.date }
        return InsightService.measurementNudge(
            checkInsWithWaist: withWaist,
            weightTrendService: weightTrendService,
            unit: weightUnit
        )
    }

    private var paceContextMessage: String? {
        let rate = weightTrendService.weeklyRatePerWeek(unit: weightUnit)?.value
        return InsightService.paceContext(
            currentRatePerWeek: rate,
            paceMin: settings?.paceMinPerWeek,
            paceMax: settings?.paceMaxPerWeek,
            goalType: settings?.goalType ?? .none,
            unit: weightUnit
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(spacing: 20) {
                        if checkIns.isEmpty {
                            emptyState
                        } else {
                            content
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }
            }
            .background(NeonTheme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Timeline")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(NeonTheme.textPrimary)
            Text("Your journey at a glance")
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

    private var content: some View {
        VStack(spacing: 20) {
            WeightGraphView(
                trendPoints: trendPoints,
                rawPoints: rawPoints,
                weeklyRateText: weeklyRateText,
                hasEnoughData: hasEnoughWeightData,
                selectedRange: $selectedRange,
                showDailyPoints: $showDailyPoints
            )
            statsGrid
            if measurementNudgeMessage != nil || paceContextMessage != nil {
                insightsCard
            }
            recentCheckIns
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(NeonTheme.surfaceAlt)
                    .frame(width: 72, height: 72)
                Image(systemName: "calendar.badge.plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(NeonTheme.textTertiary)
            }
            Text("No check-ins yet")
                .font(.headline)
                .foregroundStyle(NeonTheme.textPrimary)
            Text("Log a photo or weight on the Check-In tab to see your progress here.")
                .font(.subheadline)
                .foregroundStyle(NeonTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .neonCard()
    }

    private var rangeChangeLabel: String {
        selectedRange == .all ? "All-time Change" : "\(selectedRange.pickerLabel) Change"
    }

    private var consistencyPercentText: String? {
        guard consistencyLast7Days > 0 else { return nil }
        let percent = Int(round(Double(consistencyLast7Days) / 7.0 * 100.0))
        return "\(percent)%"
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            statCard(
                icon: "scope",
                title: rangeChangeLabel,
                value: trendChangeText ?? "—"
            )
            statCard(
                icon: "chart.line.downtrend.xyaxis",
                title: "Weekly Rate",
                value: weeklyRateText ?? "—"
            )
            statCard(
                icon: "calendar",
                title: "This Month",
                value: "\(uniqueDaysLoggedThisMonth) days"
            )
            statCard(
                icon: "bolt",
                title: "Consistency",
                value: consistencyPercentText ?? "—"
            )
        }
    }

    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NeonIconBadge(systemName: icon, size: 40)
            Text(title)
                .font(.caption)
                .foregroundStyle(NeonTheme.textTertiary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(NeonTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .neonCard()
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text("💡")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 6) {
                    if let msg = measurementNudgeMessage {
                        Text(msg)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(NeonTheme.textPrimary)
                    }
                    if let msg = paceContextMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(NeonTheme.textSecondary)
                    }
                }
            }
        }
        .padding(20)
        .neonCard(
            background: NeonTheme.surface,
            border: NeonTheme.accent.opacity(0.3),
            shadowColor: NeonTheme.accent.opacity(0.2)
        )
    }

    private var recentCheckIns: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Check-ins".uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(NeonTheme.textTertiary)
                .padding(.horizontal, 4)

            LazyVStack(spacing: 12) {
                ForEach(checkIns) { checkIn in
                    NavigationLink {
                        CheckInDetailView(checkIn: checkIn)
                    } label: {
                        TimelineRowView(
                            checkIn: checkIn,
                            weightUnit: weightUnit,
                            showDailyPoints: showDailyPoints,
                            weightTrendService: weightTrendService,
                            showWeight: !photoFirstMode,
                            isBaseline: settings?.baselineCheckInID == checkIn.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formatSignedChange(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct TimelineRowView: View {
    let checkIn: CheckIn
    let weightUnit: WeightUnit
    var showDailyPoints: Bool = false
    var weightTrendService: WeightTrendService?
    var showWeight: Bool = true
    var isBaseline: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                if let path = checkIn.primaryPhotoPath, let img = ImageStore.shared.loadImage(path: path) {
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(NeonTheme.surfaceAlt)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "camera")
                                .font(.title3)
                                .foregroundStyle(NeonTheme.textTertiary)
                        }
                }
                if isBaseline {
                    ZStack {
                        Circle()
                            .fill(NeonTheme.accent)
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.black)
                    }
                    .frame(width: 22, height: 22)
                    .offset(x: 6, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(formattedDate(checkIn.date))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NeonTheme.textPrimary)
                if showWeight, let display = weightDisplay {
                    Text(display)
                        .font(.caption)
                        .foregroundStyle(NeonTheme.textSecondary)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(NeonTheme.surfaceAlt)
                    .frame(width: 32, height: 32)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NeonTheme.textTertiary)
            }
        }
        .padding(16)
        .neonCard()
    }

    private var weightDisplay: String? {
        guard showWeight else { return nil }
        guard let service = weightTrendService else {
            return checkIn.weight.map { "\(formatWeight($0)) \(weightUnit.rawValue)" }
        }
        if showDailyPoints, let raw = checkIn.weight {
            return "\(formatWeight(raw)) \(weightUnit.rawValue)"
        }
        if let idx = service.index(forDay: checkIn.date), let trend = service.trend(atIndex: idx) {
            return "\(formatWeight(trend)) \(weightUnit.rawValue) trend"
        }
        return checkIn.weight.map { "\(formatWeight($0)) \(weightUnit.rawValue)" }
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
    TimelineView()
        .modelContainer(for: [CheckIn.self, UserSettings.self, ProgressPeriod.self], inMemory: true)
}

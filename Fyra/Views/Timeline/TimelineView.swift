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
            Group {
                if checkIns.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No check-ins yet", systemImage: "calendar.badge.plus")
        } description: {
            Text("Log a photo or weight on the Check-In tab to see your progress here.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listContent: some View {
        List {
            Section {
                WeightGraphView(
                    trendPoints: trendPoints,
                    rawPoints: rawPoints,
                    weeklyRateText: weeklyRateText,
                    hasEnoughData: hasEnoughWeightData,
                    selectedRange: $selectedRange,
                    showDailyPoints: $showDailyPoints
                )
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section("Metrics") {
                if let trendChangeText {
                    HStack {
                        Text("\(selectedRange.metricLabel) trend change")
                            .font(.subheadline)
                        Spacer()
                        Text(trendChangeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if let weeklyRateText {
                    HStack {
                        Text("Weekly rate")
                            .font(.subheadline)
                        Spacer()
                        Text(weeklyRateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Days logged this month")
                        .font(.subheadline)
                    Spacer()
                    Text("\(uniqueDaysLoggedThisMonth)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if consistencyLast7Days > 0 {
                    HStack {
                        Text("Consistency (last 7 days)")
                            .font(.subheadline)
                        Spacer()
                        Text("\(consistencyLast7Days)/7")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            if measurementNudgeMessage != nil || paceContextMessage != nil {
                Section("Notes") {
                    if let msg = measurementNudgeMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let msg = paceContextMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }

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
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }
        }
        .listStyle(.insetGrouped)
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
        HStack(spacing: AppTheme.itemSpacing) {
            if let path = checkIn.primaryPhotoPath, let img = ImageStore.shared.loadImage(path: path) {
                img
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            } else {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.body)
                            .foregroundStyle(.quaternary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(formattedDate(checkIn.date))
                        .font(.subheadline.weight(.medium))
                    if isBaseline {
                        Text("Baseline")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                }
                if showWeight, let display = weightDisplay {
                    Text(display)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
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

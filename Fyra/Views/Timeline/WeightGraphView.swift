//
//  WeightGraphView.swift
//  Fyra
//

import SwiftUI
import Charts

enum WeightGraphRange: String, CaseIterable, Identifiable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case sixMonths
    case oneYear
    case all

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .ninetyDays: return "90D"
        case .sixMonths: return "6M"
        case .oneYear: return "1Y"
        case .all: return "All"
        }
    }

    var metricLabel: String {
        switch self {
        case .sevenDays: return "7-day"
        case .thirtyDays: return "30-day"
        case .ninetyDays: return "90-day"
        case .sixMonths: return "6-month"
        case .oneYear: return "1-year"
        case .all: return "All-time"
        }
    }

    func startDate(ending endDate: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: endDate)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: endDate)
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: endDate)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: endDate)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: endDate)
        case .all:
            return nil
        }
    }
}

struct WeightGraphPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct WeightGraphView: View {
    let trendPoints: [WeightGraphPoint]
    let rawPoints: [WeightGraphPoint]
    let weeklyRateText: String?
    let hasEnoughData: Bool
    @Binding var selectedRange: WeightGraphRange
    @Binding var showDailyPoints: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                NeonIconBadge(systemName: "chart.line.downtrend.xyaxis")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight Trend")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NeonTheme.textPrimary)
                    Text("Track your progress")
                        .font(.caption)
                        .foregroundStyle(NeonTheme.textTertiary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WeightGraphRange.allCases) { range in
                        Button {
                            selectedRange = range
                        } label: {
                            Text(range.pickerLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedRange == range ? Color.black : NeonTheme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedRange == range ? NeonTheme.accent : NeonTheme.surfaceAlt)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedRange == range ? Color.clear : NeonTheme.borderStrong, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            if hasEnoughData {
                ZStack {
                    RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                        .fill(NeonTheme.surfaceAlt)
                    Chart {
                        ForEach(trendPoints) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Trend", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .foregroundStyle(NeonTheme.accent)
                        }
                        if showDailyPoints {
                            ForEach(rawPoints) { point in
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", point.value)
                                )
                                .foregroundStyle(NeonTheme.accent)
                                .symbolSize(26)
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine().foregroundStyle(Color.clear)
                            AxisTick().foregroundStyle(Color.clear)
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(NeonTheme.textTertiary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                                .foregroundStyle(NeonTheme.borderStrong.opacity(0.4))
                            AxisTick().foregroundStyle(Color.clear)
                            AxisValueLabel()
                                .font(.caption2)
                                .foregroundStyle(NeonTheme.textTertiary)
                        }
                    }
                    .padding(14)
                }
                .frame(height: 220)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: NeonTheme.cornerMedium, style: .continuous)
                        .fill(NeonTheme.surfaceAlt)
                    Text("Not enough data yet")
                        .font(.subheadline)
                        .foregroundStyle(NeonTheme.textTertiary)
                }
                .frame(height: 200)
            }

            HStack {
                Text("Show data points")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NeonTheme.textSecondary)
                Spacer()
                NeonToggle(isOn: $showDailyPoints)
                    .opacity(hasEnoughData ? 1 : 0.5)
                    .disabled(!hasEnoughData)
            }

            if let weeklyRateText {
                Text("Trending \(weeklyRateText)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NeonTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(24)
        .neonCard()
    }
}

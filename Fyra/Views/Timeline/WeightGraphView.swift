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
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionLabel("Weight trend")

            Picker("Range", selection: $selectedRange) {
                ForEach(WeightGraphRange.allCases) { range in
                    Text(range.pickerLabel).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if hasEnoughData {
                Chart {
                    ForEach(trendPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Trend", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Color.accentColor)
                    }
                    if showDailyPoints {
                        ForEach(rawPoints) { point in
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Weight", point.value)
                            )
                            .foregroundStyle(.secondary)
                            .symbolSize(22)
                        }
                    }
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                Text("Not enough data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }

            Toggle("Show daily points", isOn: $showDailyPoints)
                .font(.subheadline)
                .disabled(!hasEnoughData)

            if let weeklyRateText {
                Text("Trend: \(weeklyRateText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

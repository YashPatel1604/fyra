//
//  TimelapseGeneratorView.swift
//  Fyra
//

import SwiftUI

enum TimelapseRangeOption: String, CaseIterable, Identifiable {
    case currentPeriod
    case thisMonth
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .currentPeriod: return "Current period"
        case .thisMonth: return "This month"
        case .all: return "All"
        }
    }
}

struct TimelapseGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    let checkIns: [CheckIn]
    let settings: UserSettings?
    let periods: [ProgressPeriod]

    @State private var selectedPose: Pose
    @State private var rangeOption: TimelapseRangeOption = .currentPeriod
    @State private var frameDuration: Double = 0.5
    @State private var overlayWeight: Bool = false
    @State private var isGenerating = false
    @State private var progressText: String?
    @State private var generatedURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    init(checkIns: [CheckIn], settings: UserSettings?, periods: [ProgressPeriod]) {
        self.checkIns = checkIns
        self.settings = settings
        self.periods = periods
        let defaultPose = (settings?.photoMode == .single) ? (settings?.preferredPoseSingle ?? .front) : .front
        _selectedPose = State(initialValue: defaultPose)
    }

    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }
    private var activePeriod: ProgressPeriod? {
        ProgressPeriodService.activePeriod(settings: settings, periods: periods)
    }
    private var selectedRange: DateInterval? {
        switch rangeOption {
        case .currentPeriod:
            if let active = activePeriod {
                return DateInterval(start: active.startDate, end: active.endDate ?? Date())
            }
            return nil
        case .thisMonth:
            let calendar = Calendar.current
            let now = Date()
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return DateInterval(start: start, end: now)
        case .all:
            return nil
        }
    }
    private var frames: [TimelapseFrame] {
        TimelapseService.frames(
            checkIns: checkIns,
            pose: selectedPose,
            range: selectedRange,
            overlayWeight: overlayWeight,
            unit: weightUnit
        )
    }
    private var usesFallbackRange: Bool {
        rangeOption == .currentPeriod && activePeriod == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pose") {
                    Picker("Pose", selection: $selectedPose) {
                        ForEach(Pose.allCases, id: \.self) { pose in
                            Text(pose.displayName).tag(pose)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Range") {
                    Picker("Range", selection: $rangeOption) {
                        ForEach(TimelapseRangeOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    if usesFallbackRange {
                        Text("No active progress period yet — using all photos.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(frames.count) photos in range")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Frame duration") {
                    Picker("Frame duration", selection: $frameDuration) {
                        Text("0.25s").tag(0.25)
                        Text("0.5s").tag(0.5)
                        Text("1.0s").tag(1.0)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Overlays") {
                    Toggle("Overlay weight (trend)", isOn: $overlayWeight)
                }

                Section {
                    Button("Generate") {
                        Task { await generateTimelapse() }
                    }
                    .disabled(isGenerating || frames.count < 2)

                    if let progressText, isGenerating {
                        HStack {
                            ProgressView()
                            Text(progressText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if frames.count < 2 {
                        Text("Not enough photos for this pose yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if frames.count > 200 {
                        Text("Large set — this may take a little while.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Create Timelapse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = generatedURL {
                    ShareSheet(activityItems: [url]) {
                        cleanupTempFile()
                    }
                }
            }
            .alert("Couldn’t generate timelapse", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func generateTimelapse() async {
        guard !isGenerating else { return }
        isGenerating = true
        progressText = "Preparing..."
        do {
            let url = try await TimelapseService.generateVideo(
                frames: frames,
                frameDuration: frameDuration
            ) { current, total in
                progressText = "Generating \(current)/\(total)"
            }
            generatedURL = url
            showShareSheet = true
        } catch {
            errorMessage = "Please try again with a smaller range."
        }
        isGenerating = false
    }

    private func cleanupTempFile() {
        if let url = generatedURL {
            try? FileManager.default.removeItem(at: url)
        }
        generatedURL = nil
    }
}

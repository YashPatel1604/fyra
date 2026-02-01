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

    private var settings: UserSettings? { settingsList.first }
    private var lastCheckInDate: Date? {
        allCheckIns.first(where: { $0.hasAnyContent })?.date
    }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }
    private var photoMode: PhotoMode { settings?.photoMode ?? .single }
    private var photoFirstMode: Bool { settings?.photoFirstMode ?? false }
    private var lastWeight: Double? {
        allCheckIns.first(where: { $0.weight != nil })?.weight
    }
    /// Most recent previous day's weight (for fluctuation banner).
    private var previousDayWeight: Double? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return allCheckIns.first(where: { calendar.startOfDay(for: $0.date) < startOfToday && $0.weight != nil })?.weight
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    if showReturnBanner {
                        returnBanner
                    }
                    if showFluctuationBanner {
                        fluctuationBanner
                    }
                    if !photoFirstMode {
                        weightSection
                    }
                    poseSection
                    tagsSection
                    waistSection
                    noteSection
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if photoFirstMode {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add weight") { showWeightSheet = true }
                    }
                }
            }
            .onAppear {
                loadToday()
                updateReturnBanner()
            }
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

    private var returnBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "hand.wave")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Welcome back. Let's just log today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Dismiss") {
                dismissReturnBanner()
            }
            .font(.caption.weight(.medium))
            .frame(minWidth: AppTheme.minTapTarget, minHeight: AppTheme.minTapTarget)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.cardBackground)
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
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text(InsightService.fluctuationBannerMessage(unit: weightUnit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button("Dismiss") {
                        dismissFluctuationBanner()
                    }
                    .font(.caption.weight(.medium))
                    .frame(minWidth: AppTheme.minTapTarget, minHeight: AppTheme.minTapTarget)
                }
                .padding(AppTheme.cardPadding)
                .background(AppTheme.cardBackground)
            }
        }
    }

    private var weightEntrySheet: some View {
        NavigationStack {
            VStack(spacing: AppTheme.itemSpacing) {
                TextField("Weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.title2.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(AppTheme.cardPadding)
                    .background(AppTheme.inputBackground)
                Spacer()
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showWeightSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppTheme.sectionLabel("Weight")
            TextField("Enter weight", text: $weightText)
                .keyboardType(.decimalPad)
                .font(.title2.weight(.medium))
                .padding(AppTheme.cardPadding)
                .background(AppTheme.inputBackground)
                .onChange(of: weightText) { _, _ in hasChanges = true }
        }
    }

    private var poseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppTheme.sectionLabel("Photos")
            let posesToShow: [Pose] = photoMode == .threePose ? Pose.allCases : [settings?.preferredPoseSingle ?? .front]
            ForEach(posesToShow, id: \.self) { pose in
                poseRow(pose: pose, selectedItem: binding(for: pose))
            }
        }
    }

    private func binding(for pose: Pose) -> Binding<PhotosPickerItem?> {
        switch pose {
        case .front: return $selectedFront
        case .side: return $selectedSide
        case .back: return $selectedBack
        }
    }

    private func poseRow(pose: Pose, selectedItem: Binding<PhotosPickerItem?>) -> some View {
        let path = currentCheckIn?.photoPath(for: pose)
        return HStack(spacing: AppTheme.itemSpacing) {
            ZStack {
                if let path, let img = ImageStore.shared.loadImage(path: path) {
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 84, height: 84)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.quaternary)
                        }
                }
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 6) {
                PhotosPicker(
                    selection: selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(path != nil ? "Replace" : "Add \(pose.displayName)")
                        .font(.subheadline.weight(.medium))
                }
                .onChange(of: selectedItem.wrappedValue) { _, newItem in
                    if newItem != nil { hasChanges = true }
                    Task { await processPhoto(for: pose, item: newItem) }
                }
                if path != nil {
                    Button("Remove") {
                        removePhoto(for: pose)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.sectionLabel("Non-scale wins (optional)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                ForEach(CheckInTag.allCases.filter { $0 != .custom }, id: \.self) { tag in
                    let raw = tag.rawValue
                    let selected = selectedTagRawValues.contains(raw)
                    Button {
                        if selected { selectedTagRawValues.remove(raw) }
                        else { selectedTagRawValues.insert(raw) }
                        hasChanges = true
                    } label: {
                        Text(tag.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.pillBackground(selected: selected))
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField("Other", text: $customTagText)
                .font(.subheadline)
                .padding(14)
                .background(AppTheme.inputBackground)
                .onChange(of: customTagText) { _, _ in hasChanges = true }
        }
    }

    private var waistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppTheme.sectionLabel("Waist (optional)")
            TextField("Measurement", text: $waistText)
                .keyboardType(.decimalPad)
                .font(.body)
                .padding(AppTheme.cardPadding)
                .background(AppTheme.inputBackground)
                .onChange(of: waistText) { _, _ in hasChanges = true }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppTheme.sectionLabel("Note (optional)")
            TextField("Add a note", text: $noteText, axis: .vertical)
                .lineLimit(3...6)
                .padding(AppTheme.cardPadding)
                .background(AppTheme.inputBackground)
                .onChange(of: noteText) { _, _ in hasChanges = true }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .frame(minHeight: AppTheme.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!hasChanges)
        .accessibilityLabel("Save check-in")
    }

    private var loggedToastView: some View {
        Text("Logged")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
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

    private func save() {
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
        try? modelContext.save()
        hasChanges = false
        loggedToast = true
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { loggedToast = false }
        }
    }
}

#Preview {
    CheckInView()
        .modelContainer(for: [CheckIn.self, UserSettings.self], inMemory: true)
}

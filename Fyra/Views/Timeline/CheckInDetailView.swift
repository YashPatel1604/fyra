//
//  CheckInDetailView.swift
//  Fyra
//

import SwiftUI
import SwiftData
import PhotosUI

struct CheckInDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var checkIn: CheckIn
    @Query private var settingsList: [UserSettings]

    @State private var weightText: String = ""
    @State private var noteText: String = ""
    @State private var waistText: String = ""
    @State private var selectedTagRawValues: Set<String> = []
    @State private var customTagText: String = ""
    @State private var selectedFront: PhotosPickerItem?
    @State private var selectedSide: PhotosPickerItem?
    @State private var selectedBack: PhotosPickerItem?
    @State private var hasChanges: Bool = false

    private var settings: UserSettings? { settingsList.first }
    private var weightUnit: WeightUnit { settings?.weightUnit ?? .lb }
    private var photoMode: PhotoMode { settings?.photoMode ?? .single }
    private var isBaseline: Bool { BaselineService.isBaseline(checkIn, settings: settings) }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.sectionSpacing) {
                HStack(spacing: 10) {
                    Text(formattedDate(checkIn.date))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    if isBaseline {
                        Text("Baseline")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)

                baselineSection

                weightSection
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
        .navigationTitle("Edit check-in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                baselineButton
            }
        }
        .onAppear {
            weightText = checkIn.weight.map { formatWeight($0) } ?? ""
            noteText = checkIn.note ?? ""
            waistText = checkIn.waistMeasurement.map { formatWeight($0) } ?? ""
            selectedTagRawValues = Set(checkIn.tagRawValues)
            customTagText = checkIn.tagRawValues.first(where: { $0.hasPrefix("custom:") }).map { String($0.dropFirst(7)) } ?? ""
        }
        .onChange(of: weightText) { _, _ in hasChanges = true }
        .onChange(of: noteText) { _, _ in hasChanges = true }
    }

    private var baselineSection: some View {
        Group {
            if isBaseline {
                HStack {
                    Text("This check-in is your baseline for comparisons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var baselineButton: some View {
        Button(isBaseline ? "Remove baseline" : "Set as baseline") {
            toggleBaseline()
        }
        .font(.subheadline.weight(.medium))
        .accessibilityLabel(isBaseline ? "Remove baseline" : "Set as baseline")
    }

    private func toggleBaseline() {
        guard let s = settingsList.first else { return }
        if isBaseline {
            BaselineService.setBaseline(nil, settings: s)
        } else {
            BaselineService.setBaseline(checkIn.id, settings: s)
        }
        try? modelContext.save()
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppTheme.sectionLabel("Weight (\(weightUnit.rawValue))")
            TextField("Weight", text: $weightText)
                .keyboardType(.decimalPad)
                .font(.title2.weight(.medium))
                .padding(AppTheme.cardPadding)
                .background(AppTheme.inputBackground)
        }
    }

    private var poseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppTheme.sectionLabel("Photos")
            let posesToShow: [Pose] = photoMode == .threePose ? Pose.allCases : [settings?.preferredPoseSingle ?? .front]
            ForEach(posesToShow, id: \.self) { pose in
                detailPoseRow(pose: pose)
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

    private static let poseImageSize: CGFloat = 200

    private func detailPoseRow(pose: Pose) -> some View {
        let path = checkIn.photoPath(for: pose)
        return HStack(alignment: .top, spacing: 16) {
            Group {
                if let path, let img = ImageStore.shared.loadImage(path: path) {
                    img
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: Self.poseImageSize, maxHeight: Self.poseImageSize)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: Self.poseImageSize, height: Self.poseImageSize)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.quaternary)
                        }
                }
            }
            .frame(width: Self.poseImageSize, height: Self.poseImageSize)

            VStack(alignment: .leading, spacing: 8) {
                PhotosPicker(
                    selection: binding(for: pose),
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(path != nil ? "Replace \(pose.displayName)" : "Add \(pose.displayName)")
                        .font(.subheadline.weight(.medium))
                }
                .onChange(of: binding(for: pose).wrappedValue) { _, newItem in
                    if newItem != nil { hasChanges = true }
                    Task { await processPhoto(for: pose, item: newItem) }
                }

                if path != nil {
                    Button("Remove") {
                        removePhoto(for: pose)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
                .padding(AppTheme.cardPadding)
                .background(AppTheme.inputBackground)
                .onChange(of: waistText) { _, _ in hasChanges = true }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppTheme.sectionLabel("Note")
            TextField("Note", text: $noteText, axis: .vertical)
                .lineLimit(3...6)
                .padding(AppTheme.cardPadding)
                .background(AppTheme.inputBackground)
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Save changes")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!hasChanges)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatWeight(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func processPhoto(for pose: Pose, item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
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
        guard let path = checkIn.photoPath(for: pose) else { return }
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
        let weight: Double? = Double(weightText.trimmingCharacters(in: .whitespacesAndNewlines))
        checkIn.weight = weight?.isFinite == true ? weight : nil
        checkIn.note = noteText.isEmpty ? nil : noteText
        checkIn.waistMeasurement = Double(waistText.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isFinite ? $0 : nil }
        checkIn.tagRawValues = Array(selectedTagRawValues) + (customTagText.isEmpty ? [] : ["custom:\(customTagText)"])
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

#Preview {
    NavigationStack {
        CheckInDetailView(checkIn: CheckIn(date: Date()))
            .modelContainer(for: [CheckIn.self, UserSettings.self], inMemory: true)
    }
}

//
//  ExportService.swift
//  Fyra
//

import Foundation
import UIKit
import SwiftUI

/// Export weight CSV and compare image via share sheet.
enum ExportService {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Generate CSV string: date, weight, unit. Sorted by date ascending.
    static func weightCSV(checkIns: [CheckIn], unit: WeightUnit) -> String {
        let header = "date,weight,unit"
        let rows = checkIns
            .filter { $0.weight != nil }
            .sorted { $0.date < $1.date }
            .compactMap { c -> String? in
                guard let w = c.weight else { return nil }
                let dateStr = dateFormatter.string(from: c.date)
                return "\(dateStr),\(w),\(unit.rawValue)"
            }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Write CSV to temp file and return URL for share sheet.
    static func writeWeightCSVToTempFile(checkIns: [CheckIn], unit: WeightUnit) -> URL? {
        let csv = weightCSV(checkIns: checkIns, unit: unit)
        let fileName = "weight_export_\(dateFormatter.string(from: Date())).csv"
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: temp, atomically: true, encoding: .utf8)
            return temp
        } catch {
            return nil
        }
    }

    /// Render a simple side-by-side compare view to UIImage (for export).
    static func compareImage(
        fromPath: String?,
        toPath: String?,
        fromLabel: String,
        toLabel: String,
        caption: String?,
        scale: CGFloat
    ) -> UIImage? {
        let fromImg = fromPath.flatMap { ImageStore.shared.load(path: $0) }
        let toImg = toPath.flatMap { ImageStore.shared.load(path: $0) }
        let view = CompareExportView(
            fromImage: fromImg,
            toImage: toImg,
            fromLabel: fromLabel,
            toLabel: toLabel,
            caption: caption
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage
    }

    /// Present iOS share sheet for a file URL.
    static func shareFile(_ url: URL, from sourceView: UIView?) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var presentFrom = root
            while let presented = presentFrom.presentedViewController { presentFrom = presented }
            if let popover = vc.popoverPresentationController, let view = sourceView {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            }
            presentFrom.present(vc, animated: true)
        }
    }

    /// Present share sheet for an image.
    static func shareImage(_ image: UIImage, from sourceView: UIView?) {
        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var presentFrom = root
            while let presented = presentFrom.presentedViewController { presentFrom = presented }
            if let popover = vc.popoverPresentationController, let view = sourceView {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            }
            presentFrom.present(vc, animated: true)
        }
    }
}

/// Minimal SwiftUI view for rendering compare export image.
struct CompareExportView: View {
    let fromImage: UIImage?
    let toImage: UIImage?
    let fromLabel: String
    let toLabel: String
    let caption: String?

    private let width: CGFloat = 600
    private let height: CGFloat = 400

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                imageColumn(image: fromImage, label: fromLabel)
                imageColumn(image: toImage, label: toLabel)
            }
            .frame(width: width, height: 320)
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(width: width, height: height)
        .background(Color(.systemBackground))
    }

    private func imageColumn(image: UIImage?, label: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemFill))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

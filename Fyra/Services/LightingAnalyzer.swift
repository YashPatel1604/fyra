//
//  LightingAnalyzer.swift
//  Fyra
//

import Foundation
import UIKit

/// Simple average luminance; used for Compare lighting disclaimer.
enum LightingAnalyzer {
    /// Threshold: if relative difference in average luminance exceeds this, show disclaimer.
    /// e.g. 0.25 = 25% difference.
    static let luminanceDifferenceThreshold: Double = 0.25

    /// Average luminance (0–1) of image; nil if image can't be analyzed. Samples via small bitmap.
    static func averageLuminance(of image: UIImage) -> Double? {
        let sampleSize: Int = 32
        let w = sampleSize
        let h = sampleSize
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * w
        let bufferSize = bytesPerRow * h
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buffer,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        guard let cg = image.cgImage else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var total: Double = 0
        var count = 0
        for i in stride(from: 0, to: bufferSize, by: bytesPerPixel) {
            let r = Double(buffer[i]) / 255
            let g = Double(buffer[i + 1]) / 255
            let b = Double(buffer[i + 2]) / 255
            total += (0.299 * r + 0.587 * g + 0.114 * b)
            count += 1
        }
        guard count > 0 else { return nil }
        return total / Double(count)
    }

    /// True if the two images have meaningfully different lighting (for disclaimer).
    static func hasSignificantLightingDifference(image1: UIImage?, image2: UIImage?) -> Bool {
        guard let img1 = image1, let img2 = image2,
              let l1 = averageLuminance(of: img1),
              let l2 = averageLuminance(of: img2) else { return false }
        let avg = (l1 + l2) / 2
        guard avg > 0.01 else { return false }
        let relativeDiff = abs(l1 - l2) / avg
        return relativeDiff > luminanceDifferenceThreshold
    }
}

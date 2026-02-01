//
//  TimelapseService.swift
//  Fyra
//

import Foundation
import UIKit
import AVFoundation

struct TimelapseFrame: Identifiable {
    let id = UUID()
    let date: Date
    let imagePath: String
    let overlayText: String?
}

enum TimelapseError: Error {
    case noFrames
    case writerFailed
    case imageLoadFailed
    case pixelBufferFailed
}

enum TimelapseService {
    static func frames(
        checkIns: [CheckIn],
        pose: Pose,
        range: DateInterval?,
        overlayWeight: Bool,
        unit: WeightUnit
    ) -> [TimelapseFrame] {
        let filtered = checkIns
            .filter { c in
                if let range { return c.date >= range.start && c.date <= range.end }
                return true
            }
            .sorted { $0.date < $1.date }

        let weightService = WeightTrendService(checkIns: filtered, unit: unit)
        return filtered.compactMap { checkIn in
            guard let path = checkIn.photoPath(for: pose) else { return nil }
            var overlayText: String?
            if overlayWeight,
               let idx = weightService.index(forDay: checkIn.date),
               let trend = weightService.trend(atIndex: idx) {
                overlayText = "Trend \(WeightTrendService.formatTrend(trend, unit: unit))"
            }
            return TimelapseFrame(date: checkIn.date, imagePath: path, overlayText: overlayText)
        }
    }

    static func generateVideo(
        frames: [TimelapseFrame],
        frameDuration: Double,
        outputSize: CGSize = CGSize(width: 1080, height: 1440),
        progress: ((Int, Int) -> Void)? = nil
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let url = try generateVideoSync(
                        frames: frames,
                        frameDuration: frameDuration,
                        outputSize: outputSize,
                        progress: progress
                    )
                    continuation.resume(returning: url)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func generateVideoSync(
        frames: [TimelapseFrame],
        frameDuration: Double,
        outputSize: CGSize,
        progress: ((Int, Int) -> Void)?
    ) throws -> URL {
        guard frames.count >= 2 else { throw TimelapseError.noFrames }

        let fileName = "progress_timelapse_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: outputSize.width,
            AVVideoHeightKey: outputSize.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outputSize.width,
            kCVPixelBufferHeightKey as String: outputSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw TimelapseError.writerFailed }
        writer.add(input)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameTime = CMTime(seconds: frameDuration, preferredTimescale: 600)
        var frameCount: Int32 = 0
        var failure: Error?
        for (index, frame) in frames.enumerated() {
            if failure != nil { break }
            autoreleasepool {
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
                guard let image = loadImage(path: frame.imagePath) else {
                    failure = TimelapseError.imageLoadFailed
                    return
                }
                guard let pixelBuffer = makePixelBuffer(
                    from: image,
                    size: outputSize,
                    overlayText: frame.overlayText
                ) else {
                    failure = TimelapseError.pixelBufferFailed
                    return
                }
                let presentationTime = CMTimeMultiply(frameTime, multiplier: frameCount)
                let ok = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                if !ok {
                    failure = TimelapseError.writerFailed
                    return
                }
                frameCount += 1
                if let progress {
                    DispatchQueue.main.async {
                        progress(index + 1, frames.count)
                    }
                }
            }
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        if let failure { throw failure }
        if writer.status == .failed || writer.status == .cancelled {
            throw TimelapseError.writerFailed
        }
        return outputURL
    }

    private static func loadImage(path: String) -> UIImage? {
        let fullURL = ImageStore.shared.photosDirectory.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: fullURL),
              let image = UIImage(data: data) else { return nil }
        return normalize(image)
    }

    private static func normalize(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func makePixelBuffer(
        from image: UIImage,
        size: CGSize,
        overlayText: String?
    ) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs as CFDictionary, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let drawRect = aspectFillRect(imageSize: image.size, targetSize: size)
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: drawRect)
        }

        if let overlayText {
            drawOverlay(text: overlayText, in: context, size: size)
        }

        return buffer
    }

    private static func aspectFillRect(imageSize: CGSize, targetSize: CGSize) -> CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let targetAspect = targetSize.width / targetSize.height
        if imageAspect > targetAspect {
            let scaledHeight = targetSize.height
            let scaledWidth = scaledHeight * imageAspect
            let x = (targetSize.width - scaledWidth) / 2
            return CGRect(x: x, y: 0, width: scaledWidth, height: scaledHeight)
        } else {
            let scaledWidth = targetSize.width
            let scaledHeight = scaledWidth / imageAspect
            let y = (targetSize.height - scaledHeight) / 2
            return CGRect(x: 0, y: y, width: scaledWidth, height: scaledHeight)
        }
    }

    private static func drawOverlay(text: String, in context: CGContext, size: CGSize) {
        let fontSize: CGFloat = 36
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let padding: CGFloat = 20
        let backgroundRect = CGRect(
            x: padding - 8,
            y: size.height - textSize.height - padding - 8,
            width: textSize.width + 16,
            height: textSize.height + 12
        )
        context.setFillColor(UIColor.black.withAlphaComponent(0.45).cgColor)
        let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 10)
        context.addPath(path.cgPath)
        context.fillPath()

        let textRect = CGRect(
            x: padding,
            y: size.height - textSize.height - padding,
            width: textSize.width,
            height: textSize.height
        )
        UIGraphicsPushContext(context)
        attributed.draw(in: textRect)
        UIGraphicsPopContext()
    }
}

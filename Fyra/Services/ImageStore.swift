//
//  ImageStore.swift
//  Fyra
//

import Foundation
import UIKit
import SwiftUI

final class ImageStore {
    static let shared = ImageStore()
    private let fileManager = FileManager.default
    private let maxDimension: CGFloat = 1600
    private let jpegQuality: CGFloat = 0.8
    private let photosFolderName = "ProgressPhotos"

    private var cache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.fyra.imagecache")

    private init() {}

    var photosDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(photosFolderName, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Save image data (e.g. from PhotosPicker) for a check-in and pose. Resizes and compresses.
    /// Returns the relative path to store in SwiftData.
    func save(imageData: Data, checkinID: UUID, pose: Pose) -> String? {
        guard let image = UIImage(data: imageData) else { return nil }
        return save(image: image, checkinID: checkinID, pose: pose)
    }

    func save(image: UIImage, checkinID: UUID, pose: Pose) -> String? {
        let resized = resize(image, maxDimension: maxDimension)
        guard let jpegData = resized.jpegData(compressionQuality: jpegQuality) else { return nil }

        let checkinDir = photosDirectory.appendingPathComponent(checkinID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: checkinDir.path) {
            try? fileManager.createDirectory(at: checkinDir, withIntermediateDirectories: true)
        }
        let filename = "\(pose.rawValue).jpg"
        let fileURL = checkinDir.appendingPathComponent(filename)
        do {
            try jpegData.write(to: fileURL)
            let relativePath = "\(checkinID.uuidString)/\(filename)"
            cacheQueue.sync { cache[relativePath] = resized }
            return relativePath
        } catch {
            return nil
        }
    }

    func load(path: String) -> UIImage? {
        if let cached = cacheQueue.sync(execute: { cache[path] }) { return cached }
        let fullURL = photosDirectory.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: fullURL.path),
              let data = try? Data(contentsOf: fullURL),
              let image = UIImage(data: data) else { return nil }
        cacheQueue.sync { cache[path] = image }
        return image
    }

    func loadImage(path: String) -> Image? {
        guard let uiImage = load(path: path) else { return nil }
        return Image(uiImage: uiImage)
    }

    func delete(path: String) {
        let fullURL = photosDirectory.appendingPathComponent(path)
        try? fileManager.removeItem(at: fullURL)
        cacheQueue.sync { cache[path] = nil }
    }

    func deleteAll(for checkinID: UUID) {
        let checkinDir = photosDirectory.appendingPathComponent(checkinID.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: checkinDir)
        cacheQueue.sync {
            cache = cache.filter { !$0.key.hasPrefix(checkinID.uuidString + "/") }
        }
    }

    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1)
        if ratio >= 1 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

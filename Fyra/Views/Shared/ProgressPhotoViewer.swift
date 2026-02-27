//
//  ProgressPhotoViewer.swift
//  Fyra
//

import Photos
import SwiftUI
import UIKit

struct ProgressPhotoViewerItem: Identifiable {
    let id: String
    let path: String
    let title: String
    let subtitle: String
}

struct ProgressPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let item: ProgressPhotoViewerItem

    @State private var isSaving = false
    @State private var saveMessage = ""
    @State private var showSaveAlert = false

    private var uiImage: UIImage? {
        ImageStore.shared.load(path: item.path)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = uiImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Couldn’t load this photo.")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text(item.title)
                        Text("•")
                        Text(item.subtitle)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                }
                .padding(.bottom, 12)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    saveToPhotos()
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .tint(Color.black)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isSaving ? "Saving..." : "Save to Photos")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(uiImage == nil ? NeonTheme.surfaceAlt : NeonTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || uiImage == nil)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.black.opacity(0.88))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Photo", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveMessage)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveToPhotos() {
        guard let image = uiImage else {
            presentSaveMessage("Couldn’t load this photo.")
            return
        }

        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            writeImageToLibrary(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    handleAuthorization(status, image: image)
                }
            }
        case .denied, .restricted:
            presentSaveMessage("Allow Photos access in Settings to save images to your gallery.")
        @unknown default:
            presentSaveMessage("Couldn’t save this photo.")
        }
    }

    private func handleAuthorization(_ status: PHAuthorizationStatus, image: UIImage) {
        switch status {
        case .authorized, .limited:
            writeImageToLibrary(image)
        case .denied, .restricted:
            presentSaveMessage("Allow Photos access in Settings to save images to your gallery.")
        case .notDetermined:
            presentSaveMessage("Couldn’t confirm Photos access.")
        @unknown default:
            presentSaveMessage("Couldn’t save this photo.")
        }
    }

    private func writeImageToLibrary(_ image: UIImage) {
        isSaving = true
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                isSaving = false
                if success {
                    presentSaveMessage("Saved to Photos.")
                } else {
                    presentSaveMessage(error?.localizedDescription ?? "Couldn’t save this photo.")
                }
            }
        }
    }

    private func presentSaveMessage(_ message: String) {
        saveMessage = message
        showSaveAlert = true
    }
}

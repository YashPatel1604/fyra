//
//  SystemImagePicker.swift
//  Fyra
//

import SwiftUI
import UIKit

struct SystemImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    var onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        configureCameraOverlay(for: picker)
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        if uiViewController.sourceType != sourceType {
            uiViewController.sourceType = sourceType
        }
        configureCameraOverlay(for: uiViewController)
    }

    private func configureCameraOverlay(for picker: UIImagePickerController) {
        guard picker.sourceType == .camera else {
            picker.cameraOverlayView = nil
            return
        }

        let overlay: RuleOfThirdsOverlayView
        if let existingOverlay = picker.cameraOverlayView as? RuleOfThirdsOverlayView {
            overlay = existingOverlay
        } else {
            overlay = RuleOfThirdsOverlayView()
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            picker.cameraOverlayView = overlay
        }

        DispatchQueue.main.async {
            overlay.frame = picker.view.bounds
            overlay.setNeedsLayout()
        }
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: SystemImagePicker

        init(parent: SystemImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel?()
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
    }
}

private final class RuleOfThirdsOverlayView: UIView {
    private let gridLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        gridLayer.lineWidth = 1.0 / UIScreen.main.scale
        layer.addSublayer(gridLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gridLayer.frame = bounds
        gridLayer.path = gridPath(in: bounds).cgPath
    }

    private func gridPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        for step in 1...2 {
            let fraction = CGFloat(step) / 3.0
            let x = rect.width * fraction
            let y = rect.height * fraction

            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}

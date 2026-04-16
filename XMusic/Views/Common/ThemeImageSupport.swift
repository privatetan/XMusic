import SwiftUI

#if canImport(UIKit)
import UIKit

enum ThemeBackgroundImageProcessor {
    static func loadImage(from data: Data) -> UIImage? {
        UIImage(data: data)
    }

    static func makeEditableImage(from image: UIImage) -> UIImage? {
        resizedImage(from: image, maxDimension: 2600)
    }

    static func makeBackgroundImageData(from image: UIImage) -> Data? {
        guard let rendered = resizedImage(from: image, maxDimension: 3200) else {
            return nil
        }

        return rendered.jpegData(compressionQuality: 0.94)
    }

    private static func resizedImage(from image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let largestSide = max(size.width, size.height)
        let scaleRatio = largestSide > maxDimension ? maxDimension / largestSide : 1
        let targetSize = CGSize(width: size.width * scaleRatio, height: size.height * scaleRatio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

struct ThemePhotoLibraryImagePicker: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onSelect: (UIImage) -> Void
        let dismiss: DismissAction

        init(onSelect: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onSelect = onSelect
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onSelect(image)
            }
            dismiss()
        }
    }
}

struct ThemeBackgroundCropperView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var committedOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var committedScale: CGFloat = 1
    @State private var pinchScale: CGFloat = 1

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                let layout = cropLayout(in: proxy.size)
                let effectiveScale = max(1, committedScale * pinchScale)
                let displaySize = displayedImageSize(for: layout, scale: effectiveScale)
                let proposedOffset = CGSize(
                    width: committedOffset.width + dragOffset.width,
                    height: committedOffset.height + dragOffset.height
                )
                let clampedOffset = clamped(
                    offset: proposedOffset,
                    imageSize: displaySize,
                    cropSize: layout.cropSize
                )

                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.11),
                            Color(red: 0.04, green: 0.04, blue: 0.07),
                            .black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Spacer(minLength: 8)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("裁剪背景图")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            Text("拖动调整位置，双指缩放调整取景，确认后再作为背景图保存。")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.66))
                        }
                        .frame(maxWidth: layout.cropSize.width, alignment: .leading)

                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.50))

                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: displaySize.width, height: displaySize.height)
                                .offset(clampedOffset)
                                .gesture(dragGesture(for: displaySize, cropSize: layout.cropSize))
                                .simultaneousGesture(magnificationGesture(for: displaySize, cropSize: layout.cropSize))

                            cropMask(for: layout.cropSize)
                                .allowsHitTesting(false)
                        }
                        .frame(width: layout.cropSize.width, height: layout.cropSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 16)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消", action: onCancel)
                            .foregroundStyle(.white)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("使用") {
                            if let cropped = renderedImage(
                                cropSize: layout.cropSize,
                                imageSize: displaySize,
                                offset: clampedOffset
                            ) {
                                onConfirm(cropped)
                            }
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private func cropLayout(in containerSize: CGSize) -> CropLayout {
        let horizontalInset: CGFloat = 24
        let verticalInset: CGFloat = 210
        let availableWidth = max(220, containerSize.width - horizontalInset * 2)
        let availableHeight = max(320, containerSize.height - verticalInset)
        let cropAspect = max(containerSize.width, 1) / max(containerSize.height, 1)

        var cropWidth = availableWidth
        var cropHeight = cropWidth / cropAspect
        if cropHeight > availableHeight {
            cropHeight = availableHeight
            cropWidth = cropHeight * cropAspect
        }

        return CropLayout(cropSize: CGSize(width: cropWidth, height: cropHeight))
    }

    private func displayedImageSize(for layout: CropLayout, scale: CGFloat) -> CGSize {
        let baseScale = max(
            layout.cropSize.width / max(image.size.width, 1),
            layout.cropSize.height / max(image.size.height, 1)
        )

        return CGSize(
            width: image.size.width * baseScale * scale,
            height: image.size.height * baseScale * scale
        )
    }

    private func dragGesture(for imageSize: CGSize, cropSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposedOffset = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                dragOffset = CGSize(
                    width: clamped(offset: proposedOffset, imageSize: imageSize, cropSize: cropSize).width - committedOffset.width,
                    height: clamped(offset: proposedOffset, imageSize: imageSize, cropSize: cropSize).height - committedOffset.height
                )
            }
            .onEnded { value in
                let proposedOffset = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                committedOffset = clamped(offset: proposedOffset, imageSize: imageSize, cropSize: cropSize)
                dragOffset = .zero
            }
    }

    private func magnificationGesture(for imageSize: CGSize, cropSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                pinchScale = value
            }
            .onEnded { value in
                committedScale = min(max(committedScale * value, 1), 4)
                pinchScale = 1
                committedOffset = clamped(offset: committedOffset, imageSize: imageSize, cropSize: cropSize)
            }
    }

    private func clamped(offset: CGSize, imageSize: CGSize, cropSize: CGSize) -> CGSize {
        let horizontalLimit = max((imageSize.width - cropSize.width) / 2, 0)
        let verticalLimit = max((imageSize.height - cropSize.height) / 2, 0)

        return CGSize(
            width: min(max(offset.width, -horizontalLimit), horizontalLimit),
            height: min(max(offset.height, -verticalLimit), verticalLimit)
        )
    }

    private func renderedImage(cropSize: CGSize, imageSize: CGSize, offset: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2

        let renderer = UIGraphicsImageRenderer(size: cropSize, format: format)
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: cropSize))

            let origin = CGPoint(
                x: (cropSize.width - imageSize.width) / 2 + offset.width,
                y: (cropSize.height - imageSize.height) / 2 + offset.height
            )

            image.draw(in: CGRect(origin: origin, size: imageSize))
        }
    }

    @ViewBuilder
    private func cropMask(for cropSize: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(Color.white.opacity(0.26), lineWidth: 1.2)
            .overlay {
                ZStack {
                    Path { path in
                        let thirdWidth = cropSize.width / 3
                        let thirdHeight = cropSize.height / 3
                        path.move(to: CGPoint(x: thirdWidth, y: 0))
                        path.addLine(to: CGPoint(x: thirdWidth, y: cropSize.height))
                        path.move(to: CGPoint(x: thirdWidth * 2, y: 0))
                        path.addLine(to: CGPoint(x: thirdWidth * 2, y: cropSize.height))
                        path.move(to: CGPoint(x: 0, y: thirdHeight))
                        path.addLine(to: CGPoint(x: cropSize.width, y: thirdHeight))
                        path.move(to: CGPoint(x: 0, y: thirdHeight * 2))
                        path.addLine(to: CGPoint(x: cropSize.width, y: thirdHeight * 2))
                    }
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
                }
            }
    }
}

private struct CropLayout {
    let cropSize: CGSize
}
#endif

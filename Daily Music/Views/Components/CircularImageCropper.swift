//
//  CircularImageCropper.swift
//  Daily Music
//
//  A minimal square cropper with a circular guide: pinch to zoom, drag to
//  reposition. The SAME transformed view is used for the preview and the capture
//  (via ImageRenderer), so what you see is what gets saved. Output is a square
//  UIImage (we clip to a circle wherever avatars are shown).
//

import SwiftUI

struct CircularImageCropper: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let side: CGFloat = 300

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                transformed
                    .overlay {
                        Circle().stroke(.white.opacity(0.9), lineWidth: 2)
                            .frame(width: side, height: side)
                    }
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { scale = max(1, lastScale * $0) }
                                .onEnded { _ in lastScale = scale },
                            DragGesture()
                                .onChanged { offset = CGSize(width: lastOffset.width + $0.translation.width,
                                                             height: lastOffset.height + $0.translation.height) }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel).tint(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") { onConfirm(rendered()) }.tint(.white).bold()
                }
            }
        }
    }

    // The image, scaled-to-fill the square, then transformed and clipped to it.
    private var transformed: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: side, height: side)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: side, height: side)
            .clipped()
    }

    @MainActor private func rendered() -> UIImage {
        let renderer = ImageRenderer(content: transformed)
        renderer.scale = 1024 / side    // capture at ~1024px for quality
        return renderer.uiImage ?? image
    }
}

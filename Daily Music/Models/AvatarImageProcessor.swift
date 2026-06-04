//
//  AvatarImageProcessor.swift
//  Daily Music
//
//  Pure image helper: shrink a picked avatar so it never exceeds maxDimension on
//  its longest side, then JPEG-encode it. Keeps uploads small and predictable.
//

import UIKit

enum AvatarImageProcessor {
    static func downscaledJPEG(_ image: UIImage,
                               maxDimension: CGFloat = 512,
                               quality: CGFloat = 0.8) -> Data? {
        let w = image.size.width, h = image.size.height
        guard w > 0, h > 0 else { return nil }
        let scale = min(1, maxDimension / max(w, h))     // min(1, …) = never upscale
        let newSize = CGSize(width: w * scale, height: h * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1                                 // size is in pixels, not points
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

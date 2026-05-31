//
//  ArtworkPalette.swift
//  Daily Music
//
//  Extracts a bold accent color from a song's album art so each day's screen is
//  themed by its artwork. Falls back gracefully to the brand color when the art
//  can't be loaded (e.g. no network), so the UI is never broken — just less
//  personalised.
//

import SwiftUI
import UIKit
import CoreImage

@MainActor
@Observable
final class ArtworkPalette {
    private(set) var accent: Color = Theme.Brand.gradient[0]
    /// The loaded artwork itself, kept so features like the share card can embed
    /// it (ImageRenderer can't wait on an async AsyncImage).
    private(set) var image: UIImage?
    private(set) var isLoaded = false
    private(set) var didFinishLoading = false

    func load(from url: URL?) async {
        didFinishLoading = false
        isLoaded = false
        image = nil

        guard let url else {
            didFinishLoading = true
            return
        }

        guard
            let (data, _) = try? await URLSession.shared.data(from: url),
            let image = UIImage(data: data)
        else {
            didFinishLoading = true
            return
        }

        self.image = image
        if let color = image.dominantVibrantColor() {
            accent = Color(color)
        }
        isLoaded = true
        didFinishLoading = true
    }
}

private extension UIImage {
    /// Average color of the image, with saturation/brightness nudged up so the
    /// result reads as a confident accent rather than a muddy gray.
    func dominantVibrantColor() -> UIColor? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let extent = ciImage.extent
        guard
            let filter = CIFilter(
                name: "CIAreaAverage",
                parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: CIVector(cgRect: extent)]
            ),
            let output = filter.outputImage
        else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        var color = UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            color = UIColor(
                hue: h,
                saturation: min(1, max(s, 0.55)),
                brightness: min(1, max(b, 0.5)),
                alpha: 1
            )
        }
        return color
    }
}

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
import UIKit        // UIImage + UIColor (the older UIKit image/color types Core Image works with)
import CoreImage    // Apple's image-processing framework — used here for the average-color filter

// @MainActor: every method/property here runs on the main (UI) thread, which is
//   required for anything that updates SwiftUI state.
// @Observable: the Swift Observation macro. It makes this class's properties
//   trackable, so any SwiftUI view that reads `accent`/`isLoaded` automatically
//   re-renders when they change — no manual @Published needed (that was the older
//   ObservableObject style).
// `final` forbids subclassing (a small perf + clarity win).
@MainActor
@Observable
final class ArtworkPalette {
    // `private(set)` = readable from anywhere, but only THIS class can assign it.
    // Views observe these; the loading logic owns the writes.
    // Neutral until artwork loads, so the screen never flashes the brand purple
    // before fading to the album's real color.
    private(set) var accent: Color = Color(red: 0.42, green: 0.45, blue: 0.5)
    /// The loaded artwork itself, kept so features like the share card can embed
    /// it (ImageRenderer can't wait on an async AsyncImage).
    private(set) var image: UIImage?
    private(set) var isLoaded = false
    private(set) var didFinishLoading = false

    // `async` because it awaits a network download. SwiftUI calls it from a
    // `.task { await palette.load(...) }`, which ties the work to the view's
    // lifetime (auto-cancelled if the view disappears).
    func load(from url: URL?) async {
        didFinishLoading = false
        isLoaded = false
        image = nil

        // `guard let url else { … }` is the early-exit idiom: if `url` is nil we
        // bail now (marking loading done so the UI doesn't hang on the fallback).
        guard let url else {
            didFinishLoading = true
            return
        }

        // A multi-clause guard: BOTH must succeed or we fall into `else`.
        //   • `try?` turns the throwing download into an optional (nil on failure)
        //     so a network error degrades gracefully instead of crashing.
        //   • URLSession.shared.data(from:) is the modern async download API.
        //   • UIImage(data:) is nil if the bytes aren't a valid image.
        guard
            let (data, _) = try? await URLSession.shared.data(from: url),
            let image = UIImage(data: data)
        else {
            didFinishLoading = true
            return
        }

        self.image = image
        // Only override the brand accent if we actually extracted a color.
        if let color = image.dominantVibrantColor() {
            accent = Color(color)        // bridge UIColor → SwiftUI Color
        }
        isLoaded = true
        didFinishLoading = true
    }
}

// A `private extension` on UIImage: adds a helper method usable only within this
// file. Extensions let you bolt methods onto types you don't own.
private extension UIImage {
    /// Average color of the image, with saturation/brightness nudged up so the
    /// result reads as a confident accent rather than a muddy gray.
    func dominantVibrantColor() -> UIColor? {
        // Convert to a CIImage (Core Image's representation) so we can run a filter.
        guard let ciImage = CIImage(image: self) else { return nil }
        let extent = ciImage.extent   // the full pixel rectangle of the image
        // CIAreaAverage collapses a region down to its single average color
        // (a 1×1-pixel output image). The parameters tell it which image and which
        // region to average over.
        guard
            let filter = CIFilter(
                name: "CIAreaAverage",
                parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: CIVector(cgRect: extent)]
            ),
            let output = filter.outputImage
        else { return nil }

        // Render that 1×1 result into a 4-byte buffer (R,G,B,A). `&bitmap` passes
        // the array by reference so `render` can write into it. NSNull working
        // color space = render in raw device RGB (no color management surprises).
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

        // Build a UIColor from those 0–255 bytes (divided to 0–1).
        var color = UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )

        // Average colors tend to look washed out, so convert to HSB and FLOOR the
        // saturation/brightness (min 0.55 / 0.5) to guarantee a punchy accent.
        // getHue(...) writes into the four `&` inout vars and returns false if the
        // color can't be expressed in HSB (then we keep the plain average).
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            color = UIColor(
                hue: h,
                saturation: min(1, max(s, 0.55)),   // clamp into [0.55, 1]
                brightness: min(1, max(b, 0.5)),    // clamp into [0.5, 1]
                alpha: 1
            )
        }
        return color
    }
}

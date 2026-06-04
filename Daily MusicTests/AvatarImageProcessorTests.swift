import Testing
import UIKit
@testable import Daily_Music

struct AvatarImageProcessorTests {
    static func solidImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let r = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return r.image { ctx in
            UIColor.systemPurple.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func capsLongestSideAtMax() throws {
        let big = Self.solidImage(width: 2000, height: 1000)
        let data = try #require(AvatarImageProcessor.downscaledJPEG(big, maxDimension: 512))
        let out = try #require(UIImage(data: data))
        #expect(max(out.size.width, out.size.height) <= 512)
    }

    @Test func doesNotUpscaleSmallImages() throws {
        let small = Self.solidImage(width: 100, height: 80)
        let data = try #require(AvatarImageProcessor.downscaledJPEG(small, maxDimension: 512))
        let out = try #require(UIImage(data: data))
        #expect(max(out.size.width, out.size.height) <= 100)
    }
}

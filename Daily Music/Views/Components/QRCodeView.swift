//  QRCodeView.swift — renders a string as a QR using CoreImage (no permissions).
import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let string: String
    var size: CGFloat = 180

    private static let context = CIContext()

    var body: some View {
        Image(uiImage: qrImage())
            .interpolation(.none)            // keep the modules crisp when scaled
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("QR code for your friend link")
    }

    private func qrImage() -> UIImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cg = Self.context.createCGImage(output, from: output.extent) else {
            return UIImage(systemName: "qrcode") ?? UIImage()
        }
        return UIImage(cgImage: cg)
    }
}

import SwiftUI

struct ShieldPage: View {
    @Environment(\.dismiss) private var dismiss
    let imageName: String
    var autoCropTransparentEdges: Bool = false   // NEW

    var body: some View {
        ZStack {
            AppTheme.navy900.ignoresSafeArea()

            GeometryReader { geo in
                let targetWidth = geo.size.width - 24  // gutters like before

                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    VStack(spacing: 24) {
                        Spacer(minLength: 40)

                        if let ui = UIImage(named: imageName) {
                            let uiFinal = autoCropTransparentEdges
                                ? (ui.croppingTransparentEdges() ?? ui)
                                : ui

                            Image(uiImage: uiFinal)
                                .resizable()
                                .scaledToFit()
                                .frame(width: targetWidth)   // hard width = screen width - padding
                                .padding(.horizontal, 12)
                        } else {
                            // Fallback if asset missing
                            Image(systemName: "shield.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: targetWidth)
                                .padding(.horizontal, 12)
                                .foregroundStyle(AppTheme.appGreen)
                        }

                        Button(action: { dismiss() }) {
                            Text("Back")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(AppTheme.appGreen)
                                .cornerRadius(12)
                        }
                        .padding(.top, 16)

                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .interactiveDismissDisabled() // force using the Back button
    }
}

// MARK: - UIImage alpha-crop helper
import CoreGraphics
import UIKit

private extension UIImage {
    /// Crops fully-transparent edges off an image. Returns nil if no opaque content found.
    func croppingTransparentEdges() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let ctx = CGContext(
            data: nil,
            width: width, height: height,
            bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

        var minX = width, minY = height, maxX = 0, maxY = 0
        for y in 0..<height {
            let row = data + y * bytesPerRow
            for x in 0..<width {
                let a = row[x * bytesPerPixel + 3]
                if a != 0 { // has opacity
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        if minX > maxX || minY > maxY { return nil } // fully transparent

        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: self.scale, orientation: self.imageOrientation)
    }
}

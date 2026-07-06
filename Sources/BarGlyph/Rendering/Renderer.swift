import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Draws a module ``Matrix`` into a bitmap with CoreGraphics.
///
/// One renderer covers every symbology: 1D matrices (`height == 1`) are
/// stretched to `RenderOptions.barHeight`; 2D matrices use square modules.
/// Module edges are snapped to whole pixels so fractional `moduleSize` values
/// cannot produce hairline seams between adjacent modules.
enum Renderer {
    static func cgImage(
        matrix: Matrix,
        symbology: Symbology,
        options: RenderOptions
    ) throws(RenderError) -> CGImage {
        guard options.moduleSize > 0 else {
            throw .invalidOptions(description: "moduleSize must be positive")
        }
        guard !symbology.isLinear || options.barHeight > 0 else {
            throw .invalidOptions(description: "barHeight must be positive")
        }

        let quietModules: Int
        switch options.quietZone {
        case .standard: quietModules = symbology.standardQuietZoneModules
        case .modules(let count): quietModules = max(0, count)
        case .none: quietModules = 0
        }

        // 1D symbologies take the quiet zone horizontally only.
        let module = options.moduleSize
        let isLinear = symbology.isLinear
        let columns = matrix.width + 2 * quietModules
        let pixelWidth = Int((CGFloat(columns) * module).rounded(.up))
        let pixelHeight = isLinear
            ? Int(options.barHeight.rounded(.up))
            : Int((CGFloat(matrix.height + 2 * quietModules) * module).rounded(.up))

        guard
            let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw .contextCreationFailed
        }

        context.setAllowsAntialiasing(false)
        context.setFillColor(options.backgroundColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.setFillColor(options.foregroundColor.cgColor)

        func pixelEdge(ofModule index: Int) -> Int {
            Int((CGFloat(quietModules + index) * module).rounded())
        }

        for y in 0..<matrix.height {
            let top = isLinear ? 0 : pixelEdge(ofModule: y)
            let bottom = isLinear ? pixelHeight : pixelEdge(ofModule: y + 1)
            for x in 0..<matrix.width where matrix[x, y] {
                let left = pixelEdge(ofModule: x)
                let right = pixelEdge(ofModule: x + 1)
                // CoreGraphics' origin is bottom-left; matrix row 0 is the top.
                context.fill(CGRect(
                    x: CGFloat(left),
                    y: CGFloat(pixelHeight - bottom),
                    width: CGFloat(right - left),
                    height: CGFloat(bottom - top)
                ))
            }
        }

        guard let image = context.makeImage() else {
            throw .contextCreationFailed
        }
        return image
    }

    static func pngData(from image: CGImage) throws(RenderError) -> Data {
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil
            )
        else {
            throw .pngEncodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw .pngEncodingFailed
        }
        return data as Data
    }
}

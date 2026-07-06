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

        let isLinear = symbology.isLinear
        let quiet: QuietZoneSpec
        switch options.quietZone {
        case .standard:
            quiet = symbology.standardQuietZone
        case .modules(let count):
            let clamped = max(0, count)
            quiet = QuietZoneSpec(
                leading: clamped, trailing: clamped, vertical: isLinear ? 0 : clamped)
        case .none:
            quiet = QuietZoneSpec(leading: 0, trailing: 0, vertical: 0)
        }

        let module = options.moduleSize
        let rowHeight = symbology.rowHeightMultiplier
        let columns = matrix.width + quiet.leading + quiet.trailing
        let pixelWidth = Int((CGFloat(columns) * module).rounded(.up))
        let pixelHeight = isLinear
            ? Int(options.barHeight.rounded(.up))
            : Int((CGFloat(matrix.height * rowHeight + 2 * quiet.vertical) * module).rounded(.up))

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

        func horizontalEdge(ofModule index: Int) -> Int {
            Int((CGFloat(quiet.leading + index) * module).rounded())
        }
        func verticalEdge(ofModule index: Int) -> Int {
            Int((CGFloat(quiet.vertical + index * rowHeight) * module).rounded())
        }

        for y in 0..<matrix.height {
            let top = isLinear ? 0 : verticalEdge(ofModule: y)
            let bottom = isLinear ? pixelHeight : verticalEdge(ofModule: y + 1)
            for x in 0..<matrix.width where matrix[x, y] {
                let left = horizontalEdge(ofModule: x)
                let right = horizontalEdge(ofModule: x + 1)
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

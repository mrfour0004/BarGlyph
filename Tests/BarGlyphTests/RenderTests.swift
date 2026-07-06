import CoreGraphics
import Testing
@testable import BarGlyph

struct RenderTests {
    /// Reads an image back as RGBA bytes.
    private func rgbaBytes(of image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    @Test func imageHasExpectedDimensions() throws {
        // "A" -> 47 modules; standard Code 39 quiet zone is 10 modules per side.
        let image = try BarGlyph.image(for: "A", symbology: .code39)
        #expect(image.width == (47 + 20) * 3)
        #expect(image.height == 60)
    }

    @Test func explicitQuietZoneAndModuleSizeApply() throws {
        let image = try BarGlyph.image(
            for: "A", symbology: .code39,
            options: .init(moduleSize: 2, barHeight: 40, quietZone: .modules(2)))
        #expect(image.width == (47 + 4) * 2)
        #expect(image.height == 40)
    }

    @Test func pixelsMatchMatrixExactly() throws {
        // 1px modules, 1px bar height, no quiet zone: image == matrix.
        let matrix = try BarGlyph.matrix(for: "A", symbology: .code39)
        let image = try BarGlyph.image(
            for: "A", symbology: .code39,
            options: .init(moduleSize: 1, barHeight: 1, quietZone: QuietZone.none))
        #expect(image.width == matrix.width)
        #expect(image.height == 1)

        let pixels = try rgbaBytes(of: image)
        for x in 0..<matrix.width {
            let red = pixels[x * 4]
            #expect(red == (matrix[x, 0] ? 0 : 255), "pixel \(x) mismatch")
        }
    }

    @Test func quietZoneStaysBackgroundColored() throws {
        let image = try BarGlyph.image(
            for: "A", symbology: .code39,
            options: .init(moduleSize: 1, barHeight: 1, quietZone: .modules(5)))
        let pixels = try rgbaBytes(of: image)
        for x in 0..<5 {
            #expect(pixels[x * 4] == 255)
            #expect(pixels[(image.width - 1 - x) * 4] == 255)
        }
    }

    @Test func pngDataHasPNGMagicBytes() throws {
        let data = try BarGlyph.pngData(for: "A", symbology: .code39)
        #expect(data.count > 8)
        #expect(Array(data.prefix(4)) == [0x89, 0x50, 0x4E, 0x47])
    }

    @Test func rejectsNonPositiveModuleSize() throws {
        let matrix = try BarGlyph.matrix(for: "A", symbology: .code39)
        #expect(throws: RenderError.self) {
            try Renderer.cgImage(
                matrix: matrix, symbology: .code39, options: .init(moduleSize: 0))
        }
    }
}

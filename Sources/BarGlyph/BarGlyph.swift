import CoreGraphics
import Foundation

/// BarGlyph — generates 1D & 2D barcode images.
///
/// The facade is the package's sole entry point:
///
/// ```swift
/// let image = try BarGlyph.image(for: "ABC-123", symbology: .code39)
/// let png   = try BarGlyph.pngData(for: "ABC-123",
///                                  symbology: .code39(includeCheckDigit: true),
///                                  options: .init(moduleSize: 4))
/// ```
public enum BarGlyph {
    /// Encodes `contents` and renders it as a bitmap image.
    ///
    /// - Throws: ``EncodeError`` if `contents` cannot be represented by
    ///   `symbology`; ``RenderError`` if drawing fails.
    public static func image(
        for contents: String,
        symbology: Symbology,
        options: RenderOptions = .init()
    ) throws -> CGImage {
        try Renderer.cgImage(
            matrix: matrix(for: contents, symbology: symbology),
            symbology: symbology,
            options: options
        )
    }

    /// Encodes `contents` and renders it as PNG data, ready to write or upload.
    ///
    /// - Throws: ``EncodeError`` if `contents` cannot be represented by
    ///   `symbology`; ``RenderError`` if drawing or PNG encoding fails.
    public static func pngData(
        for contents: String,
        symbology: Symbology,
        options: RenderOptions = .init()
    ) throws -> Data {
        try Renderer.pngData(from: image(for: contents, symbology: symbology, options: options))
    }

    /// Encodes `contents` into a module matrix without rendering — the
    /// platform-independent encoding result.
    public static func matrix(
        for contents: String,
        symbology: Symbology
    ) throws(EncodeError) -> Matrix {
        try symbology.encoder.encode(contents)
    }
}

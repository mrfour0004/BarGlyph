import CoreGraphics
import Vision
@testable import BarGlyph

/// Decodes a rendered barcode with Apple's Vision framework — an independent
/// implementation, so a successful round trip validates our encoding tables
/// and layout against a real scanner.
func visionDecode(_ image: CGImage, symbology: VNBarcodeSymbology) throws -> String? {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [symbology]
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    return request.results?.first?.payloadStringValue
}

/// Generates, renders, and Vision-decodes `contents`, returning the payload.
func roundTrip(
    _ contents: String,
    symbology: Symbology,
    vision: VNBarcodeSymbology,
    options: RenderOptions = .init()
) throws -> String? {
    let image = try BarGlyph.image(for: contents, symbology: symbology, options: options)
    return try visionDecode(image, symbology: vision)
}

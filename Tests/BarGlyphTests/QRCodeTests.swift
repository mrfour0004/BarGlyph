import Testing
@testable import BarGlyph

struct QRCodeTests {
    // ── version selection & geometry ──

    @Test func shortContentUsesVersion1() throws {
        let matrix = try BarGlyph.matrix(for: "HELLO", symbology: .qr(errorCorrection: .low))
        #expect(matrix.width == 21)
        #expect(matrix.height == 21)
    }

    @Test func hundredBytesAtLowUsesVersion5() throws {
        let contents = String(repeating: "x", count: 100)
        let matrix = try BarGlyph.matrix(for: contents, symbology: .qr(errorCorrection: .low))
        #expect(matrix.width == 37)  // version 5 = 4*5 + 17
    }

    @Test func higherCorrectionNeedsBiggerSymbol() throws {
        let contents = String(repeating: "x", count: 100)
        let low = try BarGlyph.matrix(for: contents, symbology: .qr(errorCorrection: .low))
        let high = try BarGlyph.matrix(for: contents, symbology: .qr(errorCorrection: .high))
        #expect(high.width > low.width)
    }

    @Test func sizeIsAlwaysFourTimesVersionPlus17() throws {
        for length in [1, 30, 200, 900] {
            let contents = String(repeating: "a", count: length)
            let matrix = try BarGlyph.matrix(for: contents, symbology: .qr)
            #expect((matrix.width - 17).isMultiple(of: 4))
            #expect(matrix.width == matrix.height)
        }
    }

    // ── structure ──

    @Test func findersSitInThreeCorners() throws {
        let matrix = try BarGlyph.matrix(for: "FINDER", symbology: .qr)
        let size = matrix.width
        for (cx, cy) in [(3, 3), (size - 4, 3), (3, size - 4)] {
            #expect(matrix[cx, cy])                 // center dark
            #expect(!matrix[cx + 2, cy + 2])        // ring 2 light
            #expect(matrix[cx + 3, cy + 3])         // ring 3 dark border
        }
    }

    @Test func encodingIsDeterministic() throws {
        let a = try BarGlyph.matrix(for: "same input", symbology: .qr)
        let b = try BarGlyph.matrix(for: "same input", symbology: .qr)
        #expect(a == b)
    }

    // ── capacity limits ──

    @Test func oversizedContentThrowsDataTooLong() {
        let contents = String(repeating: "x", count: 3000)
        #expect(throws: EncodeError.dataTooLong(maximum: 1273)) {
            try BarGlyph.matrix(for: contents, symbology: .qr(errorCorrection: .high))
        }
    }

    @Test func maximumHighCorrectionContentFits() throws {
        let contents = String(repeating: "x", count: 1273)
        let matrix = try BarGlyph.matrix(for: contents, symbology: .qr(errorCorrection: .high))
        #expect(matrix.width == 177)  // version 40
    }

    @Test func rejectsEmptyInput() {
        #expect(throws: EncodeError.emptyInput) {
            try BarGlyph.matrix(for: "", symbology: .qr)
        }
    }

    // ── round trip against Vision ──

    @Test(arguments: [
        "https://example.com/barglyph?id=42",
        "Short",
        "1234567890",
        "Line one\nLine two — punctuation, quotes 'x' \"y\"",
    ])
    func visionDecodesRoundTrip(contents: String) throws {
        for level: Symbology.QRErrorCorrection in [.low, .medium, .quartile, .high] {
            let payload = try roundTrip(
                contents, symbology: .qr(errorCorrection: level), vision: .qr)
            #expect(payload == contents, "level \(level)")
        }
    }

    @Test func visionDecodesMultiBlockVersion() throws {
        // ~250 bytes forces a version with multiple interleaved EC blocks.
        let contents = (0..<25).map { "segment-\(String(format: "%02d", $0))" }
            .joined(separator: "/")
        #expect(try roundTrip(contents, symbology: .qr(errorCorrection: .quartile), vision: .qr)
            == contents)
    }

    @Test func visionDecodesUTF8Content() throws {
        let contents = "BarGlyph 條碼測試"
        #expect(try roundTrip(contents, symbology: .qr, vision: .qr) == contents)
    }
}

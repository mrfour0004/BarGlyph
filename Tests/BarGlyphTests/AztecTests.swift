import Testing
@testable import BarGlyph

struct AztecTests {
    // ── bit stuffing ──

    @Test func allZeroWordGetsComplementBitStuffed() {
        // First 5 bits of a 6-bit word all zero -> emit 000001, re-read the
        // displaced bit; remainder pads with ones.
        let stuffed = AztecEncoder.stuff([Bool](repeating: false, count: 6), wordSize: 6)
        let expected =
            [false, false, false, false, false, true]   // stuffed word
            + [false, true, true, true, true, true]     // displaced bit + 1-padding
        #expect(stuffed == expected)
    }

    @Test func allOnesWordGetsZeroBitStuffed() {
        // The displaced bit plus 1-padding forms another all-ones word, which
        // gets stuffed again.
        let stuffed = AztecEncoder.stuff([Bool](repeating: true, count: 6), wordSize: 6)
        let expected =
            [true, true, true, true, true, false]
            + [true, true, true, true, true, false]
        #expect(stuffed == expected)
    }

    @Test func mixedWordPassesThroughUnchanged() {
        let bits = [true, false, true, false, true, false]
        #expect(AztecEncoder.stuff(bits, wordSize: 6) == bits)
    }

    // ── mode message ──

    @Test func compactModeMessageSpans28Bits() {
        let message = AztecEncoder.modeMessage(compact: true, layers: 1, dataWords: 5)
        #expect(message.count == 28)
    }

    @Test func fullModeMessageSpans40Bits() {
        let message = AztecEncoder.modeMessage(compact: false, layers: 8, dataWords: 100)
        #expect(message.count == 40)
    }

    // ── geometry ──

    @Test func shortContentProducesCompactSymbol() throws {
        // Compact 1-layer symbols are 15×15.
        let matrix = try BarGlyph.matrix(for: "AZ", symbology: .aztec)
        #expect(matrix.width == 15)
        #expect(matrix.height == 15)
    }

    @Test func symbolIsSquareWithOddSize() throws {
        for length in [1, 20, 60, 300, 800] {
            let contents = String(repeating: "z", count: length)
            let matrix = try BarGlyph.matrix(for: contents, symbology: .aztec)
            #expect(matrix.width == matrix.height)
            #expect(matrix.width.isMultiple(of: 2) == false)
        }
    }

    @Test func bullseyeCenterIsDark() throws {
        let matrix = try BarGlyph.matrix(for: "CENTER", symbology: .aztec)
        let center = matrix.width / 2
        #expect(matrix[center, center])
        #expect(!matrix[center + 1, center])  // first ring gap is light
        #expect(matrix[center + 2, center])   // second ring is dark
    }

    // ── errors ──

    @Test func rejectsEmptyInput() {
        #expect(throws: EncodeError.emptyInput) {
            try BarGlyph.matrix(for: "", symbology: .aztec)
        }
    }

    @Test func oversizedContentThrowsDataTooLong() {
        let contents = String(repeating: "x", count: 3000)
        #expect(throws: EncodeError.dataTooLong(maximum: 1914)) {
            try BarGlyph.matrix(for: contents, symbology: .aztec)
        }
    }

    // ── round trip against Vision ──

    @Test(arguments: [
        "BarGlyph Aztec",
        "A",
        "ticket:2026-07-07/seat=12B/gate=7",
        "0123456789012345678901234567890123456789",
    ])
    func visionDecodesRoundTrip(contents: String) throws {
        // Aztec requires no quiet zone, so small compact symbols would touch
        // the image edge; give the detector some margin and resolution.
        let options = RenderOptions(moduleSize: 6, quietZone: .modules(4))
        #expect(try roundTrip(contents, symbology: .aztec, vision: .aztec, options: options)
            == contents)
    }

    @Test func visionDecodesFullFormatSymbol() throws {
        // ~120 bytes exceeds compact capacity and forces the full format.
        let contents = (0..<12).map { "segment-\($0)" }.joined(separator: ",")
        #expect(try roundTrip(contents, symbology: .aztec, vision: .aztec) == contents)
    }

    @Test func visionDecodesSymbolWithReferenceGrid() throws {
        // ~500 bytes needs enough layers that the dotted reference grid appears.
        let contents = (0..<50).map { "chunk-\(String(format: "%03d", $0))" }
            .joined(separator: ";")
        #expect(try roundTrip(contents, symbology: .aztec, vision: .aztec) == contents)
    }
}

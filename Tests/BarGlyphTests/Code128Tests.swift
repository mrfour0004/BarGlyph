import Testing
@testable import BarGlyph

struct Code128Tests {
    private func bits(_ matrix: Matrix) -> String {
        (0..<matrix.width).map { matrix[$0, 0] ? "1" : "0" }.joined()
    }

    // ── table invariants (catch any typo in the 107-entry table) ──

    @Test func allSymbolPatternsSpanElevenModules() {
        for value in 0...105 {
            let pattern = Code128Encoder.patterns[value]
            #expect(pattern.count == 6)
            #expect(pattern.reduce(0, +) == 11, "value \(value)")
        }
    }

    @Test func stopPatternSpansThirteenModules() {
        let stop = Code128Encoder.patterns[106]
        #expect(stop.count == 7)
        #expect(stop.reduce(0, +) == 13)
    }

    @Test func allSymbolsHaveEvenBarModuleCount() {
        // Code 128 symbol property: dark modules per symbol are always even.
        for value in 0...105 {
            let pattern = Code128Encoder.patterns[value]
            let barSum = stride(from: 0, to: 6, by: 2).map { pattern[$0] }.reduce(0, +)
            #expect(barSum.isMultiple(of: 2), "value \(value)")
        }
    }

    // ── golden vectors ──

    @Test func encodesSingleLetterAgainstGoldenPattern() throws {
        // Start B (104) = 11010010000, 'A' (33) = 10100011000,
        // checksum (104 + 1*33) % 103 = 34 = 10001011000, stop = 1100011101011.
        let expected = "11010010000" + "10100011000" + "10001011000" + "1100011101011"
        let matrix = try BarGlyph.matrix(for: "A", symbology: .code128)
        #expect(matrix.width == 46)
        #expect(bits(matrix) == expected)
    }

    @Test func digitRunsUseDoubleDensityCodeSetC() throws {
        // "123456" -> Start C + 3 pairs + checksum + stop = 5 symbols + stop.
        let matrix = try BarGlyph.matrix(for: "123456", symbology: .code128)
        #expect(matrix.width == 5 * 11 + 13)
    }

    @Test func oddDigitEncodesOutsideCodeSetC() throws {
        // "12345" -> Start C + 2 pairs + CODE_B + '5' + checksum + stop.
        let matrix = try BarGlyph.matrix(for: "12345", symbology: .code128)
        #expect(matrix.width == 6 * 11 + 13)
    }

    @Test func shortDigitRunStaysInCodeSetB() throws {
        // "AB123" -> Start B + 5 characters + checksum + stop (no switch for 3 digits).
        let matrix = try BarGlyph.matrix(for: "AB123", symbology: .code128)
        #expect(matrix.width == 7 * 11 + 13)
    }

    @Test func controlCharactersUseCodeSetA() throws {
        // TAB requires code set A: Start A + TAB + 'A' + checksum + stop.
        let matrix = try BarGlyph.matrix(for: "\tA", symbology: .code128)
        #expect(matrix.width == 4 * 11 + 13)
    }

    // ── errors ──

    @Test func rejectsEmptyInput() {
        #expect(throws: EncodeError.emptyInput) {
            try BarGlyph.matrix(for: "", symbology: .code128)
        }
    }

    @Test func rejectsNonASCII() {
        #expect(throws: EncodeError.unsupportedCharacter("é")) {
            try BarGlyph.matrix(for: "café", symbology: .code128)
        }
    }

    // ── round trip against Vision (independent decoder) ──

    @Test(arguments: [
        "BarGlyph-128",
        "0123456789",
        "Hello, World! 42",
        "a1b2C3d4",
        "12345",
    ])
    func visionDecodesRoundTrip(contents: String) throws {
        #expect(try roundTrip(contents, symbology: .code128, vision: .code128) == contents)
    }
}

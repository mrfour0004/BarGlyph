import Testing
@testable import BarGlyph

struct Code39Tests {
    /// Converts a matrix's single row into a "1"/"0" string for comparison.
    private func bits(_ matrix: Matrix) -> String {
        (0..<matrix.width).map { matrix[$0, 0] ? "1" : "0" }.joined()
    }

    @Test func encodesSingleCharacterAgainstGoldenPattern() throws {
        // Hand-derived from the Code 39 table, 3:1 wide-to-narrow ratio:
        //   '*' (start/stop) = NWNNWNWNN -> 1 000 1 0 111 0 111 0 1
        //   'A'              = WNNNNWNNW -> 111 0 1 0 1 000 1 0 111
        // Layout: *  gap  A  gap  *
        let star = "100010111011101"
        let a = "111010100010111"
        let expected = star + "0" + a + "0" + star

        let matrix = try BarGlyph.matrix(for: "A", symbology: .code39)
        #expect(matrix.height == 1)
        #expect(matrix.width == 47)
        #expect(bits(matrix) == expected)
    }

    @Test func checkDigitMatchesManuallyAppendedCheckCharacter() throws {
        // "CODE39" values: C=12 O=24 D=13 E=14 3=3 9=9, sum 75, 75 mod 43 = 32 = 'W'.
        let automatic = try BarGlyph.matrix(
            for: "CODE39", symbology: .code39(includeCheckDigit: true))
        let manual = try BarGlyph.matrix(for: "CODE39W", symbology: .code39)
        #expect(automatic == manual)
    }

    @Test func widthGrowsFifteenModulesPerCharacter() throws {
        // (characters + start/stop) * 15 modules + inter-character gaps.
        let one = try BarGlyph.matrix(for: "A", symbology: .code39)
        let two = try BarGlyph.matrix(for: "AB", symbology: .code39)
        #expect(one.width == 3 * 15 + 2)
        #expect(two.width == 4 * 15 + 3)
    }

    @Test func supportsFullAlphabet() throws {
        let all = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%"
        let matrix = try BarGlyph.matrix(for: all, symbology: .code39)
        #expect(matrix.width == (43 + 2) * 15 + 44)
    }

    @Test func rejectsEmptyInput() {
        #expect(throws: EncodeError.emptyInput) {
            try BarGlyph.matrix(for: "", symbology: .code39)
        }
    }

    @Test func rejectsLowercase() {
        #expect(throws: EncodeError.unsupportedCharacter("a")) {
            try BarGlyph.matrix(for: "abc", symbology: .code39)
        }
    }

    @Test func rejectsAsteriskInContents() {
        #expect(throws: EncodeError.unsupportedCharacter("*")) {
            try BarGlyph.matrix(for: "A*B", symbology: .code39)
        }
    }
}

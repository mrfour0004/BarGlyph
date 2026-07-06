import Testing
@testable import BarGlyph

struct EANTests {
    private func bits(_ matrix: Matrix) -> String {
        (0..<matrix.width).map { matrix[$0, 0] ? "1" : "0" }.joined()
    }

    // ── golden vectors ──

    @Test func allZerosEAN13MatchesGoldenPattern() throws {
        // Leading digit 0 -> parity LLLLLL; L(0) = 0001101, R(0) = 1110010.
        let expected = "101" + String(repeating: "0001101", count: 6)
            + "01010" + String(repeating: "1110010", count: 6) + "101"
        let matrix = try BarGlyph.matrix(for: "0000000000000", symbology: .ean13)
        #expect(matrix.width == 95)
        #expect(bits(matrix) == expected)
    }

    @Test func allZerosEAN8MatchesGoldenPattern() throws {
        let expected = "101" + String(repeating: "0001101", count: 4)
            + "01010" + String(repeating: "1110010", count: 4) + "101"
        let matrix = try BarGlyph.matrix(for: "00000000", symbology: .ean8)
        #expect(matrix.width == 67)
        #expect(bits(matrix) == expected)
    }

    // ── check digit ──

    @Test func autoCheckDigitMatchesManual() throws {
        // "400638133393" GTIN check digit is 1.
        let auto = try BarGlyph.matrix(for: "400638133393", symbology: .ean13)
        let manual = try BarGlyph.matrix(for: "4006381333931", symbology: .ean13)
        #expect(auto == manual)
    }

    @Test func rejectsWrongCheckDigit() {
        #expect(throws: EncodeError.invalidCheckDigit) {
            try BarGlyph.matrix(for: "4006381333932", symbology: .ean13)
        }
    }

    // ── UPC-A is EAN-13 with a leading zero ──

    @Test func upcAEncodesAsEAN13WithLeadingZero() throws {
        let upc = try BarGlyph.matrix(for: "036000291452", symbology: .upcA)
        let ean = try BarGlyph.matrix(for: "0036000291452", symbology: .ean13)
        #expect(upc == ean)
    }

    // ── errors ──

    @Test func rejectsWrongLength() {
        #expect(throws: EncodeError.invalidLength(expected: "12 or 13 digits", actual: 5)) {
            try BarGlyph.matrix(for: "12345", symbology: .ean13)
        }
    }

    @Test func rejectsNonDigits() {
        #expect(throws: EncodeError.unsupportedCharacter("A")) {
            try BarGlyph.matrix(for: "40063813339A", symbology: .ean13)
        }
    }

    @Test func rejectsEmptyInput() {
        #expect(throws: EncodeError.emptyInput) {
            try BarGlyph.matrix(for: "", symbology: .ean8)
        }
    }

    // ── asymmetric standard quiet zone (EAN-13: 11 leading, 7 trailing) ──

    @Test func ean13QuietZoneIsAsymmetric() throws {
        let image = try BarGlyph.image(
            for: "4006381333931", symbology: .ean13,
            options: .init(moduleSize: 1, barHeight: 1))
        #expect(image.width == 11 + 95 + 7)
    }

    // ── round trip against Vision ──

    @Test func visionDecodesEAN13() throws {
        #expect(try roundTrip("4006381333931", symbology: .ean13, vision: .ean13)
            == "4006381333931")
    }

    @Test func visionDecodesEAN8() throws {
        #expect(try roundTrip("96385074", symbology: .ean8, vision: .ean8)
            == "96385074")
    }

    @Test func visionDecodesUPCA() throws {
        // Vision reports UPC-A as its EAN-13 form with a leading zero.
        let payload = try roundTrip("036000291452", symbology: .upcA, vision: .ean13)
        #expect(payload?.hasSuffix("036000291452") == true)
    }
}

import Testing
@testable import BarGlyph

struct FacadeTests {
    @Test func code39StaticSugarOmitsCheckDigit() throws {
        let sugar = try BarGlyph.matrix(for: "A", symbology: .code39)
        let explicit = try BarGlyph.matrix(
            for: "A", symbology: .code39(includeCheckDigit: false))
        #expect(sugar == explicit)
    }

    @Test func matrixIsPlatformIndependentEncodingResult() throws {
        let matrix = try BarGlyph.matrix(for: "TEST", symbology: .code39)
        #expect(matrix.height == 1)
        #expect(matrix.width > 0)
    }
}

import Testing
@testable import BarGlyph

@Test func versionIsSet() {
    #expect(!BarGlyph.version.isEmpty)
}

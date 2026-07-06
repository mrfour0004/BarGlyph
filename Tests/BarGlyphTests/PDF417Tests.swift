import Testing
@testable import BarGlyph

struct PDF417Tests {
    // ── codeword table invariants ──

    @Test func tableHasThreeClustersOf929Patterns() {
        #expect(PDF417CodewordTable.clusters.count == 3)
        for cluster in PDF417CodewordTable.clusters {
            #expect(cluster.count == 929)
        }
    }

    @Test func everyPatternHoldsClusterInvariant() {
        // 17 modules, leading bar, trailing space, 4 bars/4 spaces, and
        // (b1 - b2 + b3 - b4 + 9) mod 9 == cluster number.
        for (clusterIndex, cluster) in PDF417CodewordTable.clusters.enumerated() {
            for pattern in cluster {
                #expect(pattern >> 16 & 1 == 1)
                #expect(pattern & 1 == 0)
                var bars: [Int] = []
                var runLength = 0
                var previous = true
                for shift in stride(from: 16, through: 0, by: -1) {
                    let bit = pattern >> shift & 1 == 1
                    if bit == previous {
                        runLength += 1
                    } else {
                        if previous { bars.append(runLength) }
                        previous = bit
                        runLength = 1
                    }
                }
                if previous { bars.append(runLength) }
                #expect(bars.count == 4)
                let k = (bars[0] - bars[1] + bars[2] - bars[3] + 9) % 9
                #expect(k == clusterIndex * 3)
            }
        }
    }

    // ── error correction ──

    @Test func generatorPolynomialLevel0MatchesSpec() {
        // g(x) = (x-3)(x-9) = x² - 12x + 27; -12 mod 929 = 917.
        #expect(PDF417Encoder.generatorPolynomial(degree: 2) == [1, 917, 27])
    }

    @Test func errorCorrectionRootsCancel() {
        // message·x^k + parity must evaluate to 0 at every generator root 3^i.
        let message = [5, 453, 178, 121, 239]
        let parity = PDF417Encoder.errorCorrection(for: message, count: 8)
        let polynomial = message + parity
        var root = 1
        for _ in 1...8 {
            root = root * 3 % 929
            var value = 0
            for coefficient in polynomial {
                value = (value * root + coefficient) % 929
            }
            #expect(value == 0, "root \(root)")
        }
    }

    // ── byte compaction ──

    @Test func sixByteGroupsUse924Latch() {
        let codewords = PDF417Encoder.byteCompaction(Array("abcdef".utf8))
        #expect(codewords.count == 6)  // latch + 5
        #expect(codewords[0] == 924)
    }

    @Test func remainderBytesEncodeDirectly() {
        let codewords = PDF417Encoder.byteCompaction(Array("abcdefgh".utf8))
        #expect(codewords[0] == 901)
        #expect(codewords.count == 1 + 5 + 2)
        #expect(codewords.suffix(2) == [Int(UInt8(ascii: "g")), Int(UInt8(ascii: "h"))])
    }

    // ── geometry ──

    @Test func widthFollowsColumnFormula() throws {
        let matrix = try BarGlyph.matrix(for: "BarGlyph PDF417", symbology: .pdf417)
        #expect((matrix.width - 69).isMultiple(of: 17))
        #expect((3...90).contains(matrix.height))
    }

    @Test func everyRowStartsAndStopsWithStandardPatterns() throws {
        let matrix = try BarGlyph.matrix(for: "row check", symbology: .pdf417)
        for y in 0..<matrix.height {
            // Start pattern begins 11111111; stop pattern ends …01.
            for x in 0..<8 {
                #expect(matrix[x, y])
            }
            #expect(!matrix[matrix.width - 2, y])
            #expect(matrix[matrix.width - 1, y])
        }
    }

    @Test func stackedRowsRenderThreeModulesTall() throws {
        let matrix = try BarGlyph.matrix(for: "tall", symbology: .pdf417)
        let image = try BarGlyph.image(
            for: "tall", symbology: .pdf417,
            options: .init(moduleSize: 1, quietZone: QuietZone.none))
        #expect(image.height == matrix.height * 3)
        #expect(image.width == matrix.width)
    }

    // ── errors ──

    @Test func rejectsEmptyInput() {
        #expect(throws: EncodeError.emptyInput) {
            try BarGlyph.matrix(for: "", symbology: .pdf417)
        }
    }

    @Test func oversizedContentThrows() {
        let contents = String(repeating: "x", count: 2000)
        #expect(throws: EncodeError.self) {
            try BarGlyph.matrix(for: contents, symbology: .pdf417)
        }
    }

    // ── round trip against Vision ──

    @Test(arguments: [
        "BarGlyph PDF417",
        "abcdef",
        "0123456789012345678901234567890123456789",
        "Boarding pass: SFO -> TPE, seat 42A, gate B7",
    ])
    func visionDecodesRoundTrip(contents: String) throws {
        #expect(try roundTrip(contents, symbology: .pdf417, vision: .pdf417) == contents)
    }

    @Test func visionDecodesLongContent() throws {
        let contents = (0..<40).map { "row-\($0)" }.joined(separator: ";")
        #expect(try roundTrip(contents, symbology: .pdf417, vision: .pdf417) == contents)
    }
}

/// PDF417 (ISO/IEC 15438) encoder.
///
/// A stacked symbology: each row is a sequence of 17-module codewords framed
/// by start/stop patterns and row-indicator codewords. Content is encoded
/// with byte compaction (UTF-8 bytes, 6 bytes → 5 codewords in base 900);
/// error correction is Reed-Solomon over the prime field GF(929).
struct PDF417Encoder: SymbologyEncoder {
    private static let prime = 929
    private static let padCodeword = 900
    private static let byteLatchMultipleOf6 = 924
    private static let byteLatch = 901

    /// Total codewords in a symbol (descriptor + data + pad + EC) may not
    /// exceed the codeword value space.
    private static let maxCodewords = 929

    func encode(_ contents: String) throws(EncodeError) -> Matrix {
        guard !contents.isEmpty else { throw .emptyInput }
        let bytes = Array(contents.utf8)

        var data = Self.byteCompaction(bytes)

        // Specification-recommended minimum error correction level for the
        // data codeword count.
        let level: Int
        switch data.count {
        case ..<41: level = 2
        case ..<161: level = 3
        case ..<321: level = 4
        default: level = 5
        }
        let eccCount = 1 << (level + 1)

        let required = 1 + data.count + eccCount  // descriptor + data + EC
        guard required <= Self.maxCodewords else {
            let capacity = Self.maxCodewords - 1 - eccCount - 1  // minus descriptor & latch
            throw .dataTooLong(maximum: capacity / 5 * 6 + capacity % 5)
        }

        let (columns, rows) = Self.dimensions(forCodewordCount: required)
        let padCount = columns * rows - required
        data.append(contentsOf: repeatElement(Self.padCodeword, count: padCount))

        var message = [1 + data.count] + data  // symbol length descriptor first
        message += Self.errorCorrection(for: message, count: eccCount)

        return Self.layout(message, columns: columns, rows: rows, level: level)
    }

    // ── high-level encoding ──

    /// Byte compaction: groups of 6 bytes become 5 base-900 codewords;
    /// trailing bytes map one to one.
    static func byteCompaction(_ bytes: [UInt8]) -> [Int] {
        var codewords = [bytes.count.isMultiple(of: 6) ? byteLatchMultipleOf6 : byteLatch]
        var index = 0
        while bytes.count - index >= 6 {
            var value: UInt64 = 0
            for offset in 0..<6 {
                value = value << 8 | UInt64(bytes[index + offset])
            }
            var group = [Int](repeating: 0, count: 5)
            for position in stride(from: 4, through: 0, by: -1) {
                group[position] = Int(value % 900)
                value /= 900
            }
            codewords += group
            index += 6
        }
        while index < bytes.count {
            codewords.append(Int(bytes[index]))
            index += 1
        }
        return codewords
    }

    /// Picks a column count (1–30) whose row count is legal (3–90), preferring
    /// a roughly 2:1 wide symbol.
    private static func dimensions(forCodewordCount count: Int) -> (columns: Int, rows: Int) {
        var best: (columns: Int, rows: Int, score: Int)?
        for columns in 1...30 {
            let rows = max(3, (count + columns - 1) / columns)
            guard rows <= 90, columns * rows <= maxCodewords else { continue }
            let widthModules = 17 * columns + 69
            let heightModules = rows * 3
            let score = abs(widthModules - 2 * heightModules)
            if best == nil || score < best!.score {
                best = (columns, rows, score)
            }
        }
        // Reachable for any count ≤ maxCodewords (30 columns × 31 rows covers it).
        return (best!.columns, best!.rows)
    }

    // ── error correction over GF(929) ──

    /// Reed-Solomon parity: remainder of `message · x^k` divided by
    /// g(x) = ∏ (x - 3^i), negated in GF(929).
    static func errorCorrection(for message: [Int], count: Int) -> [Int] {
        let generator = generatorPolynomial(degree: count)
        var remainder = [Int](repeating: 0, count: count)
        for codeword in message {
            let factor = (codeword + remainder[0]) % prime
            remainder.removeFirst()
            remainder.append(0)
            guard factor != 0 else { continue }
            for degree in 0..<count {
                let subtrahend = factor * generator[degree + 1] % prime
                remainder[degree] = (remainder[degree] + prime - subtrahend) % prime
            }
        }
        return remainder.map { ($0 == 0 ? 0 : prime - $0) }
    }

    /// Coefficients of ∏_{i=1}^{degree} (x − 3^i), highest degree first.
    static func generatorPolynomial(degree: Int) -> [Int] {
        var generator = [1]
        var root = 1
        for _ in 1...degree {
            root = root * 3 % prime
            var next = [Int](repeating: 0, count: generator.count + 1)
            for (position, coefficient) in generator.enumerated() {
                next[position] = (next[position] + coefficient) % prime
                next[position + 1] =
                    (next[position + 1] + prime - coefficient * root % prime) % prime
            }
            generator = next
        }
        return generator
    }

    // ── low-level layout ──

    private static func layout(_ codewords: [Int], columns: Int, rows: Int, level: Int) -> Matrix {
        let width = 17 * (columns + 3) + 18
        var matrix = Matrix(width: width, height: rows)

        for row in 0..<rows {
            let cluster = row % 3
            let rowValue = 30 * (row / 3)

            let left: Int
            let right: Int
            switch cluster {
            case 0:
                left = rowValue + (rows - 1) / 3
                right = rowValue + columns - 1
            case 1:
                left = rowValue + level * 3 + (rows - 1) % 3
                right = rowValue + (rows - 1) / 3
            default:
                left = rowValue + columns - 1
                right = rowValue + level * 3 + (rows - 1) % 3
            }

            var x = 0
            func append(_ pattern: UInt32, bitCount: Int) {
                for shift in stride(from: bitCount - 1, through: 0, by: -1) {
                    matrix[x, row] = pattern >> shift & 1 == 1
                    x += 1
                }
            }

            let patterns = PDF417CodewordTable.clusters[cluster]
            append(PDF417CodewordTable.start, bitCount: 17)
            append(patterns[left], bitCount: 17)
            for column in 0..<columns {
                append(patterns[codewords[row * columns + column]], bitCount: 17)
            }
            append(patterns[right], bitCount: 17)
            append(PDF417CodewordTable.stop, bitCount: 18)
        }
        return matrix
    }
}

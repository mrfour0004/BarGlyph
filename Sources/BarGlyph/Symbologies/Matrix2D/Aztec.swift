/// Aztec (ISO/IEC 24778) encoder.
///
/// Content bytes are carried in a binary shift sequence, bit-stuffed into
/// words sized by the layer count, and extended with Reed-Solomon parity that
/// fills all remaining symbol capacity (23% + 3 words minimum). The layout —
/// central bullseye, mode message, reference grid, and data dominoes spiraling
/// outside-in — follows the specification via the zxing reference encoder.
struct AztecEncoder: SymbologyEncoder {
    /// Data word size in bits, indexed by layer count.
    private static let wordSizes: [Int] = [
        4, 6, 6, 8, 8, 8, 8, 8, 8, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
        10, 10, 10, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    ]

    /// ISO/IEC 24778 recommends at least 23% + 3 words of error correction.
    private static let errorCorrectionPercent = 23

    /// Specification maximum for 8-bit data (full symbol, 32 layers).
    private static let maxDataBytes = 1914

    private static let fields: [Int: GaloisField] = [
        4: GaloisField(bits: 4, polynomial: 0x13),
        6: GaloisField(bits: 6, polynomial: 0x43),
        8: GaloisField(bits: 8, polynomial: 0x12D),
        10: GaloisField(bits: 10, polynomial: 0x409),
        12: GaloisField(bits: 12, polynomial: 0x1069),
    ]

    func encode(_ contents: String) throws(EncodeError) -> Matrix {
        guard !contents.isEmpty else { throw .emptyInput }
        let bytes = Array(contents.utf8)

        // Binary shift from the initial Upper mode: code 31, a 5-bit length
        // (0 escapes to an 11-bit extended length), then raw bytes.
        guard bytes.count <= 31 + 2047 else {
            throw .dataTooLong(maximum: Self.maxDataBytes)
        }
        var bits = BitBuffer()
        bits.append(31, bitCount: 5)
        if bytes.count <= 31 {
            bits.append(bytes.count, bitCount: 5)
        } else {
            bits.append(0, bitCount: 5)
            bits.append(bytes.count - 31, bitCount: 11)
        }
        for byte in bytes {
            bits.append(Int(byte), bitCount: 8)
        }

        // Smallest symbol that fits data plus minimum error correction,
        // trying Compact1…Compact4 then Full4…Full32.
        let eccBits = bits.count * Self.errorCorrectionPercent / 100 + 11
        var compact = false
        var layers = 0
        var capacity = 0
        var wordSize = 0
        var stuffed: [Bool] = []
        var fits = false
        for attempt in 0...32 {
            compact = attempt <= 3
            layers = compact ? attempt + 1 : attempt
            capacity = ((compact ? 88 : 112) + 16 * layers) * layers
            guard bits.count + eccBits <= capacity else { continue }
            if wordSize != Self.wordSizes[layers] {
                wordSize = Self.wordSizes[layers]
                stuffed = Self.stuff(bits.bits, wordSize: wordSize)
            }
            // The compact mode message caps data words at 64.
            if compact && stuffed.count > wordSize * 64 { continue }
            if stuffed.count + eccBits <= capacity - capacity % wordSize {
                fits = true
                break
            }
        }
        guard fits else {
            throw .dataTooLong(maximum: Self.maxDataBytes)
        }

        let dataWords = Self.words(from: stuffed, wordSize: wordSize)
        let totalWords = capacity / wordSize
        let encoder = ReedSolomonEncoder(field: Self.fields[wordSize]!, firstRoot: 1)
        let parity = encoder.parity(for: dataWords, parityCount: totalWords - dataWords.count)

        var message = BitBuffer()
        message.append(0, bitCount: capacity % wordSize)
        for word in dataWords + parity {
            message.append(word, bitCount: wordSize)
        }

        return Self.layout(
            messageBits: message,
            modeMessage: Self.modeMessage(compact: compact, layers: layers, dataWords: dataWords.count),
            compact: compact,
            layers: layers
        )
    }

    // ── bit stuffing ──

    /// Splits bits into words, padding with 1s; a word whose leading
    /// `wordSize - 1` bits are all equal gets its last bit forced to the
    /// complement, and the displaced input bit restarts the next word.
    static func stuff(_ bits: [Bool], wordSize: Int) -> [Bool] {
        var output = BitBuffer()
        let mask = (1 << wordSize) - 2
        var index = 0
        while index < bits.count {
            var word = 0
            for offset in 0..<wordSize {
                if index + offset >= bits.count || bits[index + offset] {
                    word |= 1 << (wordSize - 1 - offset)
                }
            }
            if word & mask == mask {
                output.append(word & mask, bitCount: wordSize)
                index += wordSize - 1
            } else if word & mask == 0 {
                output.append(word | 1, bitCount: wordSize)
                index += wordSize - 1
            } else {
                output.append(word, bitCount: wordSize)
                index += wordSize
            }
        }
        return output.bits
    }

    private static func words(from bits: [Bool], wordSize: Int) -> [Int] {
        stride(from: 0, to: bits.count, by: wordSize).map { start in
            (0..<wordSize).reduce(0) { ($0 << 1) | (bits[start + $1] ? 1 : 0) }
        }
    }

    // ── mode message ──

    /// Layer and data word counts with GF(16) Reed-Solomon parity:
    /// 28 bits for compact symbols, 40 for full.
    static func modeMessage(compact: Bool, layers: Int, dataWords: Int) -> BitBuffer {
        var bits = BitBuffer()
        if compact {
            bits.append(layers - 1, bitCount: 2)
            bits.append(dataWords - 1, bitCount: 6)
        } else {
            bits.append(layers - 1, bitCount: 5)
            bits.append(dataWords - 1, bitCount: 11)
        }
        let words = Self.words(from: bits.bits, wordSize: 4)
        let encoder = ReedSolomonEncoder(field: fields[4]!, firstRoot: 1)
        let parity = encoder.parity(for: words, parityCount: (compact ? 7 : 10) - words.count)
        var message = BitBuffer()
        for word in words + parity {
            message.append(word, bitCount: 4)
        }
        return message
    }

    // ── layout ──

    private static func layout(
        messageBits: BitBuffer,
        modeMessage: BitBuffer,
        compact: Bool,
        layers: Int
    ) -> Matrix {
        let base = (compact ? 11 : 14) + layers * 4
        var alignmentMap = [Int](repeating: 0, count: base)
        let size: Int
        if compact {
            size = base
            for index in 0..<base { alignmentMap[index] = index }
        } else {
            // Full symbols insert a dotted reference grid line every 16
            // modules; map layout coordinates around them.
            size = base + 1 + 2 * ((base / 2 - 1) / 15)
            let baseCenter = base / 2
            let center = size / 2
            for index in 0..<baseCenter {
                let offset = index + index / 15
                alignmentMap[baseCenter - index - 1] = center - offset - 1
                alignmentMap[baseCenter + index] = center + offset + 1
            }
        }
        var matrix = Matrix(width: size, height: size)

        // Data dominoes, one ring of the spiral per layer, outermost first.
        var rowOffset = 0
        for layer in 0..<layers {
            let rowSize = (layers - layer) * 4 + (compact ? 9 : 12)
            for j in 0..<rowSize {
                let columnOffset = j * 2
                for k in 0..<2 {
                    if messageBits[rowOffset + columnOffset + k] {
                        matrix[alignmentMap[layer * 2 + k], alignmentMap[layer * 2 + j]] = true
                    }
                    if messageBits[rowOffset + rowSize * 2 + columnOffset + k] {
                        matrix[alignmentMap[layer * 2 + j], alignmentMap[base - 1 - layer * 2 - k]] = true
                    }
                    if messageBits[rowOffset + rowSize * 4 + columnOffset + k] {
                        matrix[alignmentMap[base - 1 - layer * 2 - k], alignmentMap[base - 1 - layer * 2 - j]] = true
                    }
                    if messageBits[rowOffset + rowSize * 6 + columnOffset + k] {
                        matrix[alignmentMap[base - 1 - layer * 2 - j], alignmentMap[layer * 2 + k]] = true
                    }
                }
            }
            rowOffset += rowSize * 8
        }

        drawModeMessage(&matrix, compact: compact, size: size, modeMessage: modeMessage)

        let center = size / 2
        if compact {
            drawBullseye(&matrix, center: center, radius: 5)
        } else {
            drawBullseye(&matrix, center: center, radius: 7)
            var gridOffset = 0
            var baseOffset = 0
            while baseOffset < base / 2 - 1 {
                var k = center & 1
                while k < size {
                    matrix[center - gridOffset, k] = true
                    matrix[center + gridOffset, k] = true
                    matrix[k, center - gridOffset] = true
                    matrix[k, center + gridOffset] = true
                    k += 2
                }
                baseOffset += 15
                gridOffset += 16
            }
        }
        return matrix
    }

    private static func drawBullseye(_ matrix: inout Matrix, center: Int, radius: Int) {
        for ring in stride(from: 0, to: radius, by: 2) {
            for position in (center - ring)...(center + ring) {
                matrix[position, center - ring] = true
                matrix[position, center + ring] = true
                matrix[center - ring, position] = true
                matrix[center + ring, position] = true
            }
        }
        // Orientation marks on the bullseye corners.
        matrix[center - radius, center - radius] = true
        matrix[center - radius + 1, center - radius] = true
        matrix[center - radius, center - radius + 1] = true
        matrix[center + radius, center - radius] = true
        matrix[center + radius, center - radius + 1] = true
        matrix[center + radius, center + radius - 1] = true
    }

    private static func drawModeMessage(
        _ matrix: inout Matrix, compact: Bool, size: Int, modeMessage: BitBuffer
    ) {
        let center = size / 2
        if compact {
            for i in 0..<7 {
                let offset = center - 3 + i
                if modeMessage[i] { matrix[offset, center - 5] = true }
                if modeMessage[i + 7] { matrix[center + 5, offset] = true }
                if modeMessage[20 - i] { matrix[offset, center + 5] = true }
                if modeMessage[27 - i] { matrix[center - 5, offset] = true }
            }
        } else {
            for i in 0..<10 {
                // i / 5 skips the reference grid line through the center.
                let offset = center - 5 + i + i / 5
                if modeMessage[i] { matrix[offset, center - 7] = true }
                if modeMessage[i + 10] { matrix[center + 7, offset] = true }
                if modeMessage[29 - i] { matrix[offset, center + 7] = true }
                if modeMessage[39 - i] { matrix[center - 7, offset] = true }
            }
        }
    }
}

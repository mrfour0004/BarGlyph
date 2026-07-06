/// QR Code (ISO/IEC 18004) encoder.
///
/// Encodes in byte mode with UTF-8 content bytes — the de-facto convention
/// scanners expect — automatically picking the smallest version (1–40) that
/// fits, computing Reed-Solomon error correction over GF(256), and selecting
/// the data mask with the lowest penalty score.
struct QREncoder: SymbologyEncoder {
    let errorCorrection: Symbology.QRErrorCorrection

    // ── specification tables (ISO/IEC 18004), indexed [level][version] ──
    // Level order: Low, Medium, Quartile, High. Index 0 is unused padding.

    private static let eccCodewordsPerBlock: [[Int]] = [
        [0, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28,
         28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
        [0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26,
         26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
        [0, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26,
         30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
        [0, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26,
         28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
    ]

    private static let errorCorrectionBlockCounts: [[Int]] = [
        [0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7,
         8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
        [0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14,
         16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
        [0, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21,
         20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
        [0, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25,
         25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81],
    ]

    private static let field = GaloisField(bits: 8, polynomial: 0x11D)

    // ── capacity ──

    /// Total modules available for codewords in a version, from the module
    /// count minus every function pattern.
    private static func rawDataModules(version: Int) -> Int {
        var result = (16 * version + 128) * version + 64
        if version >= 2 {
            let alignmentCount = version / 7 + 2
            result -= (25 * alignmentCount - 10) * alignmentCount - 55
            if version >= 7 {
                result -= 36
            }
        }
        return result
    }

    private static func totalCodewords(version: Int) -> Int {
        rawDataModules(version: version) / 8
    }

    private static func dataCodewords(version: Int, level: Int) -> Int {
        totalCodewords(version: version)
            - eccCodewordsPerBlock[level][version] * errorCorrectionBlockCounts[level][version]
    }

    // ── encoding ──

    func encode(_ contents: String) throws(EncodeError) -> Matrix {
        guard !contents.isEmpty else { throw .emptyInput }
        let bytes = Array(contents.utf8)
        let level = errorCorrection.tableIndex

        var version = 0
        for candidate in 1...40 {
            let needed = 4 + (candidate <= 9 ? 8 : 16) + bytes.count * 8
            if needed <= Self.dataCodewords(version: candidate, level: level) * 8 {
                version = candidate
                break
            }
        }
        guard version > 0 else {
            throw .dataTooLong(
                maximum: (Self.dataCodewords(version: 40, level: level) * 8 - 20) / 8)
        }

        let codewords = Self.buildCodewords(bytes: bytes, version: version, level: level)
        var symbol = QRSymbol(version: version)
        symbol.drawFunctionPatterns(formatLevelBits: errorCorrection.formatBits)
        symbol.drawCodewords(codewords)
        symbol.selectAndApplyBestMask(formatLevelBits: errorCorrection.formatBits)
        return symbol.modules
    }

    /// Data segment + terminator + padding, split into blocks, each extended
    /// with Reed-Solomon parity, then interleaved.
    private static func buildCodewords(bytes: [UInt8], version: Int, level: Int) -> [Int] {
        let dataCapacity = dataCodewords(version: version, level: level)

        var buffer = BitBuffer()
        buffer.append(0b0100, bitCount: 4)
        buffer.append(bytes.count, bitCount: version <= 9 ? 8 : 16)
        for byte in bytes {
            buffer.append(Int(byte), bitCount: 8)
        }
        buffer.append(0, bitCount: min(4, dataCapacity * 8 - buffer.count))
        if !buffer.count.isMultiple(of: 8) {
            buffer.append(0, bitCount: 8 - buffer.count % 8)
        }
        var data: [Int] = stride(from: 0, to: buffer.count, by: 8).map { start in
            (0..<8).reduce(0) { ($0 << 1) | (buffer[start + $1] ? 1 : 0) }
        }
        var padByte = 0xEC
        while data.count < dataCapacity {
            data.append(padByte)
            padByte = padByte == 0xEC ? 0x11 : 0xEC
        }

        // Split into blocks. The first blocks are one data codeword shorter
        // when the total doesn't divide evenly.
        let blockCount = errorCorrectionBlockCounts[level][version]
        let eccPerBlock = eccCodewordsPerBlock[level][version]
        let raw = totalCodewords(version: version)
        let shortBlockCount = blockCount - raw % blockCount
        let shortDataLength = raw / blockCount - eccPerBlock

        let encoder = ReedSolomonEncoder(field: field, firstRoot: 0)
        var blocks: [[Int]] = []
        var eccBlocks: [[Int]] = []
        var cursor = 0
        for index in 0..<blockCount {
            let length = shortDataLength + (index < shortBlockCount ? 0 : 1)
            let block = Array(data[cursor..<cursor + length])
            cursor += length
            blocks.append(block)
            eccBlocks.append(encoder.parity(for: block, parityCount: eccPerBlock))
        }

        var result: [Int] = []
        let longestBlock = shortDataLength + 1
        for position in 0..<longestBlock {
            for block in blocks where position < block.count {
                result.append(block[position])
            }
        }
        for position in 0..<eccPerBlock {
            for ecc in eccBlocks {
                result.append(ecc[position])
            }
        }
        return result
    }
}

/// A QR symbol under construction: the module grid plus a mask of function
/// modules (which data masking must not touch).
private struct QRSymbol {
    let version: Int
    let size: Int
    var modules: Matrix
    var isFunction: Matrix

    init(version: Int) {
        self.version = version
        size = version * 4 + 17
        modules = Matrix(width: size, height: size)
        isFunction = Matrix(width: size, height: size)
    }

    private mutating func setFunction(_ x: Int, _ y: Int, _ dark: Bool) {
        modules[x, y] = dark
        isFunction[x, y] = true
    }

    // ── function patterns ──

    mutating func drawFunctionPatterns(formatLevelBits: Int) {
        for i in 0..<size {
            setFunction(6, i, i.isMultiple(of: 2))
            setFunction(i, 6, i.isMultiple(of: 2))
        }
        drawFinder(3, 3)
        drawFinder(size - 4, 3)
        drawFinder(3, size - 4)

        let alignment = alignmentPositions()
        let last = alignment.count - 1
        for (i, x) in alignment.enumerated() {
            for (j, y) in alignment.enumerated() {
                let overlapsFinder = (i == 0 && j == 0) || (i == 0 && j == last) || (i == last && j == 0)
                guard !overlapsFinder else { continue }
                for dy in -2...2 {
                    for dx in -2...2 {
                        setFunction(x + dx, y + dy, max(abs(dx), abs(dy)) != 1)
                    }
                }
            }
        }

        drawFormatBits(formatLevelBits: formatLevelBits, mask: 0)  // reserves the modules
        drawVersionInformation()
    }

    private mutating func drawFinder(_ centerX: Int, _ centerY: Int) {
        for dy in -4...4 {
            for dx in -4...4 {
                let x = centerX + dx
                let y = centerY + dy
                guard x >= 0, x < size, y >= 0, y < size else { continue }
                let distance = max(abs(dx), abs(dy))
                setFunction(x, y, distance != 2 && distance != 4)
            }
        }
    }

    /// Center coordinates of alignment patterns for this version.
    private func alignmentPositions() -> [Int] {
        guard version > 1 else { return [] }
        let count = version / 7 + 2
        let step = version == 32
            ? 26
            : (version * 4 + count * 2 + 1) / (count * 2 - 2) * 2
        var positions = [6]
        var position = size - 7
        for _ in 1..<count {
            positions.insert(position, at: 1)
            position -= step
        }
        return positions
    }

    /// Format info: 5 data bits (level + mask) extended to 15 with BCH parity,
    /// XOR-masked, drawn in both required locations.
    mutating func drawFormatBits(formatLevelBits: Int, mask: Int) {
        let data = formatLevelBits << 3 | mask
        var remainder = data
        for _ in 0..<10 {
            remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537)
        }
        let bits = (data << 10 | remainder) ^ 0x5412

        func bit(_ index: Int) -> Bool { (bits >> index) & 1 == 1 }

        for i in 0...5 { setFunction(8, i, bit(i)) }
        setFunction(8, 7, bit(6))
        setFunction(8, 8, bit(7))
        setFunction(7, 8, bit(8))
        for i in 9..<15 { setFunction(14 - i, 8, bit(i)) }

        for i in 0...7 { setFunction(size - 1 - i, 8, bit(i)) }
        for i in 8..<15 { setFunction(8, size - 15 + i, bit(i)) }
        setFunction(8, size - 8, true)  // the fixed dark module
    }

    /// Version info for version 7+: 6 data bits extended to 18 with BCH parity.
    private mutating func drawVersionInformation() {
        guard version >= 7 else { return }
        var remainder = version
        for _ in 0..<12 {
            remainder = (remainder << 1) ^ ((remainder >> 11) * 0x1F25)
        }
        let bits = version << 12 | remainder
        for i in 0..<18 {
            let dark = (bits >> i) & 1 == 1
            let a = size - 11 + i % 3
            let b = i / 3
            setFunction(a, b, dark)
            setFunction(b, a, dark)
        }
    }

    // ── data placement ──

    /// Zigzag placement: column pairs from the right edge, alternating upward
    /// and downward, skipping the timing column and function modules.
    mutating func drawCodewords(_ codewords: [Int]) {
        let totalBits = codewords.count * 8
        var bitIndex = 0
        var right = size - 1
        while right >= 1 {
            if right == 6 { right = 5 }
            for vertical in 0..<size {
                for offset in 0..<2 {
                    let x = right - offset
                    let upward = ((right + 1) & 2) == 0
                    let y = upward ? size - 1 - vertical : vertical
                    guard !isFunction[x, y], bitIndex < totalBits else { continue }
                    modules[x, y] = (codewords[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1 == 1
                    bitIndex += 1
                }
            }
            right -= 2
        }
    }

    // ── masking ──

    mutating func selectAndApplyBestMask(formatLevelBits: Int) {
        var bestMask = 0
        var bestScore = Int.max
        for mask in 0..<8 {
            applyMask(mask)
            drawFormatBits(formatLevelBits: formatLevelBits, mask: mask)
            let score = penaltyScore()
            if score < bestScore {
                bestScore = score
                bestMask = mask
            }
            applyMask(mask)  // XOR twice restores the unmasked state
        }
        applyMask(bestMask)
        drawFormatBits(formatLevelBits: formatLevelBits, mask: bestMask)
    }

    private mutating func applyMask(_ mask: Int) {
        for y in 0..<size {
            for x in 0..<size where !isFunction[x, y] {
                let invert: Bool
                switch mask {
                case 0: invert = (x + y).isMultiple(of: 2)
                case 1: invert = y.isMultiple(of: 2)
                case 2: invert = x.isMultiple(of: 3)
                case 3: invert = (x + y).isMultiple(of: 3)
                case 4: invert = (x / 3 + y / 2).isMultiple(of: 2)
                case 5: invert = x * y % 2 + x * y % 3 == 0
                case 6: invert = (x * y % 2 + x * y % 3).isMultiple(of: 2)
                default: invert = ((x + y) % 2 + x * y % 3).isMultiple(of: 2)
                }
                if invert {
                    modules[x, y].toggle()
                }
            }
        }
    }

    /// ISO 18004 mask evaluation: adjacent runs, 2×2 blocks, finder-like
    /// patterns, and dark-module balance.
    private func penaltyScore() -> Int {
        var score = 0

        // Rule 1: runs of ≥5 same-colored modules, rows and columns.
        for y in 0..<size {
            var rowRun = 1
            var columnRun = 1
            for x in 1..<size {
                if modules[x, y] == modules[x - 1, y] {
                    rowRun += 1
                    if rowRun == 5 { score += 3 } else if rowRun > 5 { score += 1 }
                } else {
                    rowRun = 1
                }
                if modules[y, x] == modules[y, x - 1] {
                    columnRun += 1
                    if columnRun == 5 { score += 3 } else if columnRun > 5 { score += 1 }
                } else {
                    columnRun = 1
                }
            }
        }

        // Rule 2: 2×2 blocks of a single color.
        for y in 0..<(size - 1) {
            for x in 0..<(size - 1) {
                let color = modules[x, y]
                if color == modules[x + 1, y], color == modules[x, y + 1],
                   color == modules[x + 1, y + 1] {
                    score += 3
                }
            }
        }

        // Rule 3: finder-like 1:1:3:1:1 pattern with 4 light modules beside it.
        for y in 0..<size {
            var rowWindow = 0
            var columnWindow = 0
            for x in 0..<size {
                rowWindow = ((rowWindow << 1) | (modules[x, y] ? 1 : 0)) & 0x7FF
                columnWindow = ((columnWindow << 1) | (modules[y, x] ? 1 : 0)) & 0x7FF
                if x >= 10 {
                    if rowWindow == 0x5D0 || rowWindow == 0x05D { score += 40 }
                    if columnWindow == 0x5D0 || columnWindow == 0x05D { score += 40 }
                }
            }
        }

        // Rule 4: 10 points per 5% deviation from 50% dark.
        var dark = 0
        for y in 0..<size {
            for x in 0..<size where modules[x, y] {
                dark += 1
            }
        }
        let total = size * size
        let deviation = (abs(dark * 20 - total * 10) + total - 1) / total - 1
        score += deviation * 10

        return score
    }
}

/// EAN/UPC (ISO/IEC 15420) encoder covering EAN-13, EAN-8, and UPC-A.
///
/// Digits are drawn from three 7-module sets: L and G on the left half (their
/// mix encodes EAN-13's leading digit), R on the right. UPC-A is encoded as an
/// EAN-13 with a leading zero.
struct EANEncoder: SymbologyEncoder {
    enum Variant {
        case ean13, ean8, upcA

        /// Payload length excluding the check digit.
        var payloadLength: Int {
            switch self {
            case .ean13: 12
            case .ean8: 7
            case .upcA: 11
            }
        }
    }

    let variant: Variant

    /// L-set patterns, 7 bits each, MSB first. R = bitwise complement,
    /// G = mirrored R.
    private static let lPatterns: [Int] = [
        0x0D, 0x19, 0x13, 0x3D, 0x23, 0x31, 0x2F, 0x3B, 0x37, 0x0B,
    ]

    private static let gPatterns: [Int] = [
        0x27, 0x33, 0x1B, 0x21, 0x1D, 0x39, 0x05, 0x11, 0x09, 0x17,
    ]

    /// L/G choice (0 = L, 1 = G) for the six left digits of an EAN-13,
    /// indexed by the leading digit; bit 5 governs the first left digit.
    private static let leftParities: [Int] = [
        0x00, 0x0B, 0x0D, 0x0E, 0x13, 0x19, 0x1C, 0x15, 0x16, 0x1A,
    ]

    func encode(_ contents: String) throws(EncodeError) -> Matrix {
        guard !contents.isEmpty else { throw .emptyInput }

        var digits: [Int] = []
        for character in contents {
            guard character.isASCII, let digit = character.wholeNumberValue, (0...9).contains(digit) else {
                throw .unsupportedCharacter(character)
            }
            digits.append(digit)
        }

        let payloadLength = variant.payloadLength
        switch digits.count {
        case payloadLength:
            digits.append(Self.checkDigit(for: digits))
        case payloadLength + 1:
            guard digits.last == Self.checkDigit(for: Array(digits.dropLast())) else {
                throw .invalidCheckDigit
            }
        default:
            throw .invalidLength(
                expected: "\(payloadLength) or \(payloadLength + 1) digits",
                actual: digits.count
            )
        }

        if variant == .upcA {
            digits.insert(0, at: 0)
        }

        switch variant {
        case .ean13, .upcA: return Matrix(row: ean13Row(digits))
        case .ean8: return Matrix(row: ean8Row(digits))
        }
    }

    /// GTIN check digit: weights alternate 3, 1 leftward from the digit
    /// adjacent to the check position.
    static func checkDigit(for payload: [Int]) -> Int {
        var sum = 0
        for (index, digit) in payload.reversed().enumerated() {
            sum += digit * (index.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - sum % 10) % 10
    }

    private func ean13Row(_ digits: [Int]) -> [Bool] {
        let parity = Self.leftParities[digits[0]]
        var row: [Bool] = []
        appendGuard(&row)
        for position in 1...6 {
            let useG = parity & (1 << (6 - position)) != 0
            let patterns = useG ? Self.gPatterns : Self.lPatterns
            append(pattern: patterns[digits[position]], to: &row)
        }
        appendCenter(&row)
        for position in 7...12 {
            append(pattern: ~Self.lPatterns[digits[position]] & 0x7F, to: &row)
        }
        appendGuard(&row)
        return row
    }

    private func ean8Row(_ digits: [Int]) -> [Bool] {
        var row: [Bool] = []
        appendGuard(&row)
        for position in 0...3 {
            append(pattern: Self.lPatterns[digits[position]], to: &row)
        }
        appendCenter(&row)
        for position in 4...7 {
            append(pattern: ~Self.lPatterns[digits[position]] & 0x7F, to: &row)
        }
        appendGuard(&row)
        return row
    }

    private func append(pattern: Int, to row: inout [Bool]) {
        for bit in stride(from: 6, through: 0, by: -1) {
            row.append(pattern & (1 << bit) != 0)
        }
    }

    private func appendGuard(_ row: inout [Bool]) {
        row.append(contentsOf: [true, false, true])
    }

    private func appendCenter(_ row: inout [Bool]) {
        row.append(contentsOf: [false, true, false, true, false])
    }
}

/// Code 39 (ISO/IEC 16388) encoder.
///
/// Each character is nine elements (five bars, four spaces), exactly three of
/// them wide. This encoder uses a 3:1 wide-to-narrow ratio with a one-module
/// inter-character gap, so every character spans 15 modules.
struct Code39Encoder: SymbologyEncoder {
    let includeCheckDigit: Bool

    /// The 43 encodable characters; a character's index is its check-digit value.
    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%")

    /// Nine-bit element patterns, MSB first; a set bit marks a wide element.
    /// Elements alternate bar, space, bar, … starting with a bar.
    private static let encodings: [UInt16] = [
        0x034, 0x121, 0x061, 0x160, 0x031, 0x130, 0x070, 0x025, 0x124, 0x064, // 0-9
        0x109, 0x049, 0x148, 0x019, 0x118, 0x058, 0x00D, 0x10C, 0x04C, 0x01C, // A-J
        0x103, 0x043, 0x142, 0x013, 0x112, 0x052, 0x007, 0x106, 0x046, 0x016, // K-T
        0x181, 0x0C1, 0x1C0, 0x091, 0x190, 0x0D0, 0x085, 0x184, 0x0C4, 0x0A8, // U-Z, -, ., space, $
        0x0A2, 0x08A, 0x02A,                                                  // /, +, %
    ]

    /// The `*` start/stop pattern.
    private static let startStop: UInt16 = 0x094

    func encode(_ contents: String) throws(EncodeError) -> Matrix {
        guard !contents.isEmpty else { throw .emptyInput }

        var values: [Int] = []
        for character in contents {
            guard let value = Self.alphabet.firstIndex(of: character) else {
                throw .unsupportedCharacter(character)
            }
            values.append(value)
        }
        if includeCheckDigit {
            values.append(values.reduce(0, +) % 43)
        }

        var row: [Bool] = []
        Self.append(pattern: Self.startStop, to: &row)
        for value in values {
            row.append(false)
            Self.append(pattern: Self.encodings[value], to: &row)
        }
        row.append(false)
        Self.append(pattern: Self.startStop, to: &row)
        return Matrix(row: row)
    }

    private static func append(pattern: UInt16, to row: inout [Bool]) {
        for element in 0..<9 {
            let isWide = pattern & (1 << (8 - element)) != 0
            let isBar = element.isMultiple(of: 2)
            row.append(contentsOf: repeatElement(isBar, count: isWide ? 3 : 1))
        }
    }
}

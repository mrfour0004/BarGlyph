/// Code 128 (ISO/IEC 15417) encoder.
///
/// Encodes the full ASCII range. Each symbol is six elements (three bars,
/// three spaces) spanning 11 modules; the stop pattern spans 13. The encoder
/// switches between code sets automatically: runs of digits use the
/// double-density code set C, control characters force code set A, and
/// everything else uses code set B.
struct Code128Encoder: SymbologyEncoder {
    private enum CodeSet { case a, b, c }

    private static let codeC = 99
    private static let codeB = 100
    private static let codeA = 101
    private static let startA = 103
    private static let startB = 104
    private static let startC = 105
    private static let stop = 106

    /// Element widths (bar, space, bar, space, bar, space) for values 0–105,
    /// plus the seven-element stop pattern at index 106. Every symbol spans
    /// 11 modules; the stop pattern spans 13.
    static let patterns: [[Int]] = [
        [2, 1, 2, 2, 2, 2], [2, 2, 2, 1, 2, 2], [2, 2, 2, 2, 2, 1], [1, 2, 1, 2, 2, 3],
        [1, 2, 1, 3, 2, 2], [1, 3, 1, 2, 2, 2], [1, 2, 2, 2, 1, 3], [1, 2, 2, 3, 1, 2],
        [1, 3, 2, 2, 1, 2], [2, 2, 1, 2, 1, 3], [2, 2, 1, 3, 1, 2], [2, 3, 1, 2, 1, 2],
        [1, 1, 2, 2, 3, 2], [1, 2, 2, 1, 3, 2], [1, 2, 2, 2, 3, 1], [1, 1, 3, 2, 2, 2],
        [1, 2, 3, 1, 2, 2], [1, 2, 3, 2, 2, 1], [2, 2, 3, 2, 1, 1], [2, 2, 1, 1, 3, 2],
        [2, 2, 1, 2, 3, 1], [2, 1, 3, 2, 1, 2], [2, 2, 3, 1, 1, 2], [3, 1, 2, 1, 3, 1],
        [3, 1, 1, 2, 2, 2], [3, 2, 1, 1, 2, 2], [3, 2, 1, 2, 2, 1], [3, 1, 2, 2, 1, 2],
        [3, 2, 2, 1, 1, 2], [3, 2, 2, 2, 1, 1], [2, 1, 2, 1, 2, 3], [2, 1, 2, 3, 2, 1],
        [2, 3, 2, 1, 2, 1], [1, 1, 1, 3, 2, 3], [1, 3, 1, 1, 2, 3], [1, 3, 1, 3, 2, 1],
        [1, 1, 2, 3, 1, 3], [1, 3, 2, 1, 1, 3], [1, 3, 2, 3, 1, 1], [2, 1, 1, 3, 1, 3],
        [2, 3, 1, 1, 1, 3], [2, 3, 1, 3, 1, 1], [1, 1, 2, 1, 3, 3], [1, 1, 2, 3, 3, 1],
        [1, 3, 2, 1, 3, 1], [1, 1, 3, 1, 2, 3], [1, 1, 3, 3, 2, 1], [1, 3, 3, 1, 2, 1],
        [3, 1, 3, 1, 2, 1], [2, 1, 1, 3, 3, 1], [2, 3, 1, 1, 3, 1], [2, 1, 3, 1, 1, 3],
        [2, 1, 3, 3, 1, 1], [2, 1, 3, 1, 3, 1], [3, 1, 1, 1, 2, 3], [3, 1, 1, 3, 2, 1],
        [3, 3, 1, 1, 2, 1], [3, 1, 2, 1, 1, 3], [3, 1, 2, 3, 1, 1], [3, 3, 2, 1, 1, 1],
        [3, 1, 4, 1, 1, 1], [2, 2, 1, 4, 1, 1], [4, 3, 1, 1, 1, 1], [1, 1, 1, 2, 2, 4],
        [1, 1, 1, 4, 2, 2], [1, 2, 1, 1, 2, 4], [1, 2, 1, 4, 2, 1], [1, 4, 1, 1, 2, 2],
        [1, 4, 1, 2, 2, 1], [1, 1, 2, 2, 1, 4], [1, 1, 2, 4, 1, 2], [1, 2, 2, 1, 1, 4],
        [1, 2, 2, 4, 1, 1], [1, 4, 2, 1, 1, 2], [1, 4, 2, 2, 1, 1], [2, 4, 1, 2, 1, 1],
        [2, 2, 1, 1, 1, 4], [4, 1, 3, 1, 1, 1], [2, 4, 1, 1, 1, 2], [1, 3, 4, 1, 1, 1],
        [1, 1, 1, 2, 4, 2], [1, 2, 1, 1, 4, 2], [1, 2, 1, 2, 4, 1], [1, 1, 4, 2, 1, 2],
        [1, 2, 4, 1, 1, 2], [1, 2, 4, 2, 1, 1], [4, 1, 1, 2, 1, 2], [4, 2, 1, 1, 1, 2],
        [4, 2, 1, 2, 1, 1], [2, 1, 2, 1, 4, 1], [2, 1, 4, 1, 2, 1], [4, 1, 2, 1, 2, 1],
        [1, 1, 1, 1, 4, 3], [1, 1, 1, 3, 4, 1], [1, 3, 1, 1, 4, 1], [1, 1, 4, 1, 1, 3],
        [1, 1, 4, 3, 1, 1], [4, 1, 1, 1, 1, 3], [4, 1, 1, 3, 1, 1], [1, 1, 3, 1, 4, 1],
        [1, 1, 4, 1, 3, 1], [3, 1, 1, 1, 4, 1], [4, 1, 1, 1, 3, 1], [2, 1, 1, 4, 1, 2],
        [2, 1, 1, 2, 1, 4], [2, 1, 1, 2, 3, 2], [2, 3, 3, 1, 1, 1, 2],
    ]

    func encode(_ contents: String) throws(EncodeError) -> Matrix {
        guard !contents.isEmpty else { throw .emptyInput }

        var characters: [UInt8] = []
        for character in contents {
            guard
                character.unicodeScalars.count == 1,
                let scalar = character.unicodeScalars.first,
                scalar.value < 128
            else {
                throw .unsupportedCharacter(character)
            }
            characters.append(UInt8(scalar.value))
        }

        var values = symbolValues(for: characters)

        var checksum = values[0]
        for (position, value) in values.enumerated().dropFirst() {
            checksum = (checksum + position * value) % 103
        }
        values.append(checksum)
        values.append(Self.stop)

        var row: [Bool] = []
        for value in values {
            for (element, width) in Self.patterns[value].enumerated() {
                row.append(contentsOf: repeatElement(element.isMultiple(of: 2), count: width))
            }
        }
        return Matrix(row: row)
    }

    /// Converts ASCII characters to symbol values, starting with a start code
    /// and inserting code-set switches where they pay off.
    private func symbolValues(for characters: [UInt8]) -> [Int] {
        var values: [Int] = []
        var index = 0
        var current: CodeSet

        if digitRun(in: characters, from: 0) >= 4 {
            current = .c
            values.append(Self.startC)
        } else {
            current = preferredLetterSet(in: characters, from: 0)
            values.append(current == .a ? Self.startA : Self.startB)
        }

        while index < characters.count {
            let character = characters[index]
            switch current {
            case .c:
                if digitRun(in: characters, from: index) >= 2 {
                    values.append(Int(character - 48) * 10 + Int(characters[index + 1] - 48))
                    index += 2
                } else {
                    current = preferredLetterSet(in: characters, from: index)
                    values.append(current == .a ? Self.codeA : Self.codeB)
                }

            case .a, .b:
                let run = digitRun(in: characters, from: index)
                if run >= 6 || (run >= 4 && run == characters.count - index) {
                    values.append(Self.codeC)
                    current = .c
                    continue
                }
                if current == .a, character >= 96 {
                    values.append(Self.codeB)
                    current = .b
                    continue
                }
                if current == .b, character < 32 {
                    values.append(Self.codeA)
                    current = .a
                    continue
                }
                if character < 32 {
                    values.append(Int(character) + 64)
                } else {
                    values.append(Int(character) - 32)
                }
                index += 1
            }
        }
        return values
    }

    /// Number of consecutive ASCII digits starting at `index`.
    private func digitRun(in characters: [UInt8], from index: Int) -> Int {
        var count = 0
        while index + count < characters.count,
              (48...57).contains(characters[index + count]) {
            count += 1
        }
        return count
    }

    /// Picks code set A or B by scanning ahead for the first decisive
    /// character: a control character needs A, a lowercase letter needs B.
    private func preferredLetterSet(in characters: [UInt8], from index: Int) -> CodeSet {
        for character in characters[index...] {
            if character < 32 { return .a }
            if character >= 96 { return .b }
        }
        return .b
    }
}

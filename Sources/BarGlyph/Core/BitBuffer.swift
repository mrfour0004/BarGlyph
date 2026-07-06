/// An append-only sequence of bits, MSB-first per appended value.
struct BitBuffer {
    private(set) var bits: [Bool] = []

    var count: Int { bits.count }

    mutating func append(_ value: Int, bitCount: Int) {
        for shift in stride(from: bitCount - 1, through: 0, by: -1) {
            bits.append((value >> shift) & 1 == 1)
        }
    }

    subscript(index: Int) -> Bool { bits[index] }
}

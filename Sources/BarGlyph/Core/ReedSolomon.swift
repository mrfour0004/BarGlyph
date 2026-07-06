/// GF(2^m) arithmetic with generator element α = 2.
///
/// Shared by symbologies whose error correction works over a binary Galois
/// field (QR uses GF(256) with polynomial 0x11D; Aztec uses GF(16) through
/// GF(4096) with its own polynomials). Addition in GF(2^m) is XOR.
struct GaloisField: Sendable {
    /// Field size, 2^m.
    let size: Int
    private let expTable: [Int]
    private let logTable: [Int]

    /// - Parameters:
    ///   - bits: The exponent m of the field size 2^m.
    ///   - polynomial: The primitive reduction polynomial, including the x^m term.
    init(bits: Int, polynomial: Int) {
        let size = 1 << bits
        var expTable = [Int](repeating: 0, count: size * 2)
        var logTable = [Int](repeating: 0, count: size)
        var value = 1
        for power in 0..<(size - 1) {
            expTable[power] = value
            logTable[value] = power
            value <<= 1
            if value & size != 0 {
                value ^= polynomial
            }
        }
        // Duplicate so products of two logs index without a modulo.
        for power in (size - 1)..<(size * 2) {
            expTable[power] = expTable[power - (size - 1)]
        }
        self.size = size
        self.expTable = expTable
        self.logTable = logTable
    }

    func multiply(_ a: Int, _ b: Int) -> Int {
        if a == 0 || b == 0 { return 0 }
        return expTable[logTable[a] + logTable[b]]
    }

    /// α raised to `power`.
    func exponential(_ power: Int) -> Int {
        expTable[power % (size - 1)]
    }
}

/// Systematic Reed-Solomon encoder over GF(2^m).
struct ReedSolomonEncoder {
    let field: GaloisField

    /// The exponent of the generator polynomial's first root: QR uses roots
    /// α^0…α^(k-1), Aztec uses α^1…α^k.
    let firstRoot: Int

    /// Computes `parityCount` parity symbols for `data` (polynomial division
    /// remainder of `data · x^k` by the generator polynomial).
    func parity(for data: [Int], parityCount: Int) -> [Int] {
        // g(x) = ∏ (x - α^(firstRoot + i)), coefficients highest-degree first.
        var generator = [1]
        for rootIndex in 0..<parityCount {
            let root = field.exponential(firstRoot + rootIndex)
            var next = [Int](repeating: 0, count: generator.count + 1)
            for (degree, coefficient) in generator.enumerated() {
                next[degree] ^= coefficient
                next[degree + 1] ^= field.multiply(coefficient, root)
            }
            generator = next
        }

        var remainder = [Int](repeating: 0, count: parityCount)
        for symbol in data {
            let factor = symbol ^ remainder[0]
            remainder.removeFirst()
            remainder.append(0)
            guard factor != 0 else { continue }
            for degree in 0..<parityCount {
                remainder[degree] ^= field.multiply(generator[degree + 1], factor)
            }
        }
        return remainder
    }
}

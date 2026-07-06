/// The barcode symbologies BarGlyph can generate, with their per-symbology options.
public enum Symbology: Sendable, Equatable {
    /// Code 39 — alphanumeric 1D barcode (digits, uppercase letters, `-. $/+%`).
    ///
    /// - Parameter includeCheckDigit: Appends the optional modulo-43 check character.
    case code39(includeCheckDigit: Bool)

    /// Code 128 — full-ASCII 1D barcode with automatic code set optimization.
    case code128
}

extension Symbology {
    /// Code 39 without a check digit.
    public static var code39: Symbology { .code39(includeCheckDigit: false) }
}

extension Symbology {
    /// The encoder implementing this symbology.
    var encoder: any SymbologyEncoder {
        switch self {
        case .code39(let includeCheckDigit):
            Code39Encoder(includeCheckDigit: includeCheckDigit)
        case .code128:
            Code128Encoder()
        }
    }

    /// Whether this is a 1D symbology, rendered by stretching a single module
    /// row to the requested bar height.
    var isLinear: Bool {
        switch self {
        case .code39, .code128: true
        }
    }

    /// The quiet zone the symbology's specification requires, in modules.
    var standardQuietZoneModules: Int {
        switch self {
        case .code39, .code128: 10
        }
    }
}

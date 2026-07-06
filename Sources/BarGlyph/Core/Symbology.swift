/// The barcode symbologies BarGlyph can generate, with their per-symbology options.
public enum Symbology: Sendable, Equatable {
    /// Code 39 — alphanumeric 1D barcode (digits, uppercase letters, `-. $/+%`).
    ///
    /// - Parameter includeCheckDigit: Appends the optional modulo-43 check character.
    case code39(includeCheckDigit: Bool)

    /// Code 128 — full-ASCII 1D barcode with automatic code set optimization.
    case code128

    /// EAN-13 — international retail product barcode. Accepts 12 digits
    /// (check digit appended automatically) or 13 digits (check digit verified).
    case ean13

    /// EAN-8 — short-form retail barcode. Accepts 7 or 8 digits.
    case ean8

    /// UPC-A — North American retail barcode; structurally an EAN-13 with a
    /// leading zero. Accepts 11 or 12 digits.
    case upcA

    /// QR Code — general-purpose 2D barcode. Content is encoded in byte mode
    /// as UTF-8; version (size) is selected automatically.
    case qr(errorCorrection: QRErrorCorrection)

    /// PDF417 — stacked 2D barcode used on IDs and boarding passes. Content is
    /// encoded with byte compaction; dimensions and error correction level are
    /// selected automatically.
    case pdf417
}

extension Symbology {
    /// Code 39 without a check digit.
    public static var code39: Symbology { .code39(includeCheckDigit: false) }

    /// QR Code with medium (~15%) error correction.
    public static var qr: Symbology { .qr(errorCorrection: .medium) }

    /// QR Code error correction level: the fraction of codewords that can be
    /// restored after damage.
    public enum QRErrorCorrection: Sendable, Equatable {
        /// ~7% recovery.
        case low
        /// ~15% recovery.
        case medium
        /// ~25% recovery.
        case quartile
        /// ~30% recovery.
        case high

        /// Row index in the specification capacity tables (L, M, Q, H order).
        var tableIndex: Int {
            switch self {
            case .low: 0
            case .medium: 1
            case .quartile: 2
            case .high: 3
            }
        }

        /// The two-bit level indicator carried in the format information.
        var formatBits: Int {
            switch self {
            case .low: 1
            case .medium: 0
            case .quartile: 3
            case .high: 2
            }
        }
    }
}

/// Specification-required quiet zone, in modules, per side.
struct QuietZoneSpec {
    var leading: Int
    var trailing: Int
    /// Applied above and below. Zero for 1D symbologies.
    var vertical: Int

    static func linear(leading: Int, trailing: Int) -> QuietZoneSpec {
        QuietZoneSpec(leading: leading, trailing: trailing, vertical: 0)
    }

    static func uniform(_ modules: Int) -> QuietZoneSpec {
        QuietZoneSpec(leading: modules, trailing: modules, vertical: modules)
    }
}

extension Symbology {
    /// The encoder implementing this symbology.
    var encoder: any SymbologyEncoder {
        switch self {
        case .code39(let includeCheckDigit):
            Code39Encoder(includeCheckDigit: includeCheckDigit)
        case .code128:
            Code128Encoder()
        case .ean13:
            EANEncoder(variant: .ean13)
        case .ean8:
            EANEncoder(variant: .ean8)
        case .upcA:
            EANEncoder(variant: .upcA)
        case .qr(let errorCorrection):
            QREncoder(errorCorrection: errorCorrection)
        case .pdf417:
            PDF417Encoder()
        }
    }

    /// Whether this is a 1D symbology, rendered by stretching a single module
    /// row to the requested bar height.
    var isLinear: Bool {
        switch self {
        case .code39, .code128, .ean13, .ean8, .upcA: true
        case .qr, .pdf417: false
        }
    }

    /// The quiet zone the symbology's specification requires.
    var standardQuietZone: QuietZoneSpec {
        switch self {
        case .code39, .code128: .linear(leading: 10, trailing: 10)
        case .ean13: .linear(leading: 11, trailing: 7)
        case .ean8: .linear(leading: 7, trailing: 7)
        case .upcA: .linear(leading: 9, trailing: 9)
        case .qr: .uniform(4)
        case .pdf417: .uniform(2)
        }
    }

    /// How many module heights one matrix row occupies when rendered. Stacked
    /// symbologies draw tall rows: PDF417 specifies a 3:1 row height.
    var rowHeightMultiplier: Int {
        switch self {
        case .pdf417: 3
        default: 1
        }
    }
}

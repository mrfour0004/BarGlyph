/// Errors thrown while encoding content into a barcode symbol.
public enum EncodeError: Error, Equatable, Sendable {
    /// The content was empty but the symbology requires at least one character.
    case emptyInput

    /// The content contained a character the symbology cannot represent.
    case unsupportedCharacter(Character)

    /// The content length is invalid for a fixed-length symbology (e.g. EAN-13).
    case invalidLength(expected: String, actual: Int)

    /// The content carried a check digit that does not match its payload.
    case invalidCheckDigit

    /// The content exceeds the symbology's capacity.
    case dataTooLong(maximum: Int)
}

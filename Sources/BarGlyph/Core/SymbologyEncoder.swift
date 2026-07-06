/// A barcode encoding algorithm: turns textual content into a module ``Matrix``.
///
/// Encoders are pure and platform-independent — they know nothing about pixels
/// or colors. Turning a matrix into an image is the renderer's job, which keeps
/// the encoding core independently testable.
protocol SymbologyEncoder: Sendable {
    /// Encodes `contents` into a matrix of modules.
    ///
    /// 1D symbologies return a matrix with `height == 1`.
    func encode(_ contents: String) throws(EncodeError) -> Matrix
}

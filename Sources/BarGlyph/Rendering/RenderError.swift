/// Errors thrown while rendering a ``Matrix`` into an image.
public enum RenderError: Error, Sendable {
    /// The render options describe an undrawable image (e.g. non-positive
    /// `moduleSize` or `barHeight`).
    case invalidOptions(description: String)

    /// The bitmap context could not be created.
    case contextCreationFailed

    /// PNG encoding failed.
    case pngEncodingFailed
}

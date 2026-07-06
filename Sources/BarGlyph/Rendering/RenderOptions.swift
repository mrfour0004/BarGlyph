import CoreGraphics

/// The quiet zone (light margin) surrounding a rendered barcode.
public enum QuietZone: Sendable, Equatable {
    /// The minimum the symbology's specification requires (e.g. 10 modules for
    /// Code 39). The safe default for scannability.
    case standard

    /// An explicit width in modules.
    case modules(Int)

    /// No quiet zone. The symbol may not scan reliably against a busy background.
    case none
}

/// Appearance options for rendering a barcode image.
public struct RenderOptions: Sendable, Equatable {
    /// Edge length of one module, in pixels. Integer values render crisp edges.
    public var moduleSize: CGFloat

    /// Total bar height in pixels. Used by 1D symbologies only.
    public var barHeight: CGFloat

    /// Light margin around the symbol. 1D symbologies apply it horizontally only.
    public var quietZone: QuietZone

    /// Color of dark modules.
    public var foregroundColor: Color

    /// Color of light modules and the quiet zone.
    public var backgroundColor: Color

    public init(
        moduleSize: CGFloat = 3,
        barHeight: CGFloat = 60,
        quietZone: QuietZone = .standard,
        foregroundColor: Color = .black,
        backgroundColor: Color = .white
    ) {
        self.moduleSize = moduleSize
        self.barHeight = barHeight
        self.quietZone = quietZone
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
}

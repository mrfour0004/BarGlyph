import CoreGraphics

/// An sRGB color used to configure rendering.
///
/// A plain value type independent of UIKit/AppKit color classes, so render
/// options stay `Sendable` and trivially constructible.
public struct Color: Sendable, Equatable {
    /// Red component, `0...1`.
    public var red: Double
    /// Green component, `0...1`.
    public var green: Double
    /// Blue component, `0...1`.
    public var blue: Double
    /// Alpha component, `0...1`.
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Opaque black — the conventional bar/module color.
    public static let black = Color(red: 0, green: 0, blue: 0)

    /// Opaque white — the conventional background color.
    public static let white = Color(red: 1, green: 1, blue: 1)

    var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

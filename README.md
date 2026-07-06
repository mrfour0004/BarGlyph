# BarGlyph

A Swift package for generating 1D & 2D barcode images.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+

## Installation

Add BarGlyph to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/BarGlyph.git", from: "0.1.0")
]
```

## Usage

```swift
import BarGlyph

// One-liner: encode and render
let image = try BarGlyph.image(for: "ABC-123", symbology: .code39)

// PNG data with custom appearance
let png = try BarGlyph.pngData(
    for: "ABC-123",
    symbology: .code39(includeCheckDigit: true),
    options: .init(moduleSize: 4, barHeight: 90)
)

// Platform-independent encoding result (module grid)
let matrix = try BarGlyph.matrix(for: "ABC-123", symbology: .code39)
```

## Supported symbologies

| Symbology | Type | Status |
|---|---|---|
| Code 39 | 1D | ✅ |
| Code 128 | 1D | Planned |
| EAN-13 / EAN-8 / UPC-A | 1D | Planned |
| QR Code | 2D | Planned |
| PDF417 | 2D | Planned |
| Aztec | 2D | Planned |

## License

MIT

/// A rectangular grid of barcode modules.
///
/// A *module* is the smallest logical unit of a barcode. `true` marks a dark
/// module (a bar or filled cell); `false` marks a light module.
///
/// Both 1D and 2D symbologies produce a `Matrix`, so a single renderer can draw
/// either: a 1D barcode is a matrix with `height == 1`, stretched vertically to
/// the requested bar height at render time.
///
/// Modules are stored row-major; row `0` is the top row.
public struct Matrix: Sendable, Equatable {
    /// Number of module columns.
    public let width: Int

    /// Number of module rows. Always `1` for 1D symbologies.
    public let height: Int

    private var modules: [Bool]

    /// Creates a matrix from explicit row-major module data.
    ///
    /// - Precondition: `modules.count == width * height`.
    public init(width: Int, height: Int, modules: [Bool]) {
        precondition(width >= 0 && height >= 0, "dimensions must be non-negative")
        precondition(modules.count == width * height, "modules count must equal width * height")
        self.width = width
        self.height = height
        self.modules = modules
    }

    /// Creates a matrix of the given size with every module light.
    public init(width: Int, height: Int) {
        self.init(width: width, height: height, modules: Array(repeating: false, count: width * height))
    }

    /// Creates a single-row matrix from a 1D bar pattern.
    public init(row: [Bool]) {
        self.init(width: row.count, height: 1, modules: row)
    }

    /// Accesses the module at column `x`, row `y`.
    public subscript(x: Int, y: Int) -> Bool {
        get {
            precondition(x >= 0 && x < width && y >= 0 && y < height, "index out of bounds")
            return modules[y * width + x]
        }
        set {
            precondition(x >= 0 && x < width && y >= 0 && y < height, "index out of bounds")
            modules[y * width + x] = newValue
        }
    }
}

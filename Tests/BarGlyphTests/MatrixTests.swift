import Testing
@testable import BarGlyph

struct MatrixTests {
    @Test func emptyInitIsAllLight() {
        let matrix = Matrix(width: 3, height: 2)
        #expect(matrix.width == 3)
        #expect(matrix.height == 2)
        for y in 0..<2 {
            for x in 0..<3 {
                #expect(matrix[x, y] == false)
            }
        }
    }

    @Test func subscriptReadsAndWrites() {
        var matrix = Matrix(width: 2, height: 2)
        matrix[1, 0] = true
        matrix[0, 1] = true
        #expect(matrix[1, 0])
        #expect(matrix[0, 1])
        #expect(!matrix[0, 0])
        #expect(!matrix[1, 1])
    }

    @Test func rowInitIsSingleRow() {
        let matrix = Matrix(row: [true, false, true])
        #expect(matrix.height == 1)
        #expect(matrix.width == 3)
        #expect(matrix[0, 0] && !matrix[1, 0] && matrix[2, 0])
    }

    @Test func storageIsRowMajor() {
        let matrix = Matrix(width: 2, height: 2, modules: [true, false, false, true])
        #expect(matrix[0, 0] && matrix[1, 1])
        #expect(!matrix[1, 0] && !matrix[0, 1])
    }
}

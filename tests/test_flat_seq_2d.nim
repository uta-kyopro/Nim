include ../src/lib/collections/flat_seq_2d
import std/unittest

suite "FlatSeq2D":
    test "flat 2d sequence indexes rows and columns":
        var a = initFlatSeq2D[int](2, 3)
        for i in 0..<2:
            for j in 0..<3:
                a[i, j] = i * 10 + j
        check toSeq(a.getRow(1)) == @[10, 11, 12]
        check toSeq(a.getCol(2)) == @[2, 12]
        check a.len == 6

    test "flat 2d sequence supports initial values and mutable elements":
        var a = initFlatSeq2D[int](2, 3, 100)
        check toSeq(a.items) == @[100, 100, 100, 100, 100, 100]
        a[0, 1] += 7
        check chmin(a[1, 2], 5)
        proc increment(value: var int) = inc value
        increment(a[0, 0])
        check a[0, 0] == 101
        check a[0, 1] == 107
        check a[1, 2] == 5
        let b = a
        check b[0, 1] == 107
        check initFlatSeq2D[int](0, 3, 9).len == 0
        check initFlatSeq2D[int](2, 0, 9).len == 0

    test "flat 2d sequence converts rectangular sequences and arrays":
        var source = @[@[1, 2, 3], @[4, 5, 6]]
        var a = source.toFlatSeq2D()
        check a.row == 2
        check a.col == 3
        check toSeq(a.items) == @[1, 2, 3, 4, 5, 6]
        source[0][0] = 99
        check a[0, 0] == 1
        a[1, 2] = 77
        check source[1][2] == 6
        let b = [["a", "b"], ["c", "d"]].toFlatSeq2D()
        check b[1, 0] == "c"
        let empty = newSeq[seq[int]]().toFlatSeq2D()
        check empty.row == 0
        check empty.col == 0
        let emptyRows = @[newSeq[int](), newSeq[int]()].toFlatSeq2D()
        check emptyRows.row == 2
        check emptyRows.col == 0
        check emptyRows.len == 0
        let noArrayRows: array[0, array[3, int]] = []
        check noArrayRows.toFlatSeq2D().len == 0
        let noArrayCols: array[2, array[0, int]] = [[], []]
        let emptyArray = noArrayCols.toFlatSeq2D()
        check emptyArray.row == 2
        check emptyArray.col == 0
        when defined(debug):
            expect ValueError:
                discard @[@[1, 2], @[3]].toFlatSeq2D()
            expect ValueError:
                discard @[newSeq[int](), @[1]].toFlatSeq2D()

    when defined(debug):
        test "flat 2d sequence checks both coordinate bounds":
            var a = initFlatSeq2D[int](2, 3)
            let b = initFlatSeq2D[int](2, 3)
            expect AssertionDefect:
                discard a[0, 3]
            expect AssertionDefect:
                discard b[0, 3]
            expect AssertionDefect:
                a[0, 3] = 7
            expect AssertionDefect:
                a[0, 3] += 1
            expect AssertionDefect:
                discard a[2, 0]
            expect AssertionDefect:
                discard toSeq(a.getRow(2))
            expect AssertionDefect:
                discard toSeq(a.getCol(3))
            var empty = initFlatSeq2D[int](0, 0)
            expect AssertionDefect:
                discard empty[0, 0]
            expect AssertionDefect:
                discard toSeq(empty.getRow(0))
            expect AssertionDefect:
                discard toSeq(empty.getCol(0))

    when defined(debug):
        test "flat 2d sequence rejects invalid shapes in debug builds":
            expect AssertionDefect:
                discard initFlatSeq2D[int](@[], 0)
            expect AssertionDefect:
                discard initFlatSeq2D[int](@[1, 2, 3], 2)

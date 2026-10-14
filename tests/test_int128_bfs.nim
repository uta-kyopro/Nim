import ../src/lib/math/int128
import ../src/examples/int128/bitboard_bfs
import std/[unittest, random, sequtils, deques]

proc verify(height, width: int, open: seq[bool], starts: seq[int]) =
    var walkable = initUInt128(0)
    var startBits = initUInt128(0)
    for cell, allowed in open:
        if allowed: walkable = walkable or (initUInt128(1) shl cell)
    for cell in starts:
        startBits = startBits or (initUInt128(1) shl cell)
    let answer = bitboardBfs(height, width, walkable, startBits)
    # 独立した座標・キューによるBFSで全セルの距離を比較する。
    var expected = newSeqWith(height * width, -1)
    var queue = initDeque[int]()
    for cell in starts:
        if expected[cell] < 0:
            expected[cell] = 0
            queue.addLast(cell)
    while queue.len > 0:
        let cell = queue.popFirst()
        let row = cell div width
        let col = cell mod width
        for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            let nr = row + dr
            let nc = col + dc
            if nr >= 0 and nr < height and nc >= 0 and nc < width:
                let next = nr * width + nc
                if open[next] and expected[next] < 0:
                    expected[next] = expected[cell] + 1
                    queue.addLast(next)
    check answer.distances == expected
    check answer.reachable.popCount() == expected.countIt(it >= 0)
    check toSeq(answer.reachable.getSetBits()) == toSeq(0..<expected.len).filterIt(expected[it] >= 0)

suite "128bit bitboard BFS":
    test "full boards, one row, one column and row boundaries":
        for (height, width) in [(1, 1), (1, 128), (128, 1), (8, 16), (16, 8), (7, 13)]:
            let open = newSeqWith(height * width, true)
            verify(height, width, open, @[0])
            verify(height, width, open, @[height * width - 1])
            verify(height, width, open, @[0, height * width - 1])
        verify(2, 16, newSeqWith(32, true), @[15])
        verify(8, 16, newSeqWith(128, true), @[63])

    test "walls, empty frontier and unreachable cells":
        verify(8, 16, newSeq[bool](128), @[])
        verify(8, 16, newSeqWith(128, true), @[])
        var open = newSeqWith(128, true)
        for col in 0..<16: open[4 * 16 + col] = false
        verify(8, 16, open, @[0])

    test "random boards match queue BFS":
        var rng = initRand(20261015)
        for _ in 0..<300:
            let height = rng.rand(1..16)
            let width = rng.rand(1..min(16, 128 div height))
            var open = newSeq[bool](height * width)
            var starts: seq[int]
            for cell in 0..<open.len:
                open[cell] = rng.rand(3) != 0
                if open[cell] and rng.rand(15) == 0: starts.add(cell)
            verify(height, width, open, starts)

    when defined(debug):
        test "invalid board shapes and bits are checked":
            expect AssertionDefect:
                discard bitboardBfs(0, 1, initUInt128(0), initUInt128(0))
            expect AssertionDefect:
                discard bitboardBfs(8, 17, initUInt128(0), initUInt128(0))
            expect AssertionDefect:
                discard bitboardBfs(1, 1, initUInt128(2), initUInt128(0))
            expect AssertionDefect:
                discard bitboardBfs(1, 1, initUInt128(0), initUInt128(1))

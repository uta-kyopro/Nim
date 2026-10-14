import ../src/examples/bitboard_bfs/u64
import std/[unittest, random, sequtils, deques, bitops]

proc verify(height, width: int, open: seq[bool], starts: seq[int]) =
    var walkable, startBits: uint64
    for cell, allowed in open:
        if allowed: walkable = walkable or (1'u64 shl cell)
    for cell in starts:
        startBits = startBits or (1'u64 shl cell)
    let answer = bitboardBfs(height, width, walkable, startBits)
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
    for cell, distance in expected:
        check ((answer.reachable shr cell) and 1) == uint64(ord(distance >= 0))

suite "uint64 bitboard BFS":
    test "full boards, top bit and row boundaries":
        for (height, width) in [(1, 1), (1, 64), (64, 1), (8, 8), (4, 16), (7, 9)]:
            let open = newSeqWith(height * width, true)
            verify(height, width, open, @[0])
            verify(height, width, open, @[height * width - 1])
            verify(height, width, open, @[0, height * width - 1])
        verify(8, 8, newSeqWith(64, true), @[7])
        verify(8, 8, newSeqWith(64, true), @[31])

    test "walls, empty frontier and unreachable cells":
        verify(8, 8, newSeq[bool](64), @[])
        verify(8, 8, newSeqWith(64, true), @[])
        var open = newSeqWith(64, true)
        for col in 0..<8: open[4 * 8 + col] = false
        verify(8, 8, open, @[0])

    test "random boards match queue BFS":
        var rng = initRand(20261015)
        for _ in 0..<300:
            let height = rng.rand(1..16)
            let width = rng.rand(1..min(16, 64 div height))
            var open = newSeq[bool](height * width)
            var starts: seq[int]
            for cell in 0..<open.len:
                open[cell] = rng.rand(3) != 0
                if open[cell] and rng.rand(15) == 0: starts.add(cell)
            verify(height, width, open, starts)

    when defined(debug):
        test "invalid board shapes and bits are checked":
            expect AssertionDefect:
                discard bitboardBfs(0, 1, 0'u64, 0'u64)
            expect AssertionDefect:
                discard bitboardBfs(8, 9, 0'u64, 0'u64)
            expect AssertionDefect:
                discard bitboardBfs(1, 1, 2'u64, 0'u64)
            expect AssertionDefect:
                discard bitboardBfs(1, 1, 0'u64, 1'u64)

## 64セル以下の長方形盤面をuint64で表現する4近傍BFS。
## bit位置は row * width + col。C/C++バックエンドのどちらでも使用可能。
import std/[bitops, sequtils]

type BitboardBfs64Result* = object
    reachable*: uint64
    distances*: seq[int]  # 壁・到達不能は-1

proc bitboardBfs*(height, width: int, walkable, starts: uint64): BitboardBfs64Result =
    ## startsは通行可能セルの集合。複数始点にも対応。
    when defined(debug):
        doAssert height > 0 and width > 0 and width <= 64 and height <= 64 div width,
            "bitboard must contain 1..64 cells"
    let cells = height * width
    # uint64を64だけシフトしないよう、全64セルの場合を別扱いする。
    let boardMask = if cells == 64: high(uint64)
                    else: (1'u64 shl cells) - 1'u64
    when defined(debug):
        doAssert (walkable and not boardMask) == 0, "walkable exceeds board"
        doAssert (starts and not walkable) == 0, "start must be walkable"
    var leftEdge, rightEdge: uint64
    for row in 0..<height:
        leftEdge = leftEdge or (1'u64 shl (row * width))
        rightEdge = rightEdge or (1'u64 shl (row * width + width - 1))

    result.distances = newSeqWith(cells, -1)
    var frontier = starts and walkable and boardMask
    result.reachable = frontier
    var distance = 0
    while frontier != 0:
        var layer = frontier
        while layer != 0:
            let cell = countTrailingZeroBits(layer)
            result.distances[cell] = distance
            layer = layer and (layer - 1'u64)
        # 左右端のマスクが行の回り込みを防ぐ。
        var neighbors = ((frontier and not rightEdge) shl 1) or
                        ((frontier and not leftEdge) shr 1)
        # width=64は1行の盤面なので、縦方向のシフトは不要。
        if height > 1:
            neighbors = neighbors or (frontier shl width) or (frontier shr width)
        frontier = neighbors and walkable and boardMask and not result.reachable
        result.reachable = result.reachable or frontier
        inc distance

when isMainModule:
    let board = @[
        "S...#...",
        ".##.#...",
        "....#...",
        ".####...",
        "......#.",
        "###...#.",
        "......#.",
        "........"
    ]
    let height = board.len
    let width = board[0].len
    var walkable, starts: uint64
    for row, line in board:
        for col, ch in line:
            let bit = 1'u64 shl (row * width + col)
            if ch != '#': walkable = walkable or bit
            if ch == 'S': starts = starts or bit
    let answer = bitboardBfs(height, width, walkable, starts)
    echo "reachable cells = ", answer.reachable.popCount()
    echo "first reachable bit (1-based) = ", answer.reachable.firstSetBit()
    for row in 0..<height:
        for col in 0..<width:
            if col > 0: stdout.write(" ")
            stdout.write(answer.distances[row * width + col])
        stdout.write("\n")

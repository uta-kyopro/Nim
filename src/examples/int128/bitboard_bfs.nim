## 128セル以下の長方形盤面をUInt128で表現する4近傍BFS。
## bit位置は row * width + col。各反復で距離を1だけ進める。
import ../../lib/math/int128
import std/sequtils

type BitboardBfsResult* = object
    reachable*: UInt128
    distances*: seq[int]  # 壁・到達不能は-1

proc bitboardBfs*(height, width: int, walkable, starts: UInt128): BitboardBfsResult =
    ## startsは通行可能セルの集合。複数始点にも対応。
    when defined(debug):
        doAssert height > 0 and width > 0 and width <= 128 and height <= 128 div width,
            "bitboard must contain 1..128 cells"
    let cells = height * width
    # 128bitを128だけシフトしないよう、盤面全体の場合を別扱いする。
    let boardMask = if cells == 128: high(UInt128)
                    else: (initUInt128(1) shl cells) - initUInt128(1)
    when defined(debug):
        doAssert (walkable and not boardMask) == initUInt128(0), "walkable exceeds board"
        doAssert (starts and not walkable) == initUInt128(0), "start must be walkable"
    var leftEdge = initUInt128(0)
    var rightEdge = initUInt128(0)
    for row in 0..<height:
        leftEdge = leftEdge or (initUInt128(1) shl (row * width))
        rightEdge = rightEdge or (initUInt128(1) shl (row * width + width - 1))

    result.distances = newSeqWith(cells, -1)
    var frontier = starts and walkable and boardMask
    result.reachable = frontier
    var distance = 0
    while not (frontier == initUInt128(0)):
        for cell in frontier.getSetBits():
            result.distances[cell] = distance
        # 左右端のマスクが行の回り込みを防ぐ。
        var neighbors = ((frontier and not rightEdge) shl 1) or
                        ((frontier and not leftEdge) shr 1)
        # width=128は1行の盤面。縦方向のシフトは不要。
        if height > 1:
            neighbors = neighbors or (frontier shl width) or (frontier shr width)
        frontier = neighbors and walkable and boardMask and not result.reachable
        result.reachable = result.reachable or frontier
        inc distance

when isMainModule:
    let board = @[
        "S...#...........",
        ".##.#.####......",
        "....#....#......",
        ".####.##.#......",
        "......#..#......",
        "###...#..####...",
        "......#.........",
        "................"
    ]
    let height = board.len
    let width = board[0].len
    var walkable = initUInt128(0)
    var starts = initUInt128(0)
    for row, line in board:
        for col, ch in line:
            let bit = initUInt128(1) shl (row * width + col)
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

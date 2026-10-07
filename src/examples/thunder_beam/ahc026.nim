# AHC026 A - Stack of Boxes
# https://atcoder.jp/contests/ahc026/tasks/ahc026_a
import std/[strutils, algorithm, deques]
import ../../lib/search/thunder_beam_core

const
    MaxN = 200
    MaxM = 10
    Ahc026BeamWidth {.intdefine.} = 128
    Ahc026MinBeamWidth {.intdefine.} = 4
    Ahc026TimeLimitMs {.intdefine.} = 1400

type
    Action = object
        column: int
        seed: uint64
    OperationKind = enum
        relocate, removeBox
    Operation = object
        kind: OperationKind
        box, source, destination, count: int # destination=-1は搬出
    Frame = object
        begin, target, cost: int
        key: uint64
    State = object
        boxes: array[MaxM, array[MaxN, int]] # 各山の下から順
        size: array[MaxM, int]
        minimum: array[MaxM, array[MaxN, int]]
        location, position: array[MaxN + 1, int]
        target, cost: int
        key: uint64
        operations: seq[Operation]
        frames: seq[Frame]
    Frontier = BeamFrontier[Action, int, uint64]

var n, m: int
# 箱とその直下の箱の組をハッシュ化。山の底は山ごとに別の番号にする。
var edgeHash: array[MaxN + 1, array[MaxN + MaxM + 1, uint64]]

proc prepareHash() =
    var rng = 0x123456789abcdef0'u64
    for row in edgeHash.mitems:
        for value in row.mitems:
            rng = rng xor (rng shl 13)
            rng = rng xor (rng shr 7)
            rng = rng xor (rng shl 17)
            value = rng

proc top(s: State, stack: int): int {.inline.} =
    if s.size[stack] == 0: n + 1 + stack
    else: s.boxes[stack][s.size[stack] - 1]

proc append(s: var State, stack, box: int) =
    s.key = s.key xor edgeHash[box][s.top(stack)]
    s.location[box] = stack
    s.position[box] = s.size[stack]
    s.boxes[stack][s.size[stack]] = box
    s.minimum[stack][s.size[stack]] = if s.size[stack] == 0: box
        else: min(box, s.minimum[stack][s.size[stack] - 1])
    inc s.size[stack]

proc transfer(s: var State, source, destination, count: int) =
    doAssert source != destination and count > 0 and count <= s.size[source]
    let cut = s.size[source] - count
    let first = s.boxes[source][cut]
    let below = if cut == 0: n + 1 + source else: s.boxes[source][cut - 1]
    # 移動する塊の内部は変わらないので、境界のハッシュだけを更新する。
    s.key = s.key xor edgeHash[first][below] xor edgeHash[first][s.top(destination)]
    for i in cut..<s.size[source]:
        let box = s.boxes[source][i]
        s.boxes[destination][s.size[destination]] = box
        s.minimum[destination][s.size[destination]] = if s.size[destination] == 0: box
            else: min(box, s.minimum[destination][s.size[destination] - 1])
        s.location[box] = destination
        s.position[box] = s.size[destination]
        inc s.size[destination]
    s.size[source] = cut


proc drain(s: var State) =
    while s.target <= n:
        let source = s.location[s.target]
        if s.top(source) != s.target: break
        s.operations.add(Operation(kind: removeBox, box: s.target,
            source: source, destination: -1))
        dec s.size[source]
        s.key = s.key xor edgeHash[s.target][s.top(source)]
        inc s.target

proc moveBlock(s: var State, source, destination, count: int) =
    let box = s.boxes[source][s.size[source] - count]
    s.operations.add(Operation(kind: relocate, box: box, source: source,
        destination: destination, count: count))
    s.transfer(source, destination, count)
    s.cost += count + 1
    s.drain()

# 乱数状態をActionに保存し、再適用を決定的にする。
proc next(rng: var uint64): uint64 =
    rng = rng xor (rng shl 13)
    rng = rng xor (rng shr 7)
    rng = rng xor (rng shl 17)
    rng

proc random01(rng: var uint64): float =
    float(rng.next() shr 11) / 9007199254740992.0

proc sortedTower(s: State, column: int, maximum = 0, minimum = MaxN + 1): bool =
    if s.size[column] == 0: return true
    if s.boxes[column][0] < maximum or s.top(column) > minimum: return false
    for i in 1..<s.size[column]:
        if s.boxes[column][i - 1] < s.boxes[column][i]: return false
    true

proc fallbackDestination(s: State, source: int, smallestTop = false): int =
    result = -1
    var best = int.low
    for column in 0..<m:
        if column == source: continue
        let score = if s.size[column] == 0: n + 1
            elif smallestTop: -s.top(column)
            else: s.minimum[column][s.size[column] - 1]
        if score > best:
            best = score
            result = column

proc preSort(s: var State, selected: int, rng: var uint64) =
    var order: array[MaxM, int]
    for i in 0..<m: order[i] = i
    for i in countdown(m - 1, 1):
        swap(order[i], order[int(rng.next() mod uint64(i + 1))])
    var queue = initDeque[int]()
    for i in 0..<m: queue.addLast(order[i])
    var moves = 0
    while queue.len > 0 and moves < n:
        let source = queue.popFirst()
        if s.size[source] <= 1 or s.sortedTower(source): continue
        let box = s.top(source)
        for dest in 0..<m:
            if dest == selected or dest == source or s.size[dest] == 0: continue
            if s.top(dest) > box and rng.random01() > float(s.top(dest) - box - 1) * 0.1:
                s.moveBlock(source, dest, 1)
                inc moves
                queue.addLast(source)
                break

proc sweep(s: var State, column: int, rng: var uint64) =
    var values: seq[int]
    for i in 0..<s.size[column]: values.add(s.boxes[column][i])
    values.sort()
    values.add(n + 1)
    var successor: array[MaxN + 1, int]
    for i in 0..<values.len - 1: successor[values[i]] = values[i + 1]
    var used: array[MaxM, bool]
    var maximum = 0
    var minimum = n + 1
    while s.size[column] > 0:
        if s.size[column] == 1:
            if s.top(column) > maximum: break
            var empty = false
            for i in 0..<m:
                if s.size[i] == 0: empty = true
            if empty: break
        var value = s.top(column)
        maximum = max(maximum, value)
        minimum = min(minimum, value)
        var count = 1
        var descending = true
        while count < s.size[column]:
            let box = s.boxes[column][s.size[column] - count - 1]
            if box == s.target: break
            if descending and box < value:
                discard
            elif rng.random01() > float(box - value) * 0.1:
                descending = false
            else: break
            inc count
            value = box
            maximum = max(maximum, value)
            minimum = min(minimum, value)
        var best = n + 1
        var dest = -1
        while true:
            for i in 0..<m:
                if i == column: continue
                if s.size[i] == 0:
                    if best > n:
                        best = n
                        dest = i
                elif s.top(i) > value:
                    let top = s.top(i)
                    if rng.random01() > float(top - value - 1) * 0.4:
                        best = -1
                        dest = i
                        break
                    elif count == 1 and s.sortedTower(i):
                        if best > -top:
                            best = -n - top
                            dest = i
                    elif successor[value] > top and not used[i]:
                        if best > top - value * 2:
                            best = top - value * 2
                            dest = i
                elif best > value - s.top(i):
                    best = value - s.top(i)
                    dest = i
            if best <= n: break
            if count >= s.size[column] or rng.random01() >= 0.6: break
            inc count
            value = s.boxes[column][s.size[column] - count]
            maximum = max(maximum, value)
            minimum = min(minimum, value)
            while count < s.size[column] and s.boxes[column][s.size[column] - count - 1] < value:
                inc count
                value = s.boxes[column][s.size[column] - count]
                maximum = max(maximum, value)
                minimum = min(minimum, value)
        if dest < 0: dest = s.fallbackDestination(column, rng.random01() > 0.6)
        s.moveBlock(column, dest, count)
        used[dest] = true
        if s.sortedTower(column, maximum, minimum): break

proc gather(s: var State, column: int) =
    while true:
        let limit = if s.size[column] == 0: n + 1 else: s.top(column)
        var source = -1
        var best = 0
        for i in 0..<m:
            if i == column or s.size[i] <= 1 or s.sortedTower(i): continue
            if s.top(i) < limit and s.top(i) > best:
                source = i
                best = s.top(i)
        if source < 0 or best - s.target <= 2: break
        var count = 1
        var previous = best
        while count < s.size[source]:
            let box = s.boxes[source][s.size[source] - count - 1]
            if box <= previous or box >= limit: break
            previous = box
            inc count
        s.moveBlock(source, column, count)

proc evaluate(s: State): int =
    result = s.cost
    for column in 0..<m:
        var height = min(1, s.size[column])
        while height < s.size[column] and s.boxes[column][height - 1] > s.boxes[column][height]:
            inc height
        result += 4 * (s.size[column] - height)

proc getHash(s: State): uint64 = s.key
proc isFinished(s: State): bool = false

proc moveForward(s: var State, action: Action) =
    s.frames.add(Frame(begin: s.operations.len, target: s.target, cost: s.cost, key: s.key))
    if action.column < 0: return
    var rng = action.seed
    s.preSort(action.column, rng)
    if s.target <= n and s.size[action.column] > 0 and not s.sortedTower(action.column):
        s.sweep(action.column, rng)
        s.gather(action.column)

proc moveBackward(s: var State, action: Action) =
    let frame = s.frames.pop()
    while s.operations.len > frame.begin:
        let op = s.operations.pop()
        if op.kind == removeBox:
            dec s.target
            doAssert s.target == op.box
            s.append(op.source, op.box)
        else:
            s.transfer(op.destination, op.source, op.count)
            s.cost -= op.count + 1
    doAssert s.target == frame.target and s.cost == frame.cost and s.key == frame.key

# 完了候補は深さにかかわらず実コスト最小を保存する。
var bestCost: int
var bestOperations: seq[Operation]

proc remember(s: State) =
    if s.target > n and s.cost < bestCost and s.operations.len <= 5000:
        bestCost = s.cost
        bestOperations = s.operations

proc expand(s: var State, parent: int, frontier: var Frontier) =
    if s.target > n:
        s.remember()
        frontier.push(Action(column: -1), s.cost, s.key, parent)
        return
    for column in 0..<m:
        if s.size[column] == 0 or s.sortedTower(column): continue
        for variant in 1..4:
            let action = Action(column: column, seed: (s.key xor
                uint64(column * 4 + variant) * 0x9e3779b97f4a7c15'u64) or 1'u64)
            let before = s.key
            s.moveForward(action)
            s.remember()
            # 完走用に最大2N操作分を予約する。
            if s.key != before and s.operations.len <= 5000 - 2 * n:
                frontier.push(action, s.evaluate(), s.getHash(), parent)
            s.moveBackward(action)

defineThunderBeam(beamSearch, State, Action, int, uint64)

proc finish(s: var State) =
    s.drain()
    while s.target <= n:
        let source = s.location[s.target]
        let count = s.size[source] - s.position[s.target] - 1
        doAssert count > 0
        s.moveBlock(source, s.fallbackDestination(source), count)

proc solve(initial: State, beamWidth = Ahc026BeamWidth,
    minBeamWidth = Ahc026MinBeamWidth,
    timeLimitSec = Ahc026TimeLimitMs.float / 1000): seq[Operation] =
    var start = initial
    start.drain()
    bestCost = int.high
    bestOperations.setLen(0)
    var fallback = start
    fallback.finish()
    fallback.remember()
    let answer = beamSearch(start, beamWidth, maxTurns = n,
        timeLimitSec = timeLimitSec, minBeamWidth = minBeamWidth,
        widthUpdateInterval = 1, stopOnTimeLimit = false)
    var replay = start
    for action in answer.actions: replay.moveForward(action)
    replay.finish()
    replay.remember()
    result = bestOperations
    doAssert result.len <= 5000
    stderr.writeLine("score: ", max(1, 10000 - bestCost))

when isMainModule and not declared(Ahc026Testing):
    let tokens = stdin.readAll().splitWhitespace()
    var cursor = 0
    proc nextInt(): int =
        result = parseInt(tokens[cursor])
        inc cursor
    n = nextInt()
    m = nextInt()
    doAssert n in 1..MaxN and m in 3..MaxM and n mod m == 0
    prepareHash()
    var initial = State(target: 1)
    for stack in 0..<m:
        for _ in 0..<n div m: initial.append(stack, nextInt())
    doAssert cursor == tokens.len
    for op in solve(initial): echo op.box, " ", op.destination + 1

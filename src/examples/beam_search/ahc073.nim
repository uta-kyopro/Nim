# AHC073 A - Circles of Inversion
# https://atcoder.jp/contests/ahc073/tasks/ahc073_a
# 既存ソルバの逆順区間遷移を、Stateコピー型の通常ビームで使う例。
include ../../lib/header
import ../../lib/search/beam_search_core

const
    MaxGoals = 150
    Ahc073BeamWidth {.intdefine.} = 64
    CostWeight = 200
    PredictionHorizon = 12
    PredictionWeights = block:
        var weights: array[PredictionHorizon, int]
        var weight = CostWeight.float * 0.8
        for i in 0..<PredictionHorizon:
            weights[i] = int(weight)
            weight *= 0.9
        weights
    UnknownCell = 16384'u16

type
    Point = distinct uint16 # y:7, x:7。16384は未確定。
    Circles = array[3, Point]
    Order = object
        ids: array[3, int]
        count: int
    State = object
        circles: Circles
        turn, cost: int
    Shape = object
        fixed: bool
        pos: Point
        cost: int16
        parityCost: array[4, int16]
    Jump = object
        source, dest: Point
        circle: uint8
    Route = object
        after: Circles
        jumps: array[3, Jump]
        cost: uint16
        count: uint8
    Frontier = BeamSearchFrontier[State, int, uint64, uint8]

var
    n, m, k, limit: int
    targets: seq[Point] # 出発点、目的地0、…、最後の目的地。
    orders: seq[Order]
    savings: seq[uint16]
    savingsDepth = -1
    predictionCount: int

proc `==`(a, b: Point): bool {.borrow.}
proc point(y, x: int): Point =
    if y < 0: Point(UnknownCell) else: Point(uint16((y shl 7) or x))
proc y(p: Point): int =
    if uint16(p) == UnknownCell: -1 else: int(uint16(p) shr 7)
proc x(p: Point): int =
    if uint16(p) == UnknownCell: -1 else: int(uint16(p) and 127)
proc `[]`(o: Order, i: int): int = o.ids[i]

proc distance(a, b: Point): int = abs(a.y-b.y) + abs(a.x-b.x)
proc parity(p: Point): int = (p.y and 1)*2 + (p.x and 1)
proc parityDistance(a, b: int): int =
    ord((a and 1) != (b and 1)) + ord((a shr 1) != (b shr 1))

proc nearestAxis(x, bit, anchor: int): int =
    if (x and 1) == bit: return x
    if x+1 < n and (anchor > x or x == 0): return x+1
    x-1
proc nearest(p: Point, bits: int, anchor: Point): Point =
    point(nearestAxis(p.y, bits shr 1, anchor.y),
                nearestAxis(p.x, bits and 1, anchor.x))
proc parityMinimum(s: Shape, bits: int): int =
    if s.fixed: return int(s.cost) + parityDistance(parity(s.pos), bits)
    result = int.high div 4
    for r in 0..<4:
        result = min(result, int(s.parityCost[r]) + parityDistance(r, bits))
proc valueAt(s: Shape, p: Point): int =
    if s.fixed: int(s.cost) + distance(s.pos, p)
    else: s.parityMinimum(parity(p))
proc bestLanding(s: Shape, dest: Point): Point =
    if s.fixed: return s.pos
    var best = int.high
    for r in 0..<4:
        let cost = int(s.parityCost[r]) + parityDistance(r, parity(dest))
        if cost < best:
            best = cost
            result = nearest(dest, r, dest)
proc beforeJump(s: Shape, bits: int, anchor: Point): Point =
    if s.fixed: return nearest(s.pos, bits, anchor)
    # Preserve the original representative of equal-cost placements.
    var best = int.high
    var bestWalk = int.high
    for r in 0..<4:
        let cost = int(s.parityCost[r]) + parityDistance(r, bits)
        let p = nearest(anchor, bits, anchor)
        let q = nearest(p, r, anchor)
        let walk = distance(p, anchor) + distance(p, q)
        if cost < best or (cost == best and walk < bestWalk):
            best = cost
            bestWalk = walk
            result = p

proc chooseSourceAxis(previous, landing, goal, future, farther: int): int =
    if (previous and 1) == (landing and 1): return previous
    if previous == 0: return 1
    if previous == n-1: return previous-1
    let low = (previous-1+landing) div 2
    let high = low+1
    let lowScore = abs(low-future)+ord((low and 1)!=(goal and 1))
    let highScore = abs(high-future)+ord((high and 1)!=(goal and 1))
    if lowScore < highScore: return previous-1
    if highScore < lowScore: return previous+1
    let lowFuture = abs(low-farther)+ord((low and 1)!=(future and 1))
    let highFuture = abs(high-farther)+ord((high and 1)!=(future and 1))
    if lowFuture < highFuture: return previous-1
    if highFuture < lowFuture: return previous+1
    nearestAxis(previous, landing and 1, 2*future-landing)

proc makeUniqueRoute(s: State, order: Order): Route =
    result.after = s.circles
    result.count = uint8(order.count)
    let start = targets[m-s.turn]
    let goal = targets[m-s.turn-1]
    let future = targets[max(0, m-s.turn-2)]
    let farther = targets[max(0, m-s.turn-3)]
    var allKnown = true
    for i in 0..<order.count:
        if s.circles[order[i]].y < 0: allKnown = false
    if allKnown:
        var previous = start
        var cost = 0
        for i in 0..<order.count:
            let j = order[i]
            let landing = s.circles[j]
            let source = point(chooseSourceAxis(previous.y, landing.y, goal.y, future.y, farther.y),
                chooseSourceAxis(previous.x, landing.x, goal.x, future.x, farther.x))
            cost += distance(previous, source)+1
            result.jumps[i] = Jump(source: source, dest: landing, circle: uint8(j))
            result.after[j] = point((source.y+landing.y) div 2,
                (source.x+landing.x) div 2)
            previous = landing
        result.cost = uint16(cost+distance(previous, goal))
        return
    var shapes: array[4, Shape]
    shapes[0] = Shape(fixed: true, pos: start)
    for i in 0..<order.count:
        let circle = s.circles[order[i]]
        if circle.y >= 0:
            shapes[i+1] = Shape(fixed: true, pos: circle,
                cost: int16(shapes[i].parityMinimum(parity(circle)) + 1))
        else:
            for r in 0..<4:
                shapes[i+1].parityCost[r] = int16(shapes[i].parityMinimum(r) + 1)
    result.cost = uint16(shapes[order.count].valueAt(goal))
    var dest = goal
    for i in countdown(order.count-1, 0):
        let landing = shapes[i+1].bestLanding(dest)
        let anchor = point(max(0, min(n-1, 2*future.y-landing.y)),
            max(0, min(n-1, 2*future.x-landing.x)))
        let source = shapes[i].beforeJump(parity(landing), anchor)
        let j = order[i]
        result.jumps[i] = Jump(source: source, dest: landing, circle: uint8(j))
        result.after[j] = point((source.y+landing.y) div 2,
            (source.x+landing.x) div 2)
        dest = source

proc hasReuse(order: Order): bool =
    var mask = 0
    for i in 0..<order.count:
        let bit = 1 shl order[i]
        if (mask and bit) != 0: return true
        mask = mask or bit

proc makeRoute(s: State, order: Order): Route =
    if not order.hasReuse: return makeUniqueRoute(s, order)
    # A reused circle lands at its updated position, not its original one.
    # For repeated orders, choose each nearest parity-compatible departure.
    result.after = s.circles
    result.count = uint8(order.count)
    var previous = targets[m-s.turn]
    let goal = targets[m-s.turn-1]
    let future = targets[max(0, m-s.turn-2)]
    let farther = targets[max(0, m-s.turn-3)]
    var paid = 0
    for i in 0..<order.count:
        let j = order[i]
        var landing = result.after[j]
        var source = previous
        if landing.y < 0:
            landing = nearest(goal, parity(previous), goal)
        else:
            source = point(chooseSourceAxis(previous.y, landing.y, goal.y, future.y, farther.y),
                chooseSourceAxis(previous.x, landing.x, goal.x, future.x, farther.x))
        paid += distance(previous, source)+1
        result.jumps[i] = Jump(source: source, dest: landing, circle: uint8(j))
        result.after[j] = point((source.y+landing.y) div 2, (source.x+landing.x) div 2)
        previous = landing
    result.cost = uint16(paid+distance(previous, goal))

proc buildSavings(depth: int, table: var seq[uint16]): int =
    result = min(PredictionHorizon, m-depth)
    for i in 0..<result:
        let start = targets[m-depth-i]
        let goal = targets[m-depth-i-1]
        let direct = distance(start, goal)
        for y in 0..<n:
            for x in 0..<n:
                let p = point(y, x)
                let jump = 1 + parityDistance(parity(start), parity(p)) + distance(p, goal)
                table[int(uint16(p))*PredictionHorizon+i] = uint16(max(0, direct-jump)*PredictionWeights[i])
        table[int(UnknownCell)*PredictionHorizon+i] = uint16(max(0, direct-1-parityDistance(parity(start), parity(goal)))*PredictionWeights[i])

proc estimatedSaving(circles: Circles, table: seq[uint16], count: int): int =
    var unused = 0
    var positions: array[3, int]
    for j in 0..<3:
        positions[j] = int(uint16(circles[j]))
        if positions[j] == int(UnknownCell): inc unused
    var bonus: array[3, int]
    for i in 0..<count:
        var best = 0
        for j in 0..<3:
            if positions[j] != int(UnknownCell):
                best = max(best, int(table[positions[j]*PredictionHorizon+i]))
        result += best
        if unused > 0:
            var extra = int(table[int(UnknownCell)*PredictionHorizon+i])-best
            for j in 0..<3:
                if extra > bonus[j]: swap(extra, bonus[j])
    for j in 0..<unused: result += bonus[j]

proc evaluate(s: State): int =
    if savingsDepth != s.turn:
        predictionCount = buildSavings(s.turn, savings)
        savingsDepth = s.turn
    CostWeight*s.cost - estimatedSaving(s.circles, savings, predictionCount)

proc isFinished(s: State): bool = false # 最終層も全候補の評価を比較する。

proc getHash(s: State): uint64 =
    # 同じ層の位置は共通。未確定を含む魔法陣の多重集合を45bitに詰める。
    var cells: array[3, uint16]
    for i in 0..2: cells[i] = uint16(s.circles[i])
    if cells[0] > cells[1]: swap(cells[0], cells[1])
    if cells[1] > cells[2]: swap(cells[1], cells[2])
    if cells[0] > cells[1]: swap(cells[0], cells[1])
    for cell in cells: result = (result shl 15) or uint64(cell)

proc expand(s: var State, frontier: var Frontier) =
    for id, order in orders:
        let route = makeRoute(s, order)
        var next = s
        next.circles = route.after
        next.cost += int(route.cost)
        inc next.turn
        next.pushCandidate(frontier, uint8(id))

defineBeamSearch(beamSearch, State, int, uint64, uint8)

type Command = tuple[c: char, p: Point]
proc reverseWalk(commands: var seq[Command], a, b: Point) =
    for _ in 0..<abs(b.y-a.y):
        commands.add(((if b.y > a.y: 'U' else: 'D'), point(0,0)))
    for _ in 0..<abs(b.x-a.x):
        commands.add(((if b.x > a.x: 'L' else: 'R'), point(0,0)))

proc solve*() =
    proc readInt(): int = input(int)
    n = readInt()
    m = readInt()
    k = readInt()
    limit = readInt()
    doAssert n in 2..128 and m in 1..MaxGoals and k == 3
    targets = newSeq[Point](m+1)
    for p in targets.mitems: p = point(readInt(),readInt())
    orders.setLen(0)
    proc enumerate(order: Order) =
        orders.add(order)
        if order.count == 3: return
        for j in 0..2:
            var next = order
            next.ids[next.count] = j
            inc next.count
            enumerate(next)
    enumerate(Order())
    doAssert orders.len == 40
    savings = newSeq[uint16]((int(UnknownCell)+1)*PredictionHorizon)
    savingsDepth = -1
    var initial: State
    for circle in initial.circles.mitems: circle = point(-1,-1)
    let answer = beamSearch(initial, Ahc073BeamWidth, maxTurns = m)
    doAssert answer.turns == m
    var state = initial
    var commands: seq[Command]
    for depth in 0..<m:
        let id = int(answer.actions[depth])
        let route = makeRoute(state, orders[id])
        var position = targets[m-depth]
        for i in 0..<int(route.count):
            let jump = route.jumps[i]
            commands.reverseWalk(position, jump.source)
            # 逆転移では元の出発点に着き、元の魔法陣を復元する。
            let center = point((jump.source.y+jump.dest.y) div 2,
                (jump.source.x+jump.dest.x) div 2)
            commands.add(('J',center))
            position = jump.dest
        commands.reverseWalk(position, targets[m-depth-1])
        state.circles = route.after
        state.cost += int(route.cost)
        inc state.turn
    doAssert state.cost == answer.state.cost and state.circles == answer.state.circles
    doAssert commands.len == state.cost
    commands.reverse()
    # 幅制限下でも操作上限を保証する。
    if commands.len > limit:
        commands.setLen(0)
        for turn in countdown(m,1): commands.reverseWalk(targets[turn],targets[turn-1])
        commands.reverse()
    doAssert commands.len <= limit
    var output: string
    for p in state.circles:
        let q = if p.y < 0: point(0,0) else: p
        output.add($q.y & " " & $q.x & "\n")
    for command in commands:
        output.add(command.c)
        if command.c == 'J': output.add(" " & $command.p.y & " " & $command.p.x)
        output.add('\n')
    stdout.write(output)
    stderr.writeLine("operations = ", commands.len, ", selected = ", answer.selectedCandidates)

when isMainModule and not defined(beamTests): solve()

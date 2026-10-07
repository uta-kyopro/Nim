import std/[unittest, algorithm, tables, os, random]
include ../src/lib/search/thunder_beam_core

type
    Action = object
        delta, step: int
    State = object
        value, goal, mode: int
        history: seq[int]

proc evaluate(s: State): int = s.value
proc isFinished(s: State): bool = s.goal >= 0 and s.value >= s.goal
proc moveForward(s: var State, a: Action) =
    s.history.add(s.value)
    s.value += a.delta
proc moveBackward(s: var State, a: Action) = s.value = s.history.pop()
proc expand(s: var State, parent: int, f: var BeamFrontier[Action, int, int]) =
    if s.mode == 1: return
    if s.mode == 2: sleep(5)
    for delta in [0, 1, 3, 1]:
        let step = if s.mode == 3: 2 else: (if delta == 3: 2 else: 1)
        let a = Action(delta: delta, step: step)
        s.moveForward(a)
        let score = s.evaluate()
        let done = s.isFinished()
        s.moveBackward(a)
        f.push(a, score, score, parent, done, step)
defineThunderBeam(search, State, Action, int, int)

# 別のState/Action/Score/Keyでも同時に使えることと、大量の候補置換を検証。
type FanState = object
    value: int
proc evaluate(s: FanState): float = float(s.value)
proc isFinished(s: FanState): bool = false
proc moveForward(s: var FanState, a: int) = s.value += a
proc moveBackward(s: var FanState, a: int) = s.value -= a
proc expand(s: var FanState, parent: int, f: var BeamFrontier[int, float, string]) =
    for value in countdown(70000, 1):
        f.push(value, float(s.value+value), $(s.value+value), parent)
defineThunderBeam(fanSearch, FanState, int, float, string)

# 小さなランダムDAGを全列挙し、可変step・重複排除・剪定・復元を比較する。
type
    Edge = object
        dest, step: int
    GraphState = object
        vertex: int
        graph: seq[seq[Edge]]
        history: seq[int]
proc evaluate(s: GraphState): int = s.vertex - 10
proc isFinished(s: GraphState): bool = false
proc moveForward(s: var GraphState, a: Edge) =
    s.history.add(s.vertex)
    s.vertex = a.dest
proc moveBackward(s: var GraphState, a: Edge) = s.vertex = s.history.pop()
proc expand(s: var GraphState, parent: int, f: var BeamFrontier[Edge, int, int]) =
    for edge in s.graph[s.vertex]:
        f.push(edge, edge.dest-10, edge.dest, parent, step = edge.step)
defineThunderBeam(graphSearch, GraphState, Edge, int, int)

proc replay(initial: State, answer: BeamResult[Action, int]) =
    var s = initial
    var turns = 0
    for action in answer.actions:
        s.moveForward(action)
        turns += action.step
    doAssert turns == answer.turns
    doAssert s.evaluate() == answer.score
    if answer.status == beamFinished: doAssert s.isFinished()

suite "thunder beam":
    test "initial goal, zero turns and dead end":
        check search(State(goal: 0), 1).status == beamFinished
        check search(State(goal: 10), 1, maxTurns = 0).status == beamMaxTurns
        let dead = search(State(value: 7, goal: 10, mode: 1), 2)
        check dead.status == beamExhausted
        check dead.score == 7 and dead.actions.len == 0

    test "validation":
        expect ValueError: discard search(State(), 0)
        expect ValueError: discard search(State(), 1, maxTurns = -1)
        expect ValueError: discard search(State(), 1, timeLimitSec = -1)
        expect ValueError: discard search(State(), 2, minBeamWidth = -1)
        expect ValueError: discard search(State(), 2, minBeamWidth = 3, timeLimitSec = 1)
        expect ValueError: discard search(State(), 2, minBeamWidth = 1)
        expect ValueError: discard search(State(), 2, widthUpdateInterval = 0)

    test "adaptive width formula, bounds and last turn":
        check beamAdjustedWidth(3000, 1000, 600000, 1.0, 2.0, 500) == 1200
        check beamAdjustedWidth(3000, 1000, 600000, 0.1, 2.0, 500) == 3000
        check beamAdjustedWidth(3000, 1000, 600000, 1.9, 2.0, 500) == 1000
        check beamAdjustedWidth(1200, 1000, 600000, 0.1, 2.0, 500) == 1200
        check beamAdjustedWidth(3000, 1000, 0, 0, 2, 500) == 3000
        check beamAdjustedWidth(3000, 1000, 600000, 2, 2, 500) == 1000
        check beamAdjustedWidth(3000, 1000, 600000, 1, 2, 0) == 3000

    test "linear hash collisions, rebuilds and stale candidate indices":
        var f = BeamFrontier[int, int, int](width: 3, remaining: 1, minimize: true)
        for i in 0..10000:
            check f.push(i, -i, i * 64, 0)
        let s = f.selectors[0]
        check s.candidates.len == 3
        check s.indices.used < s.indices.keys.len * 7 div 10 + 1
        var scores: seq[int]
        for c in s.candidates: scores.add(c.score)
        scores.sort()
        check scores == @[-10000, -9999, -9998]
        check f.push(10001, -10001, 0, 0)
        check not f.push(10002, -10001, 0, 0)
        check f.push(10003, -10002, 0, 0)
        check s.candidates.len == 3

    test "integer hash keys preserve low bits without narrowing mask":
        var small = initBeamHashMap[int8](64)
        let (_, slot) = small.getIndex(-1'i8)
        small.set(slot, -1'i8, 7)
        check small.getIndex(-1'i8) == (true, slot)
        check small.values[slot] == 7
        small.clear()
        check not small.getIndex(-1'i8).found
        var large = initBeamHashMap[uint64](64)
        let (_, last) = large.getIndex(uint64.high)
        large.set(last, uint64.high, 9)
        check large.getIndex(uint64.high) == (true, last)

    test "time budget can adjust width without interrupting original search":
        let initial = State(goal: -1, mode: 2)
        let answer = search(initial, 1, maxTurns = 3, timeLimitSec = 0.001,
            minBeamWidth = 1, widthUpdateInterval = 1, stopOnTimeLimit = false)
        check answer.status == beamMaxTurns and answer.turns == 3
        initial.replay(answer)

    test "width changes preserve pending selectors as in original":
        for minimize in [true, false]:
            var f = BeamFrontier[int, int, int](width: 8, remaining: 5, minimize: minimize)
            for step in 1..3:
                for key in 0..<8: f.push(key, key, key, 0, step = step)
            f.push(100, 100, 100, 0, finished = true, step = 3)
            f.beamResize(3)
            check f.width == 3
            for s in f.selectors.items:
                check s.width == 8 and s.candidates.len == 8 and s.indices.used == 8
            check f.selectors[2].hasFinished
            let best = if minimize: -10 else: 10
            f.push(20, best, 20, 0, step = 2)
            f.push(21, best, 20, 0, step = 2) # 同点の同じキーは増えない
            f.push(22, best, 22, 0, step = 4) # 新しいselectorも縮小後の幅
            check f.selectors[1].candidates.len == 8
            check f.selectors[1].indices.used == 9 # 追い出したキーは再構築まで残す
            check f.selectors[3].width == 3
            f.beamResize(1)
            check f.selectors[1].width == 8
            check f.selectors[3].candidates[0].score == best
            check f.selectors[2].hasFinished

    test "adaptive search returns replayable paths with skipped turns":
        for minimize in [true, false]:
            let initial = State(goal: -1, mode: 3)
            let answer = search(initial, 20, maxTurns = 10000, minimize = minimize,
                timeLimitSec = 0.02, minBeamWidth = 1, widthUpdateInterval = 2)
            initial.replay(answer)
            check answer.status in {beamMaxTurns, beamTimeLimit}
            check initial.value == 0 and initial.history.len == 0

    test "both score directions, skipped layers, repeated calls, input preserved":
        for width in [1, 2, 7, 4001]:
            for mode in [0, 3]:
                for minimize in [false, true]:
                    let initial = State(goal: 8, mode: mode, history: @[99])
                    let a = search(initial, width, maxTurns = 10, minimize = minimize)
                    initial.replay(a)
                    check initial.value == 0 and initial.history == @[99]
                    let b = search(initial, width, maxTurns = 10, minimize = minimize)
                    check a == b

    test "fixed horizon score agrees with exhaustive state sets":
        for turns in 1..12:
            var reachable = newSeq[seq[int]](turns+1)
            reachable[0] = @[0]
            for t in 0..<turns:
                for value in reachable[t]:
                    reachable[t+1].add(value)
                    reachable[t+1].add(value+1)
                    if t+2 <= turns: reachable[t+2].add(value+3)
            for minimize in [false, true]:
                let initial = State(goal: -1)
                let answer = search(initial, 100, maxTurns = turns, minimize = minimize)
                check answer.status == beamMaxTurns
                check answer.turns == turns
                check answer.score == (if minimize: min(reachable[turns]) else: max(reachable[turns]))
                initial.replay(answer)

    test "first goal at earliest arrival turn matches original":
        let initial = State(goal: 2)
        let low = search(initial, 100, maxTurns = 10)
        let high = search(initial, 100, maxTurns = 10, minimize = false)
        check low.status == beamFinished and low.turns == 2 and low.score == 3
        check high.status == beamFinished and high.turns == 2 and high.score == 3
        initial.replay(low)
        initial.replay(high)

    test "step cannot overshoot horizon":
        let initial = State(goal: 10, mode: 3)
        let answer = search(initial, 3, maxTurns = 1)
        check answer.status == beamExhausted
        check answer.actions.len == 0

    test "timeout returns a replayable partial result":
        let initial = State(goal: -1, mode: 2)
        let answer = search(initial, 10, timeLimitSec = 0.001)
        check answer.status == beamTimeLimit
        initial.replay(answer)

    test "dynamic width and more replacements than the old hash capacity":
        for width in [1, 17, 4097]:
            let answer = fanSearch(FanState(), width, maxTurns = 1)
            check answer.score == 1.0
            check answer.actions == @[1]

    test "long single branch and negative scores":
        let initial = State(value: -2000, goal: -1)
        let answer = search(initial, 1, maxTurns = 1000)
        check answer.score == -2000
        check answer.turns == 1000
        initial.replay(answer)

    test "random DAGs match exhaustive search including early exhaustion":
        var rng = initRand(20260924)
        for trial in 0..<100:
            var initial = GraphState(graph: newSeq[seq[Edge]](20))
            for src in 0..<19:
                for _ in 0..<rng.rand(4):
                    initial.graph[src].add(Edge(dest: rng.rand(src+1..19), step: rng.rand(1..4)))
            const horizon = 12
            var reachable: array[horizon+1, seq[int]]
            reachable[0] = @[0]
            var deepest = 0
            for turn in 0..horizon:
                if reachable[turn].len > 0: deepest = turn
                for vertex in reachable[turn]:
                    for edge in initial.graph[vertex]:
                        if turn+edge.step <= horizon and edge.dest notin reachable[turn+edge.step]:
                            reachable[turn+edge.step].add(edge.dest)
            for minimize in [true, false]:
                let answer = graphSearch(initial, 50, maxTurns = horizon, minimize = minimize)
                let best = if minimize: min(reachable[deepest]) else: max(reachable[deepest])
                check answer.score == best-10
                check answer.turns == deepest
                var current = 0
                var turns = 0
                for edge in answer.actions:
                    check edge in initial.graph[current]
                    current = edge.dest
                    turns += edge.step
                check current == best and turns == deepest
                check initial.vertex == 0 and initial.history.len == 0

    test "future candidates keep parents alive after short branches die":
        let initial = GraphState(graph: @[
            @[Edge(dest: 1, step: 1), Edge(dest: 2, step: 4)],
            newSeq[Edge](), @[Edge(dest: 3, step: 1)], newSeq[Edge]()])
        let answer = graphSearch(initial, 1, maxTurns = 10)
        check answer.status == beamExhausted
        check answer.turns == 5 and answer.score == -7
        check answer.actions == @[Edge(dest: 2, step: 4), Edge(dest: 3, step: 1)]

    test "bounded beam matches a simple state-copying reference":
        var rng = initRand(20260925)
        for trial in 0..<50:
            var initial = GraphState(graph: newSeq[seq[Edge]](30))
            for src in 0..<29:
                for _ in 0..<rng.rand(6):
                    initial.graph[src].add(Edge(dest: rng.rand(src+1..29), step: rng.rand(1..4)))
            for width in [1, 2, 5]:
                for minimize in [true, false]:
                    var pending: array[16, seq[int]]
                    pending[0] = @[0]
                    var best = 0
                    var deepest = 0
                    for turn in 0..15:
                        pending[turn].sort()
                        if not minimize: pending[turn].reverse()
                        if pending[turn].len > width: pending[turn].setLen(width)
                        if pending[turn].len > 0:
                            deepest = turn
                            best = pending[turn][0]
                        for vertex in pending[turn]:
                            for edge in initial.graph[vertex]:
                                let arrival = turn+edge.step
                                if arrival <= 15 and edge.dest notin pending[arrival]:
                                    pending[arrival].add(edge.dest)
                    let answer = graphSearch(initial, width, maxTurns = 15, minimize = minimize)
                    check answer.turns == deepest and answer.score == best-10
                    var vertex = 0
                    var turn = 0
                    for edge in answer.actions:
                        check edge in initial.graph[vertex]
                        vertex = edge.dest
                        turn += edge.step
                    check vertex == best and turn == deepest

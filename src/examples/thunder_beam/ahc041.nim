# AHC041 A - Christmas Tree Cutting
# https://atcoder.jp/contests/ahc041/tasks/ahc041_a
import std/[algorithm, strutils]
import ../../lib/search/thunder_beam_core

const
    MaxN = 1000
    MaxH = 10
    Ahc041BeamWidth {.intdefine.} = 128
    Ahc041MinBeamWidth {.intdefine.} = 16

type
    Action = int # 今回追加する頂点の親。-1なら根。
    State = object
        turn, score: int
        depth: array[MaxN, int]
        key: uint64
    Frontier = BeamFrontier[Action, int, uint64]

# 入力と追加順は探索中に変更しない。Stateには差分更新する情報だけを持つ。
var
    n, height: int
    beauty: array[MaxN, int]
    graph: array[MaxN, seq[int]]
    order: seq[int]
    depthHash: array[MaxN, array[MaxH + 1, uint64]]

proc prepare() =
    # 小さい重みを先に置くDFS順。親はこの順序で先に追加された頂点に限定する。
    proc compare(a, b: int): int =
        result = cmp(beauty[a], beauty[b])
        if result == 0: result = cmp(a, b)
    var vertices: seq[int]
    for v in 0..<n:
        vertices.add(v)
        graph[v].sort(compare)
    vertices.sort(compare)
    var seen: array[MaxN, bool]
    proc visit(v: int) =
        seen[v] = true
        order.add(v)
        for u in graph[v]:
            if not seen[u]: visit(u)
    order.setLen(0)
    for v in vertices:
        if not seen[v]: visit(v)
    var rng = 0x123456789abcdef0'u64
    for v in 0..<n:
        for d in 0..height:
            rng = rng xor (rng shl 13)
            rng = rng xor (rng shr 7)
            rng = rng xor (rng shl 17)
            depthHash[v][d] = rng

proc initState(): State =
    result.score = 1
    for v in 0..<n:
        result.depth[v] = -1
        result.score += beauty[v] # 未処理頂点も根として数え、常に実際の得点にする。

proc evaluate(s: State): int = s.score
proc getHash(s: State): uint64 = s.key
proc isFinished(s: State): bool = false # 全候補を比較する固定ターン型。

proc moveForward(s: var State, action: Action) =
    let v = order[s.turn]
    let d = if action < 0: 0 else: s.depth[action] + 1
    s.depth[v] = d
    s.score += d * beauty[v]
    s.key = s.key xor depthHash[v][d]
    inc s.turn

proc moveBackward(s: var State, action: Action) =
    dec s.turn
    let v = order[s.turn]
    let d = s.depth[v]
    s.key = s.key xor depthHash[v][d]
    s.score -= d * beauty[v]
    s.depth[v] = -1

proc pushCandidate(s: var State, parent: int, frontier: var Frontier, action: Action) =
    s.moveForward(action)
    let score = s.evaluate()
    let key = s.getHash()
    s.moveBackward(action)
    frontier.push(action, score, key, parent)

proc expand(s: var State, parent: int, frontier: var Frontier) =
    if s.turn == n: return
    let v = order[s.turn]
    s.pushCandidate(parent, frontier, -1)
    var usedDepth: array[MaxH + 1, bool]
    for u in graph[v]:
        let d = s.depth[u]
        if d < 0 or d >= height or usedDepth[d + 1]: continue
        # 同じ深さなら親が違っても以降の候補・得点は同じなので1つだけ登録。
        usedDepth[d + 1] = true
        s.pushCandidate(parent, frontier, u)

defineThunderBeam(beamSearch, State, Action, int, uint64)

proc solve(beamWidth = Ahc041BeamWidth, minBeamWidth = Ahc041MinBeamWidth,
    timeLimitSec = 1.7): seq[int] =
    let initial = initState()
    let answer = beamSearch(initial, beamWidth, maxTurns = n, minimize = false,
        timeLimitSec = timeLimitSec, minBeamWidth = minBeamWidth)
    result = newSeq[int](n)
    for p in result.mitems: p = -1
    for turn, action in answer.actions: result[order[turn]] = action
    stderr.writeLine("score: ", answer.score)

when isMainModule:
    let tokens = stdin.readAll().splitWhitespace()
    var cursor = 0
    proc nextInt(): int =
        result = parseInt(tokens[cursor])
        inc cursor
    n = nextInt()
    let m = nextInt()
    height = nextInt()
    doAssert n in 1..MaxN and height in 0..MaxH
    for v in 0..<n: beauty[v] = nextInt()
    for _ in 0..<m:
        let u = nextInt()
        let v = nextInt()
        graph[u].add(v)
        graph[v].add(u)
    for _ in 0..<n: # 座標はこの構築法では使わない。
        discard nextInt()
        discard nextInt()
    doAssert cursor == tokens.len
    prepare()
    let parents = solve()
    for v, p in parents:
        if v > 0: stdout.write(" ")
        stdout.write(p)
    stdout.write("\n")

include ../../lib/header
import ../../lib/search/tour_beam_core
include ../beam_search/ahc073_problem

# AHC073の逆順区間遷移を、rhoo版の経路配列型ビームで使う例。
# 問題固有の経路計算・評価・入力・出力は通常ビームのサンプルと共有する。
type
    Action = object
        transition: uint64 # 魔法陣XOR差分45bit・コスト10bit・経路ID6bit。
        hashDelta: uint64
    SearchState = object
        isFinished: bool
        problem: State
        hash: uint64
    Frontier = TourBeamFrontier[Action, int, uint64]

# 多重集合の同じ位置の1個目・2個目・3個目に別のZobrist値を割り当てる。
var zobrist: array[3, array[16385, uint64]]

# 固定seedでZobrist表を初期化し、整数キーの下位bitにも十分な分散を持たせる。
proc initZobrist() =
    var seed = 73073'u64
    for occurrence in 0..2:
        for value in zobrist[occurrence].mitems:
            seed += 0x9e3779b97f4a7c15'u64
            var bits = seed
            bits = (bits xor (bits shr 30)) * 0xbf58476d1ce4e5b9'u64
            bits = (bits xor (bits shr 27)) * 0x94d049bb133111eb'u64
            value = bits xor (bits shr 31)

# 魔法陣のラベルを無視し、同じ位置の重複数を区別したZobristHashを作る。
proc circlesHash(circles: Circles): uint64 =
    for j in 0..2:
        var occurrence = 0
        for i in 0..<j:
            if circles[i] == circles[j]: inc occurrence
        result = result xor zobrist[occurrence][int(uint16(circles[j]))]

# 共通の評価関数を使う。
template evaluate(s: SearchState): int = s.problem.evaluate()
# 差分更新済みのZobristHashを返す。
template getHash(s: SearchState): uint64 = s.hash
# 最終層の全候補を比較する。

# 遷移前後の魔法陣・コスト・経路IDを、巻き戻し可能な1つのActionにまとめる。
proc makeAction(s: SearchState, route: Route, id: int): Action =
    var bits = (uint64(route.cost) shl 45) or (uint64(id) shl 55)
    for j in 0..2:
        bits = bits or (uint64(uint16(s.problem.circles[j]) xor uint16(route.after[j])) shl (15*j))
    Action(transition: bits, hashDelta: s.hash xor circlesHash(route.after))

# 魔法陣のXOR差分・実コスト・深さを適用する。
proc moveForward(s: var SearchState, action: Action) =
    let bits = action.transition
    for j in 0..2:
        s.problem.circles[j] = Point(uint16(s.problem.circles[j]) xor uint16((bits shr (15*j)) and 32767))
    s.problem.cost += int((bits shr 45) and 1023)
    inc s.problem.turn
    s.hash = s.hash xor action.hashDelta

# 同じXOR差分を再適用し、実コストと深さも完全に戻す。
proc moveBackward(s: var SearchState, action: Action) =
    let bits = action.transition
    for j in 0..2:
        s.problem.circles[j] = Point(uint16(s.problem.circles[j]) xor uint16((bits shr (15*j)) and 32767))
    s.problem.cost -= int((bits shr 45) and 1023)
    dec s.problem.turn
    s.hash = s.hash xor action.hashDelta

# 巡回では生値から復元できない実コスト・深さを更新し、Hash更新を省く。
proc moveBoardForward(s: var SearchState, action: Action) =
    let bits = action.transition
    for j in 0..2:
        s.problem.circles[j] = Point(uint16(s.problem.circles[j]) xor uint16((bits shr (15*j)) and 32767))
    s.problem.cost += int((bits shr 45) and 1023)
    inc s.problem.turn

# 巡回で変更した魔法陣・実コスト・深さを戻す。
proc moveBoardBackward(s: var SearchState, action: Action) =
    let bits = action.transition
    for j in 0..2:
        s.problem.circles[j] = Point(uint16(s.problem.circles[j]) xor uint16((bits shr (15*j)) and 32767))
    s.problem.cost -= int((bits shr 45) and 1023)
    dec s.problem.turn

# 評価値には先読みが含まれるため実コストへ代入せず、Hashだけを復元する。
template loadLeaf(s: var SearchState, leafScore: int, leafKey: uint64) = s.hash = leafKey

# 1区間を1ターンとして列挙し、StateをコピーせずActionだけを候補へ渡す。
proc expand(s: var SearchState, frontier: var Frontier) =
    for id, order in orders:
        let route = makeRoute(s.problem, order)
        s.pushCandidate(frontier, s.makeAction(route, id))

defineTourBeam(tourBeam, SearchState, Action, int, uint64)

# 復元済みのActionを1回だけ再生し、共通の出力処理へ経路IDと最終Stateを渡す。
proc runSearch(initial: State, width, turns: int): Ahc073Answer =
    initZobrist()
    let start = SearchState(problem: initial, hash: circlesHash(initial.circles))
    let answer = tourBeam(start, width, maxTurns = turns)
    var replay = start
    for action in answer.actions:
        replay.moveForward(action)
        result.actions.add(uint8(action.transition shr 55))
    doAssert replay.evaluate() == answer.score and replay.hash == circlesHash(replay.problem.circles)
    result.state = replay.problem
    result.turns = answer.turns
    result.selectedCandidates = answer.selectedCandidates

# 入力を読み、共通の逆順区間再生で提出形式を出力する。
proc solve*() = solveWith(runSearch)

when isMainModule and not defined(beamTests): solve()

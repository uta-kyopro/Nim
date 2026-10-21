include ../../lib/header
import ../../lib/search/tour_beam_core

# 整数評価値は符号付き48bit範囲、通常のビーム幅は65,536以下にする。
type
    Action = int
    LeafData = object
        score, moves: int
    State = object
        position, target, score, moves: int
        isFinished: bool # 固定5ターンの全候補を比較するためfalseのままにする。
    Frontier = TourBeamFrontier[Action, int, uint64, LeafData]

# 目標位置までの残り距離を最小化する。
template evaluate(s: State): int = s.score
# 同じ位置を同一状態として扱う。
template getHash(s: State): uint64 = uint64(s.position)
# TODO: 候補の試算・最終再生用に、盤面・評価値・補助情報・終了状態を全て更新する。
proc moveForward(s: var State, action: Action) =
    s.position += action
    s.score -= action
    inc s.moves
# TODO: 実問題では対応する適用を完全に取り消す。
proc moveBackward(s: var State, action: Action) =
    s.position -= action
    s.score += action
    dec s.moves

# 巡回中は位置だけを更新し、固定ターン探索の完了フラグはfalseのままにする。
template moveBoardForward(s: var State, action: Action) = s.position += action
# 巡回中に変更した位置を戻す。
template moveBoardBackward(s: var State, action: Action) = s.position -= action
# 評価値に加え、Actionの個数も葉ごとに保存する。
template getLeaf(s: State): LeafData = LeafData(score: s.score, moves: s.moves)
# TODO: 巡回中に更新を省いた値を、展開直前に葉の保存値で上書きする。
# 保存は差分計算を省く一方でコピー量を増やすため、実問題では軽い方を測って選ぶ。
template loadLeaf(s: var State, leaf: LeafData) =
    s.score = leaf.score
    s.moves = leaf.moves
# TODO: 合法な1ターン遷移を列挙し、仮適用・評価・巻き戻しをヘルパーに任せる。
proc expand(s: var State, frontier: var Frontier) =
    doAssert s.moves == frontier.currentLeaf.moves
    for action in [1, 2]:
        if s.position+action <= s.target:
            s.pushCandidate(frontier, action)

defineTourBeam(tourBeam, State, Action, int, uint64, LeafData)

when isMainModule:
    let initial = State(target: 10, score: 10)
    let answer = tourBeam(initial, beamWidth = 20, maxTurns = 5)
    echo answer.score
    echo answer.actions
    var replay = initial
    for action in answer.actions: replay.moveForward(action)
    doAssert answer.turns == 5 and answer.actions.len == 5
    doAssert answer.score == 0 and replay.position == 10
    doAssert replay.moves == answer.actions.len
    doAssert initial.position == 0

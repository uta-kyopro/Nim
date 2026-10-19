include ../../lib/header
import ../../lib/search/tour_beam_core

type
    Action = int
    State = object
        position, target, score: int
        isFinished: bool # 固定5ターンの全候補を比較するためfalseのままにする。

# 目標位置までの残り距離を最小化する。
template evaluate(s: State): int = s.score
# 同じ位置を同一状態として扱う。
template getHash(s: State): int = s.position
# TODO: 実問題ではActionを適用し、評価値やHashも差分更新する。
proc moveForward(s: var State, action: Action) =
    s.position += action
    s.score -= action
# TODO: 実問題では対応する適用を完全に取り消す。
proc moveBackward(s: var State, action: Action) =
    s.position -= action
    s.score += action

# 巡回中は位置だけを更新し、固定ターン探索の完了フラグはfalseのままにする。
proc moveBoardForward(s: var State, action: Action) = s.position += action
# 巡回中に変更した位置を戻す。
proc moveBoardBackward(s: var State, action: Action) = s.position -= action
# 展開直前に保存済みの評価値を復元する（Hashは位置から求まる）。
template loadLeaf(s: var State, leafScore: int, leafKey: int) = s.score = leafScore
# TODO: 合法な1ターン遷移を列挙し、仮適用・評価・巻き戻しをヘルパーに任せる。
proc expand(s: var State, frontier: var TourBeamFrontier[Action, int, int]) =
    for action in [1, 2]:
        if s.position+action <= s.target:
            s.pushCandidate(frontier, action)

defineTourBeam(tourBeam, State, Action, int, int)

when isMainModule:
    let initial = State(target: 10, score: 10)
    let answer = tourBeam(initial, beamWidth = 20, maxTurns = 5)
    echo answer.score
    echo answer.actions
    var replay = initial
    for action in answer.actions: replay.moveForward(action)
    doAssert answer.turns == 5 and answer.actions.len == 5
    doAssert answer.score == 0 and replay.position == 10
    doAssert initial.position == 0

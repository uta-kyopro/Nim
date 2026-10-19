include ../../lib/header
import ../../lib/search/skip_tour_beam_core

# skip_tour_beam.nim の「問題ごとに編集」を埋めた例。

# 0からtargetへ移動する例。+2は2ターン消費する。
type
    Action = int
    LeafData = object
        score, moves: int
    State = object
        position, target, score, moves: int
        isFinished: bool

template evaluate(s: State): int = s.score
proc getHash(s: State): int = s.position
proc moveForward(s: var State, action: Action) =
    s.position += action
    s.score -= action
    inc s.moves
    s.isFinished = s.position == s.target
proc moveBackward(s: var State, action: Action) =
    s.position -= action
    s.score += action
    dec s.moves
    s.isFinished = s.position == s.target

# 巡回中は位置と終了状態だけを更新する。
proc moveBoardForward(s: var State, action: Action) =
    s.position += action
    s.isFinished = s.position == s.target

# 巡回中は位置と終了状態だけを巻き戻す。
proc moveBoardBackward(s: var State, action: Action) =
    s.position -= action
    s.isFinished = s.position == s.target

# stepの合計とは別に、Actionの個数も葉ごとに保存する。
template getLeaf(s: State): LeafData = LeafData(score: s.score, moves: s.moves)
# 巡回中は変更しない補助情報を、展開直前にまとめて復元する。
template loadLeaf(s: var State, leaf: LeafData) =
    s.score = leaf.score
    s.moves = leaf.moves

proc expand(s: var State, frontier: var SkipTourBeamFrontier[Action, int, int, LeafData]) =
    doAssert s.moves == frontier.currentLeaf.moves
    for action in [1, 2]:
        if s.position + action > s.target: continue
        s.pushCandidate(frontier, action, step = action)

defineSkipTourBeam(skipTourBeam, State, Action, int, int, LeafData)

when isMainModule:
    let initial = State(position: 0, target: 10, score: 10)
    let answer = skipTourBeam(initial, beamWidth = 20)
    echo answer.score        # 0（evaluateの値）
    echo answer.actions      # targetへ到達する行動列
    echo answer.turns        # 10（actions.lenではなくstepの合計）
    echo answer.status       # beamFinished
    var replay = initial
    for action in answer.actions: replay.moveForward(action)
    doAssert replay.isFinished
    doAssert replay.evaluate() == answer.score
    doAssert replay.moves == answer.actions.len

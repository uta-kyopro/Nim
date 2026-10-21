include ../../lib/header
import ../../lib/search/skip_tour_beam_core

# skip_tour_beam.nim の「問題ごとに編集」を埋めた例。

# 0からtargetへ移動する例。+2は1個のActionで2ターン消費する。
# 整数評価値は符号付き48bit範囲、通常のビーム幅は65,536以下にする。
type
    Action = int
    LeafData = object
        score, moves: int
    State = object
        position, target, score, moves: int
        isFinished: bool
    Frontier = SkipTourBeamFrontier[Action, int, uint64, LeafData]

# 葉へ保存する残り距離を最小化する。
template evaluate(s: State): int = s.score
# この例では位置が同じなら同一状態として選抜する。
template getHash(s: State): uint64 = uint64(s.position)
# TODO: 候補の試算・最終再生用に、盤面・評価値・補助情報・終了状態を全て更新する。
proc moveForward(s: var State, action: Action) =
    s.position += action
    s.score -= action
    inc s.moves
    s.isFinished = s.position == s.target
# TODO: moveForwardが変更した情報を全て元に戻す。
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
# TODO: 巡回中に更新を省いた値を、展開直前に葉の保存値で上書きする。
# 保存は差分計算を省く一方でコピー量を増やすため、実問題では軽い方を測って選ぶ。
template loadLeaf(s: var State, leaf: LeafData) =
    s.score = leaf.score
    s.moves = leaf.moves

# TODO: 合法なActionと消費ターン数stepを渡し、仮適用・評価・巻き戻しを任せる。
proc expand(s: var State, frontier: var Frontier) =
    doAssert s.moves == frontier.currentLeaf.moves
    for action in [1, 2]:
        if s.position + action > s.target: continue
        s.pushCandidate(frontier, action, step = action)

defineSkipTourBeam(skipTourBeam, State, Action, int, uint64, LeafData)

when isMainModule:
    let initial = State(position: 0, target: 10, score: 10)
    let answer = skipTourBeam(initial, beamWidth = 20, maxTurns = 10)
    echo answer.score        # 0（evaluateの値）
    echo answer.actions      # targetへ到達する行動列
    echo answer.turns        # 10（actions.lenではなくstepの合計）
    echo answer.status       # beamFinished
    var replay = initial
    for action in answer.actions: replay.moveForward(action)
    doAssert replay.isFinished
    doAssert replay.evaluate() == answer.score
    doAssert replay.moves == answer.actions.len
    doAssert answer.turns == 10 and answer.status == beamFinished
    doAssert initial.position == 0

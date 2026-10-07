import ../../lib/search/thunder_beam_core

# thunder_beam.nim の「問題ごとに編集」を埋めた例。

# 0からtargetへ移動する例。+2は2ターン消費する。
type
    Action = int
    State = object
        position, target: int

proc evaluate(s: State): int = abs(s.target - s.position)
proc getHash(s: State): int = s.position
proc isFinished(s: State): bool = s.position == s.target
proc moveForward(s: var State, action: Action) = s.position += action
proc moveBackward(s: var State, action: Action) = s.position -= action

proc expand(s: var State, parent: int, frontier: var BeamFrontier[Action, int, int]) =
    for action in [1, 2]:
        if s.position + action > s.target: continue
        s.moveForward(action)
        let score = s.evaluate()
        let key = s.getHash()
        let finished = s.isFinished()
        s.moveBackward(action) # push前に元の状態へ戻す
        frontier.push(action, score, key, parent, finished, step = action)

defineThunderBeam(beamSearch, State, Action, int, int)

when isMainModule:
    let initial = State(position: 0, target: 10)
    let answer = beamSearch(initial, beamWidth = 20)
    echo answer.score        # 0（evaluateの値）
    echo answer.actions      # targetへ到達する行動列
    echo answer.turns        # 10（actions.lenではなくstepの合計）
    echo answer.status       # beamFinished
    var replay = initial
    for action in answer.actions: replay.moveForward(action)
    doAssert replay.isFinished()
    doAssert replay.evaluate() == answer.score

# 利用時に「問題ごとに編集」を書き換えるテンプレート。
# 探索エンジン thunder_beam_core.nim は編集不要。
import ./thunder_beam_core
export thunder_beam_core

# -------------------------------------------------------------------
# 問題ごとに編集：型
# -------------------------------------------------------------------
type
    CostType* = int
    HashType* = uint64
    Action* = int               # TODO: 1回の遷移と巻き戻しに必要な情報
    State* = object             # TODO: 盤面・評価差分・巻き戻し履歴などを追加

type Frontier* = BeamFrontier[Action, CostType, HashType]

# -------------------------------------------------------------------
# 問題ごとに編集：評価・終了判定・状態遷移
# -------------------------------------------------------------------
proc evaluate*(self: var State): CostType =
    # TODO: 評価値を返す。既定は最小化（小さいほど良い）。
    raise newException(ValueError, "implement evaluate")

proc getHash*(self: State): HashType =
    # TODO: 重複排除する状態のキー。同一ターンで同じキーは同一状態扱い。
    raise newException(ValueError, "implement getHash")

proc isFinished*(self: State): bool =
    # TODO: 完了条件。固定ターン問題ならfalseのままでよい。
    false

proc moveForward*(self: var State, action: Action) =
    # TODO: actionを適用。必要なら変更前の値を履歴に保存する。
    raise newException(ValueError, "implement moveForward")

proc moveBackward*(self: var State, action: Action) =
    # TODO: 直前のmoveForwardを完全に巻き戻す。
    raise newException(ValueError, "implement moveBackward")

# 候補登録の共通処理（通常は編集不要）。
proc pushCandidate*(self: var State, frontier: var Frontier, parent: int,
    action: Action, step = 1): bool {.discardable.} =
    self.moveForward(action)
    let score = self.evaluate()
    let key = self.getHash()
    let finished = self.isFinished()
    self.moveBackward(action)
    frontier.push(action, score, key, parent, finished, step)

# -------------------------------------------------------------------
# 問題ごとに編集：候補列挙
# -------------------------------------------------------------------
proc expand*(self: var State, parent: int, frontier: var Frontier) =
    # TODO: 合法なactionを列挙して登録する。
    # self.pushCandidate(frontier, parent, action)           # 1ターン遷移
    # self.pushCandidate(frontier, parent, action, step = 2) # 2ターン遷移
    # 候補がなければ何も登録せずreturn。終了時には元の状態に戻す。
    raise newException(ValueError, "implement expand")

# -------------------------------------------------------------------
# 呼び出し口（編集不要）
# -------------------------------------------------------------------
proc beamSearch*(initial: State, beamWidth: int, maxTurns = 2000,
    minimize = true, timeLimitSec = 0.0,
    minBeamWidth = 0, widthUpdateInterval = 256,
    stopOnTimeLimit = true): BeamResult[Action, CostType] =
    runThunderBeam[State, Action, CostType, HashType](
        initial, beamWidth, maxTurns, minimize, timeLimitSec, minBeamWidth,
        widthUpdateInterval, stopOnTimeLimit)

# let answer = beamSearch(initialState, beamWidth = 1000)
# echo answer.score
# echo answer.actions

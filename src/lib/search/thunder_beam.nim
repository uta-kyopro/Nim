# 利用時に「問題ごとに編集」を書き換えるテンプレート。
# 探索エンジン thunder_beam_core.nim は編集不要。
import ./thunder_beam_core
export thunder_beam_core

when not declared ThunderBeamModule:
    const ThunderBeamModule* = true
    # -------------------------------------------------------------------
    # 問題ごとに編集：型
    # -------------------------------------------------------------------
    type
        CostType* = int
        HashType* = uint64
        Action* = object    # TODO: 1回の遷移と巻き戻しに必要な情報
        State* = object     # TODO: 盤面・評価差分・巻き戻し履歴などを追加

    type Frontier* = BeamFrontier[Action, CostType, HashType]

    # -------------------------------------------------------------------
    # 問題ごとに編集：評価・終了判定・状態遷移
    # -------------------------------------------------------------------
    # TODO: 現在のStateの評価値を返す（既定は最小化、小さいほど良い）。
    proc evaluate*(self: var State): CostType =
        raise newException(ValueError, "implement evaluate")

    # TODO: 将来の遷移に影響する状態を含め、同一到達ターンの重複除去に使うキーを返す。
    proc getHash*(self: State): HashType =
        raise newException(ValueError, "implement getHash")

    # TODO: 完了条件を返す（固定ターンで最良を選ぶ問題なら常にfalse）。
    template isFinished*(self: State): bool =
        block:
            discard self
            false

    # TODO: actionをStateに適用し、巻き戻しに必要な変更前の値を履歴などへ保存する。
    proc moveForward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveForward")

    # TODO: 対応するmoveForwardの変更を取り消し、履歴も含めて直前のStateへ完全に戻す。
    proc moveBackward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveBackward")

    # 編集不要：actionを仮適用して評価・必要時だけHash計算し、巻き戻して候補を登録する。
    proc pushCandidate*(self: var State, frontier: var Frontier, parent: int,
        action: Action, step = 1, group = -1): bool {.discardable.} =
        if step > frontier.remainingTurns(): return false
        self.moveForward(action)
        let score = self.evaluate()
        let finished = self.isFinished()
        if not frontier.canImprove(score, step, finished, group):
            self.moveBackward(action)
            return false
        let key = self.getHash()
        self.moveBackward(action)
        frontier.push(action, score, key, parent, finished, step, group)

    # -------------------------------------------------------------------
    # 問題ごとに編集：候補列挙
    # -------------------------------------------------------------------
    # TODO: 合法なactionを列挙してself.pushCandidateで登録し、終了時のStateを元に戻す。
    proc expand*(self: var State, parent: int, frontier: var Frontier) =
        # self.pushCandidate(frontier, parent, action)           # 1ターン遷移
        # self.pushCandidate(frontier, parent, action, step = 2) # 2ターン遷移
        # 候補がなければ何も登録せずreturn。終了時には元の状態に戻す。
        raise newException(ValueError, "implement expand")

    # -------------------------------------------------------------------
    # 呼び出し口（編集不要）
    # -------------------------------------------------------------------
    # 編集不要：初期Stateと探索条件をcoreに渡し、最良の行動列と探索結果を返す。
    template beamSearch*(initial: State, beamWidth: int, maxTurns = 2000,
        minimize = true, timeLimitSec = 0.0,
        minBeamWidth = 0, widthUpdateInterval = 256,
        stopOnTimeLimit = true, groupLimit = 0, groupCount = 0): BeamResult[Action, CostType] =
        runThunderBeam[State, Action, CostType, HashType](
            initial, beamWidth, maxTurns, minimize, timeLimitSec, minBeamWidth,
            widthUpdateInterval, stopOnTimeLimit, groupLimit, groupCount)

# let answer = beamSearch(initialState, beamWidth = 1000)
# echo answer.score
# echo answer.actions

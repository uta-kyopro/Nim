# 利用時に「問題ごとに編集」を書き換えるテンプレート。
# 探索エンジン skip_beam_core.nim は編集不要。
import ./skip_beam_core
export skip_beam_core

when not declared SkipBeamModule:
    const SkipBeamModule* = true
    # -------------------------------------------------------------------
    # 問題ごとに編集：型
    # -------------------------------------------------------------------
    type
        CostType* = int
        HashType* = uint64
        Action* = object    # TODO: 1回の遷移と巻き戻しに必要な情報
        State* = object     # TODO: 盤面・評価差分・巻き戻し履歴などを追加
            score*: CostType # TODO: 初期化し、適用時に差分更新・巻き戻し時に復元する。
            hash*: HashType # TODO: 初期化し、適用時に差分更新・巻き戻し時に復元する。
            isFinished*: bool # TODO: 完了時にtrue。固定ターン探索はfalseのままでよい。

    type Frontier* = BeamFrontier[Action, CostType, HashType]

    # -------------------------------------------------------------------
    # 問題ごとに編集：評価・終了判定・状態遷移
    # -------------------------------------------------------------------
    # 保持している評価値を返す（既定は最小化）。必要なら計算式へ書き換える。
    template evaluate*(self: State): CostType =
        self.score

    # 保持しているHashを返す。TODO: self.hashには将来の遷移に影響する状態を反映する。
    template getHash*(self: State): HashType =
        self.hash

    # TODO: isFinishedも更新し、actionを適用して評価値・Hashも差分更新し、巻き戻しに必要な変更前の値を保存する。
    proc moveForward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveForward")

    # TODO: isFinishedも復元し、対応するmoveForwardの変更を取り消し、評価値・Hashと履歴も直前のStateへ完全に戻す。
    proc moveBackward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveBackward")

    # TODO: 巡回時に必要な盤面・履歴・isFinishedだけを更新する。
    proc moveBoardForward*(self: var State, action: Action) =
        self.moveForward(action) # TODO: 評価値・Hashの更新を除いた処理に置き換える。

    # TODO: moveBoardForwardの盤面・履歴・isFinishedを元に戻す。
    proc moveBoardBackward*(self: var State, action: Action) =
        self.moveBackward(action) # TODO: 評価値・Hashの更新を除いた処理に置き換える。

    # TODO: 保存値から評価用のStateを復元する。評価式が異なる場合は逆変換する。
    template loadLeaf*(self: var State, leafScore: CostType, leafKey: HashType) =
        self.score = leafScore
        self.hash = leafKey

    # -------------------------------------------------------------------
    # 問題ごとに編集：候補列挙
    # -------------------------------------------------------------------
    # TODO: 合法なactionを列挙してself.pushCandidateで登録し、終了時のStateを元に戻す。
    proc expand*(self: var State, frontier: var Frontier) =
        # self.pushCandidate(frontier, action)           # 1ターン遷移
        # self.pushCandidate(frontier, action, step = 2) # 2ターン遷移
        # 候補がなければ何も登録せずreturn。終了時には元の状態に戻す。
        raise newException(ValueError, "implement expand")

    # -------------------------------------------------------------------
    # 呼び出し口（編集不要）
    # -------------------------------------------------------------------
    # 編集不要：初期Stateと探索条件をcoreに渡し、最良の行動列と探索結果を返す。
    template skipBeam*(initial: State, beamWidth: int, maxTurns = 2000,
        minimize = true, timeLimitSec = 0.0,
        minBeamWidth = 0, widthUpdateInterval = 256,
        stopOnTimeLimit = true, groupLimit = 0, groupCount = 0): BeamResult[Action, CostType] =
        runSkipBeam[State, Action, CostType, HashType](
            initial, beamWidth, maxTurns, minimize, timeLimitSec, minBeamWidth,
            widthUpdateInterval, stopOnTimeLimit, groupLimit, groupCount)

# let answer = skipBeam(initialState, beamWidth = 1000)
# echo answer.score
# echo answer.actions

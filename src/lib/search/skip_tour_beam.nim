include ../header

# 利用時に「問題ごとに編集」を書き換える、世代スキップ対応のテンプレート。
import ./skip_tour_beam_core
export skip_tour_beam_core

when not declared SkipTourBeamModule:
    const SkipTourBeamModule* = true

    type
        CostType* = int
        HashType* = uint64
        Action* = object # TODO: 1回の遷移と巻き戻しに必要な情報を入れる。
        State* = object # TODO: 盤面・差分計算用の情報を追加する。
            score*: CostType # TODO: 初期化し、適用・巻き戻しで差分更新する。
            hash*: HashType # TODO: 初期化し、適用・巻き戻しで差分更新する。
            isFinished*: bool # TODO: 完了時にtrue。固定ターン探索はfalseのままでよい。
        Frontier* = SkipTourBeamFrontier[Action, CostType, HashType]

    # 保持している評価値を返す。必要なら評価式へ書き換える。
    template evaluate*(self: State): CostType = self.score

    # TODO: 将来の遷移に影響する状態を反映したHashを返す（既定はself.hash）。
    template getHash*(self: State): HashType = self.hash

    # TODO: isFinishedも更新し、actionを適用し、評価値・Hashと差分計算用の情報も更新する。
    proc moveForward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveForward")

    # TODO: isFinishedも復元し、対応するmoveForwardの変更を、評価値・Hashも含めて完全に戻す。
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

    # TODO: Actionと消費世代数stepをself.pushCandidateで登録し、終了時のStateを元に戻す。
    proc expand*(self: var State, frontier: var Frontier) =
        # self.pushCandidate(frontier, action, step = consumedTurns)
        # バケット化する場合は self.pushCandidate(frontier, action, group = groupId)
        raise newException(ValueError, "implement expand")

    # 編集不要：初期Stateと探索条件をcoreに渡し、最良の行動列を返す。
    template skipTourBeam*(initial: State, beamWidth: int, maxTurns = 2000,
            minimize = true, groupLimit = 0, groupCount = 0): SkipTourBeamResult[Action, CostType] =
        runSkipTourBeam[State, Action, CostType, HashType](initial, beamWidth,
            maxTurns, minimize, groupLimit, groupCount)

# let answer = skipTourBeam(initialState, beamWidth = 1000, maxTurns = 100)
# echo answer.score
# echo answer.actions

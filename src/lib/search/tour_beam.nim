include ../header

# 利用時に「問題ごとに編集」を書き換える、1ターン遷移専用のテンプレート。
import ./tour_beam_core
export tour_beam_core

when not declared TourBeamModule:
    const TourBeamModule* = true

    type
        CostType* = int
        HashType* = uint64
        LeafData* = object # TODO: 葉ごとに保存し、巡回中の更新を省きたい情報をまとめる。
            score*: CostType
            hash*: HashType
        Action* = object # TODO: 1回の遷移と巻き戻しに必要な情報を入れる。
        State* = object # TODO: 盤面・差分計算用の情報を追加する。
            score*: CostType # TODO: 初期化し、適用・巻き戻しで差分更新する。
            hash*: HashType # TODO: 初期化し、適用・巻き戻しで差分更新する。
            isFinished*: bool # TODO: 完了時にtrue。固定ターン探索はfalseのままでよい。
        Frontier* = TourBeamFrontier[Action, CostType, HashType, LeafData]

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

    # 葉への保存は巡回中の差分計算を省く一方、候補の保存・コピー量を増やす。
    # 軽い加減算は差分更新が速い場合もあるため、保存する情報は実測で判断する。
    # TODO: 遷移後のStateから保存したい値を返す。評価値と異なる実コストなども追加できる。
    template getLeaf*(self: State): LeafData =
        LeafData(score: self.score, hash: self.hash)

    # TODO: getLeafで保存した値をStateへ戻す。盤面・履歴は巡回処理が復元する。
    template loadLeaf*(self: var State, leaf: LeafData) =
        self.score = leaf.score
        self.hash = leaf.hash

    # TODO: 合法なActionを列挙してself.pushCandidateで登録し、終了時のStateを元に戻す。
    proc expand*(self: var State, frontier: var Frontier) =
        # self.pushCandidate(frontier, action)
        # バケット化する場合は self.pushCandidate(frontier, action, group = groupId)
        raise newException(ValueError, "implement expand")

    # 編集不要：初期Stateと探索条件をcoreに渡し、最良の行動列を返す。
    template tourBeam*(initial: State, beamWidth: int, maxTurns = 2000,
            minimize = true, groupLimit = 0, groupCount = 0): TourBeamResult[Action, CostType] =
        runTourBeam[State, Action, CostType, HashType, LeafData](initial, beamWidth,
            maxTurns, minimize, groupLimit, groupCount)

# let answer = tourBeam(initialState, beamWidth = 1000, maxTurns = 100)
# echo answer.score
# echo answer.actions

# 問題ごとに型・評価・Hash・展開を書き換えるテンプレート。
import ./beam_search_core
export beam_search_core

when not declared BeamSearchModule:
    const BeamSearchModule* = true
    type
        CostType* = int
        HashType* = uint64
        Action* = object # TODO: 1回の遷移を再現する操作・選択を格納する。
        State* = object # TODO: 盤面など、各候補が所有する状態（履歴は不要）。
            hash*: HashType # TODO: 初期化し、遷移時にZobristHashを差分更新する。
            isFinished*: bool # TODO: 完了時にtrue。固定ターン探索はfalseのままでよい。
        Node* = BeamSearchNode[State, CostType, HashType, Action]
        Frontier* = BeamSearchFrontier[State, CostType, HashType, Action]

    # TODO: 現在のStateの評価値を返す（既定は最小化、小さいほど良い）。
    proc evaluate*(self: State): CostType =
        raise newException(ValueError, "implement evaluate")

    # 保持しているHashを返す。TODO: self.hashには将来の遷移に影響する状態を反映する。
    template getHash*(self: State): HashType =
        self.hash

    # TODO: 合法な遷移ごとにStateをコピー・更新し、next.pushCandidate(frontier, action)で登録する。
    proc expand*(self: var State, frontier: var Frontier) =
        # var next = self
        # nextに遷移を適用し、next.hashとnext.isFinishedを更新する。
        # next.pushCandidate(frontier, action)
        # バケット化を使う場合は next.pushCandidate(frontier, action, group = groupId)
        raise newException(ValueError, "implement expand")

    # 編集不要：初期Stateと探索条件をcoreに渡し、最良Stateと探索結果を返す。
    template beamSearch*(initial: State, beamWidth: int, maxTurns = 2000,
        minimize = true, groupLimit = 0, groupCount = 0): BeamSearchResult[State, CostType, HashType, Action] =
        runBeamSearch[State, CostType, HashType, Action](
            initial, beamWidth, maxTurns, minimize, groupLimit, groupCount)

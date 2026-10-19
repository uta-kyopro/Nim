include ../../header

## Stateをコピーする層ごとのビームサーチ。探索木や巻き戻しは使わない。
when not declared BeamSearchCoreModule:
    const BeamSearchCoreModule* = true
    type
        NoBeamAction* = object ## Action履歴を使用しない既存API向けの型。
        BeamStatus* = enum
            beamFinished, beamMaxTurns, beamExhausted
        BeamSearchNode*[State, Score, Key; Action = NoBeamAction] = object
            state*: State
            score*: Score
            key*: Key
            when Action isnot NoBeamAction:
                parentId*: int
                action*: Action
        BeamSearchResult*[State, Score, Key; Action = NoBeamAction] = object
            state*: State
            score*: Score
            key*: Key
            turns*: int
            status*: BeamStatus
            selectedCandidates*: int64
            actions*: seq[Action]
        BeamSearchFrontier*[State, Score, Key; Action = NoBeamAction] = object
            nodes: seq[BeamSearchNode[State, Score, Key, Action]]
            indices: Table[Key, int]
            # セグ木は最悪候補のスロット番号だけを保持し、評価値はNodeから読む。
            worst: seq[int]
            width, size: int
            minimize, hasFinished: bool
            finished: BeamSearchNode[State, Score, Key, Action]
            groupLimit: int
            buckets: seq[seq[BeamSearchNode[State, Score, Key, Action]]]
            when Action isnot NoBeamAction:
                parentId: int

    # Stateに実在するboolフィールドだけを読み、旧判定関数形式は受け付けない。
    template simpleFinishedField(state: typed): bool =
        const hasFinishedField = block:
            var found = false
            var probe: typeof(state)
            for name, field in fieldPairs(probe):
                when name == "isFinished":
                    when field is bool: found = true
            found
        when not hasFinishedField:
            {.error: "State must contain an isFinished: bool field".}
        else:
            state.isFinished


    # 評価方向に従い、aがbより良いか判定する。
    template simpleBetter[S](a, b: S, minimize: bool): bool =
        block:
            let first = a
            let second = b
            let isMinimum = minimize
            if isMinimum: first < second else: second < first

    # 無効な葉を除き、2候補のうち悪い方のindexを返す（同点は左を優先）。
    template simpleWorst[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A], a, b: int): int =
        block:
            let frontier = addr f
            let first = a
            let second = b
            if first < 0: second
            elif second < 0: first
            elif simpleBetter(frontier[].nodes[first].score, frontier[].nodes[second].score,
                frontier[].minimize): second
            else: first

    # 幅に達した時点で葉と最悪indexを一括構築し、確保済みの配列を再利用する。
    proc simpleBuild[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A]) =
        f.worst.setLen(f.size * 2)
        for entry in f.worst.mitems: entry = -1
        for i in 0..<f.width: f.worst[f.size+i] = i
        for p in countdown(f.size-1, 1):
            let left = p shl 1
            f.worst[p] = f.simpleWorst(f.worst[left], f.worst[left or 1])

    # Nodeの評価値変更を反映し、葉のindexを固定したまま根まで最悪候補を更新する。
    proc simpleUpdate[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A], index: int) =
        var p = (f.size+index) shr 1
        while p > 0:
            let left = p shl 1
            f.worst[p] = f.simpleWorst(f.worst[left], f.worst[left or 1])
            p = p shr 1

    # 候補配列とHash表を確保し、一括構築するセグ木の葉数を決める。
    proc initBeamSearchFrontierImpl[T, S, K, A](beamWidth: int, minimize = true,
            groupLimit = 0, groupCount = 0): BeamSearchFrontier[T, S, K, A] =
        when defined(debug):
            if beamWidth <= 0: raise newException(ValueError, "beamWidth must be positive")
            if groupLimit < 0 or groupCount < 0 or (groupLimit > 0 and groupCount <= 0):
                raise newException(ValueError, "invalid group bucket dimensions")
        when A isnot NoBeamAction: result.parentId = -1
        result.width = beamWidth
        result.minimize = minimize
        result.groupLimit = groupLimit
        result.size = 1
        while result.size < beamWidth: result.size *= 2
        result.nodes = newSeqOfCap[BeamSearchNode[T, S, K, A]](if groupLimit > 0: 0 else: beamWidth)
        if groupLimit > 0:
            result.buckets = newSeq[seq[BeamSearchNode[T, S, K, A]]](groupCount)
        else:
            result.indices = initTable[K, int]()

    # Actionを使用しない既存の型指定で候補管理を初期化する。
    template initBeamSearchFrontier*[T, S, K; A = NoBeamAction](beamWidth: int, minimize = true,
            groupLimit = 0, groupCount = 0): untyped =
        initBeamSearchFrontierImpl[T, S, K, A](beamWidth, minimize, groupLimit, groupCount)

    # 評価値と完了判定から、候補に採用の余地があるかをHash計算前に判定する。
    proc canImprove*[T, S, K, A](f: BeamSearchFrontier[T, S, K, A], score: S,
        finished = false, group = -1): bool =
        ## trueでも同一キーのより良い候補があれば不採用になる。
        when defined(debug):
            if f.groupLimit > 0 and (group < 0 or group >= f.buckets.len):
                raise newException(ValueError, "beam group out of range")
        if finished: return not f.hasFinished
        if f.groupLimit > 0: return true
        f.nodes.len < f.width or simpleBetter(score, f.nodes[f.worst[1]].score, f.minimize)

    # 評価済みStateを登録し、同じキーの改善または満杯時の最悪候補の置換を行う。
    proc push*[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A], state: T,
            score: S, key: K, finished = false, action: A, group = -1): bool {.discardable.} =
        if not f.canImprove(score, finished, group): return false
        # 採用する候補だけState・Action・親履歴IDをNodeへまとめる。
        template makeNode(): untyped =
            block:
                var node = BeamSearchNode[T, S, K, A](state: state, score: score, key: key)
                when A isnot NoBeamAction:
                    node.parentId = f.parentId
                    node.action = action
                node
        if finished:
            f.finished = makeNode()
            f.hasFinished = true
            return true
        if f.groupLimit > 0:
            f.buckets[group].add(makeNode())
            return true
        var index = f.indices.getOrDefault(key, -1)
        if index >= 0:
            if not simpleBetter(score, f.nodes[index].score, f.minimize): return false
            f.nodes[index] = makeNode()
            if f.nodes.len == f.width: f.simpleUpdate(index)
        elif f.nodes.len < f.width:
            index = f.nodes.len
            f.nodes.add(makeNode())
            f.indices[key] = index
            if f.nodes.len == f.width: f.simpleBuild()
        else:
            index = f.worst[1]
            f.indices.del(f.nodes[index].key)
            f.nodes[index] = makeNode()
            f.indices[key] = index
            f.simpleUpdate(index)
        true

    # Actionを使用しない既存の呼び出しを候補登録へ渡す。
    proc push*[T, S, K](f: var BeamSearchFrontier[T, S, K], state: T,
            score: S, key: K, finished = false, group = -1): bool {.discardable.} =
        f.push(state, score, key, finished, NoBeamAction(), group)

    # State・評価値・キーをまとめたNodeを候補として登録する。
    proc push*[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A],
            node: BeamSearchNode[T, S, K, A], finished = false, group = -1): bool {.discardable.} =
        when A is NoBeamAction:
            f.push(node.state, node.score, node.key, finished, group)
        else:
            f.push(node.state, node.score, node.key, finished, node.action, group)

    # 遷移後のStateを評価し、採用の余地がある場合だけHashを計算して登録する。
    proc pushCandidate*[T, S, K, A](state: var T,
            f: var BeamSearchFrontier[T, S, K, A], action: A, group = -1): bool {.discardable.} =
        mixin evaluate, getHash
        let score = state.evaluate()
        let finished = simpleFinishedField(state)
        if not f.canImprove(score, finished, group): return false
        f.push(state, score, state.getHash(), finished, action, group)

    # Actionを使用しない既存の呼び出しを評価・候補登録へ渡す。
    proc pushCandidate*[T, S, K](state: var T,
            f: var BeamSearchFrontier[T, S, K], group = -1): bool {.discardable.} =
        state.pushCandidate(f, NoBeamAction(), group)

    # グループID順にHashの重複を除去し、各グループの上位候補を確定する。
    proc simpleSelectGroups[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A]) =
        if f.groupLimit <= 0: return
        var seen = initHashSet[K](0)
        let minimize = f.minimize
        for bucket in f.buckets.mitems:
            # 安定ソートで同点の登録順を保ち、同じHashの重複は枠を消費させない。
            bucket.sort(proc(a, b: BeamSearchNode[T, S, K, A]): int =
                if simpleBetter(a.score, b.score, minimize): -1
                elif simpleBetter(b.score, a.score, minimize): 1
                else: 0)
            var kept = 0
            for node in bucket:
                if node.key in seen: continue
                seen.incl(node.key)
                f.nodes.add(node)
                inc kept
                if kept == f.groupLimit: break
            bucket.setLen(0)

    # Stateをコピーして層ごとに展開・選抜し、終了条件に応じた最良候補を返す。
    proc runBeamSearchImpl[State, Score, Key, Action](initial: State, beamWidth: int,
            maxTurns = 2000, minimize = true, groupLimit = 0,
            groupCount = 0): BeamSearchResult[State, Score, Key, Action] =
        mixin evaluate, getHash, expand
        when defined(debug):
            if maxTurns < 0: raise newException(ValueError, "maxTurns must be nonnegative")
        when Action isnot NoBeamAction:
            var history: seq[tuple[parentId: int, action: Action]]
            var layerBase = -1
        # 選んだ候補の親履歴を辿り、Actionを探索時の順序へ戻す。
        template restoreActions(node: untyped) =
            when Action isnot NoBeamAction:
                if result.turns > 0:
                    result.actions = newSeq[Action](result.turns)
                    var step = result.turns - 1
                    result.actions[step] = node.action
                    var parent = node.parentId
                    while parent >= 0:
                        dec step
                        result.actions[step] = history[parent].action
                        parent = history[parent].parentId
                    doAssert step == 0
        # 終了時だけ指定層を走査し、最良候補を結果へコピーする。
        template storeBest(nodes: untyped) =
            block:
                var best = 0
                for i in 1..<nodes.len:
                    if simpleBetter(nodes[i].score, nodes[best].score, minimize): best = i
                result.state = nodes[best].state
                result.score = nodes[best].score
                result.key = nodes[best].key
                restoreActions(nodes[best])
        var frontier = initBeamSearchFrontier[State, Score, Key, Action](beamWidth, minimize, groupLimit, groupCount)
        var current = @[BeamSearchNode[State, Score, Key, Action](state: initial)]
        current[0].score = current[0].state.evaluate()
        current[0].key = current[0].state.getHash()
        result.status = beamMaxTurns
        if simpleFinishedField(current[0].state):
            result.status = beamFinished
            storeBest(current)
            return
        if maxTurns == 0:
            storeBest(current)
            return
        for turn in 1..maxTurns:
            for i in 0..<current.len:
                when Action isnot NoBeamAction:
                    frontier.parentId = if turn == 1: -1 else: layerBase + i
                current[i].state.expand(frontier)
            frontier.simpleSelectGroups()
            result.selectedCandidates += int64(frontier.nodes.len + ord(frontier.hasFinished))
            if frontier.hasFinished:
                result.state = frontier.finished.state
                result.score = frontier.finished.score
                result.key = frontier.finished.key
                result.turns = turn
                result.status = beamFinished
                restoreActions(frontier.finished)
                return
            if frontier.nodes.len == 0:
                result.status = beamExhausted
                storeBest(current)
                return
            result.turns = turn
            if turn == maxTurns:
                storeBest(frontier.nodes)
                return
            when Action isnot NoBeamAction:
                layerBase = history.len
                for node in frontier.nodes:
                    history.add((node.parentId, node.action))
            # 前層の配列を次の候補バッファとして再利用する。
            swap(current, frontier.nodes)
            frontier.nodes.setLen(0)
            frontier.indices.clear()

    # Actionを使用しない既存の型指定でStateコピー型探索を実行する。
    template runBeamSearch*[State, Score, Key; Action = NoBeamAction](initial: State, beamWidth: int,
            maxTurns = 2000, minimize = true, groupLimit = 0, groupCount = 0): untyped =
        runBeamSearchImpl[State, Score, Key, Action](initial, beamWidth, maxTurns, minimize, groupLimit, groupCount)

    # State・評価値・キー・Actionの型を固定し、指定名の探索関数を定義する。
    template defineBeamSearch*(name, State, Score, Key: untyped; Action: untyped = NoBeamAction) =
        # 型を固定した探索条件をrunBeamSearchへ渡す。
        template name(initial: State, beamWidth: int, maxTurns = 2000,
            minimize = true, groupLimit = 0, groupCount = 0): BeamSearchResult[State, Score, Key, Action] =
            runBeamSearch[State, Score, Key, Action](initial, beamWidth, maxTurns, minimize, groupLimit, groupCount)

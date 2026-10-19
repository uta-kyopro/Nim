include ../header

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
            # セグ木は評価値とNodeのスロット番号だけを保持する。
            worst: seq[tuple[score: Score, index: int]]
            width, size: int
            minimize, hasFinished: bool
            finished: BeamSearchNode[State, Score, Key, Action]
            when Action isnot NoBeamAction:
                parentId: int

    # 評価方向に従い、aがbより良いか判定する。
    template simpleBetter[S](a, b: S, minimize: bool): bool =
        block:
            let first = a
            let second = b
            let isMinimum = minimize
            if isMinimum: first < second else: second < first

    # 無効な葉を除き、セグ木の2要素のうち悪い方を返す。
    template simpleWorst[S](a, b: tuple[score: S, index: int],
        minimize: bool): tuple[score: S, index: int] =
        block:
            let first = a
            let second = b
            let isMinimum = minimize
            if first.index < 0: second
            elif second.index < 0: first
            elif simpleBetter(first.score, second.score, isMinimum): second
            else: first

    # 指定Nodeの評価値をセグ木へ反映し、根まで最悪候補を更新する。
    proc simpleUpdate[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A], index: int) =
        var p = f.size + index
        f.worst[p] = (f.nodes[index].score, index)
        p = p shr 1
        while p > 0:
            let left = p shl 1
            f.worst[p] = simpleWorst(f.worst[left], f.worst[left or 1], f.minimize)
            p = p shr 1

    # 指定幅の候補配列・重複除去用Hash表・最悪値を管理するセグ木を初期化する。
    proc initBeamSearchFrontierImpl[T, S, K, A](beamWidth: int, minimize = true): BeamSearchFrontier[T, S, K, A] =
        when defined(debug):
            if beamWidth <= 0: raise newException(ValueError, "beamWidth must be positive")
        when A isnot NoBeamAction: result.parentId = -1
        result.width = beamWidth
        result.minimize = minimize
        result.size = 1
        while result.size < beamWidth: result.size *= 2
        result.nodes = newSeqOfCap[BeamSearchNode[T, S, K, A]](beamWidth)
        result.indices = initTable[K, int]()
        result.worst = newSeq[tuple[score: S, index: int]](result.size * 2)
        for entry in result.worst.mitems: entry.index = -1

    # Actionを使用しない既存の型指定で候補管理を初期化する。
    template initBeamSearchFrontier*[T, S, K; A = NoBeamAction](beamWidth: int, minimize = true): untyped =
        initBeamSearchFrontierImpl[T, S, K, A](beamWidth, minimize)

    # 評価値と完了判定から、候補に採用の余地があるかをHash計算前に判定する。
    proc canImprove*[T, S, K, A](f: BeamSearchFrontier[T, S, K, A], score: S,
        finished = false): bool =
        ## trueでも同一キーのより良い候補があれば不採用になる。
        if finished: return not f.hasFinished
        f.nodes.len < f.width or simpleBetter(score, f.worst[1].score, f.minimize)

    # 評価済みStateを登録し、同じキーの改善または満杯時の最悪候補の置換を行う。
    proc push*[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A], state: T,
            score: S, key: K, finished = false, action: A): bool {.discardable.} =
        if not f.canImprove(score, finished): return false
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
        var index = f.indices.getOrDefault(key, -1)
        if index >= 0:
            if not simpleBetter(score, f.nodes[index].score, f.minimize): return false
            f.nodes[index] = makeNode()
        elif f.nodes.len < f.width:
            index = f.nodes.len
            f.nodes.add(makeNode())
            f.indices[key] = index
        else:
            index = f.worst[1].index
            f.indices.del(f.nodes[index].key)
            f.nodes[index] = makeNode()
            f.indices[key] = index
        f.simpleUpdate(index)
        true

    # Actionを使用しない既存の呼び出しを候補登録へ渡す。
    proc push*[T, S, K](f: var BeamSearchFrontier[T, S, K], state: T,
            score: S, key: K, finished = false): bool {.discardable.} =
        f.push(state, score, key, finished, NoBeamAction())

    # State・評価値・キーをまとめたNodeを候補として登録する。
    proc push*[T, S, K, A](f: var BeamSearchFrontier[T, S, K, A],
            node: BeamSearchNode[T, S, K, A], finished = false): bool {.discardable.} =
        when A is NoBeamAction:
            f.push(node.state, node.score, node.key, finished)
        else:
            f.push(node.state, node.score, node.key, finished, node.action)

    # 遷移後のStateを評価し、採用の余地がある場合だけHashを計算して登録する。
    proc pushCandidate*[T, S, K, A](state: var T,
            f: var BeamSearchFrontier[T, S, K, A], action: A): bool {.discardable.} =
        mixin evaluate, getHash, isFinished
        let score = state.evaluate()
        let finished = state.isFinished()
        if not f.canImprove(score, finished): return false
        f.push(state, score, state.getHash(), finished, action)

    # Actionを使用しない既存の呼び出しを評価・候補登録へ渡す。
    proc pushCandidate*[T, S, K](state: var T,
            f: var BeamSearchFrontier[T, S, K]): bool {.discardable.} =
        state.pushCandidate(f, NoBeamAction())

    # Stateをコピーして層ごとに展開・選抜し、終了条件に応じた最良候補を返す。
    proc runBeamSearchImpl[State, Score, Key, Action](initial: State, beamWidth: int,
            maxTurns = 2000, minimize = true): BeamSearchResult[State, Score, Key, Action] =
        mixin evaluate, getHash, isFinished, expand
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
        var frontier = initBeamSearchFrontier[State, Score, Key, Action](beamWidth, minimize)
        var current = @[BeamSearchNode[State, Score, Key, Action](state: initial)]
        current[0].score = current[0].state.evaluate()
        current[0].key = current[0].state.getHash()
        result.status = beamMaxTurns
        if current[0].state.isFinished():
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
            for entry in frontier.worst.mitems: entry.index = -1

    # Actionを使用しない既存の型指定でStateコピー型探索を実行する。
    template runBeamSearch*[State, Score, Key; Action = NoBeamAction](initial: State, beamWidth: int,
            maxTurns = 2000, minimize = true): untyped =
        runBeamSearchImpl[State, Score, Key, Action](initial, beamWidth, maxTurns, minimize)

    # State・評価値・キー・Actionの型を固定し、指定名の探索関数を定義する。
    template defineBeamSearch*(name, State, Score, Key: untyped; Action: untyped = NoBeamAction) =
        # 型を固定した探索条件をrunBeamSearchへ渡す。
        template name(initial: State, beamWidth: int, maxTurns = 2000,
            minimize = true): BeamSearchResult[State, Score, Key, Action] =
            runBeamSearch[State, Score, Key, Action](initial, beamWidth, maxTurns, minimize)

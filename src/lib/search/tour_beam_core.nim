include ../header
include ./tour_beam_common

## 経路配列と葉の境界で巡回する1ターン遷移専用ビームサーチ。
## Stateは1つだけ保持し、候補ごとのコピーや親・兄弟リンクは使わない。
when not declared TourBeamCoreModule:
    const TourBeamCoreModule* = true

    type
        TourBeamStatus* = enum
            beamFinished, beamMaxTurns, beamExhausted
        TourBeamResult*[Action, Score] = object
            score*: Score
            actions*: seq[Action]
            turns*: int
            status*: TourBeamStatus
            selectedCandidates*: int64
        TourCandidate[A, S, K, L] = TourCommonCandidate[A, S, K, L]
        TourSelector[A, S, K, L] = TourCommonSelector[A, S, K, L, false]
        TourBeamFrontier*[Action, Score, Key; Leaf = void] = object
            currentScore*: Score # 展開中の葉の評価値。
            when Leaf isnot void:
                currentLeaf*: Leaf # 展開中の葉に保存した任意の情報。
            currentHash*: Key # 展開中の葉のHash。
            selector: TourSelector[Action, Score, Key, Leaf]
            currentParent, remaining: int
        TourTree[State, Action] = object
            state: State
            # traceは現在位置までの経路、tourは葉の間で戻る経路の断片。
            trace, tour, nextTour: seq[Action]
            leaves, nextLeaves: seq[int]
            visitOrder, offsets, expandedLeaves: seq[int]

    # 次の1層の候補管理を初期化する。groupLimit > 0なら全体幅の代わりにグループ別選抜を使う。
    proc initTourBeamFrontier*[A, S, K, L](beamWidth: int, minimize = true,
            groupLimit = 0, groupCount = 0, groupLocalHash = false): TourBeamFrontier[A, S, K, L] =
        when S is SomeSignedInt:
            if groupLimit == 0 and beamWidth > TourPackedMaxWidth:
                raise newException(ValueError, "beamWidth must not exceed 65536 for packed integer scores")
        when defined(debug):
            if beamWidth <= 0: raise newException(ValueError, "beamWidth must be positive")
            if groupLimit < 0 or groupCount < 0 or (groupLimit > 0 and groupCount <= 0):
                raise newException(ValueError, "invalid group bucket dimensions")
        result.remaining = int.high
        result.selector = TourSelector[A, S, K, L](width: beamWidth, minimize: minimize,
            groupLimit: groupLimit, groupCount: groupCount, groupLocalHash: groupLocalHash,
            candidates: newSeqOfCap[TourCandidate[A, S, K, L]](if groupLimit > 0: 0 else: beamWidth))
        if groupLimit > 0 and groupLocalHash:
            result.selector.groups.setLen(groupCount)
        elif groupLimit > 0:
            result.selector.buckets = newSeq[seq[TourCandidate[A, S, K, L]]](groupCount)
        else:
            result.selector.indices = initTourCommonHashMap[K](beamWidth)

    # 任意の葉情報を追加しない従来形式のフロンティアを初期化する。
    template initTourBeamFrontier*[A, S, K](beamWidth: int, minimize = true,
            groupLimit = 0, groupCount = 0, groupLocalHash = false): TourBeamFrontier[A, S, K] =
        initTourBeamFrontier[A, S, K, void](beamWidth, minimize, groupLimit, groupCount, groupLocalHash)

    # 現在の展開位置から探索上限までの残りターン数を返す。
    template remainingTurns*[A, S, K, L](frontier: TourBeamFrontier[A, S, K, L]): int =
        frontier.remaining

    # Hash取得前に足切りする。trueでも同じHashのより良い候補があれば不採用になる。
    proc canImprove*[A, S, K, L](frontier: TourBeamFrontier[A, S, K, L], score: S,
            finished = false, group = -1): bool =
        let s = frontier.selector
        tourCommonCheckScore(score)
        when defined(debug):
            if s.groupLimit > 0 and (group < 0 or group >= s.groupCount):
                raise newException(ValueError, "beam group out of range")
        if frontier.remaining <= 0: return false
        if finished: return not s.hasFinished
        if s.groupLimit > 0: return s.tourCommonGroupCanImprove(score, group)
        s.candidates.len < s.width or
            tourCommonBetter(score, s.candidates[s.worst[1]].score, s.minimize)

    # 評価済み候補を登録する。leafには遷移後の任意の保存情報を渡す。
    proc push*[A, S, K, L](frontier: var TourBeamFrontier[A, S, K, L], action: A,
            score: S, key: K, leaf: L, finished = false, group = -1): bool {.discardable.} =
        if not frontier.canImprove(score, finished, group): return false
        frontier.selector.tourCommonPush(TourCandidate[A, S, K, L](action: action, score: score,
            key: key, leaf: leaf, parent: frontier.currentParent), finished, group, true)

    # 任意の葉情報を追加しない従来形式の候補を登録する。
    proc push*[A, S, K](frontier: var TourBeamFrontier[A, S, K], action: A,
            score: S, key: K, finished = false, group = -1): bool {.discardable.} =
        if not frontier.canImprove(score, finished, group): return false
        frontier.selector.tourCommonPush(TourCandidate[A, S, K, void](action: action, score: score,
            key: key, parent: frontier.currentParent), finished, group, true)

    # Actionを仮適用して評価・必要時のHash取得・巻き戻しを行い、候補を登録する。
    proc pushCandidate*[T, A, S, K, L](self: var T, frontier: var TourBeamFrontier[A, S, K, L],
            action: A, group = -1): bool {.discardable.} =
        mixin moveForward, moveBackward, evaluate, getHash, getLeaf
        if frontier.remaining <= 0: return false
        self.moveForward(action)
        let score = self.evaluate()
        let finished = tourCommonFinishedField(self)
        if not frontier.canImprove(score, finished, group):
            self.moveBackward(action)
            return false
        let key = self.getHash()
        var candidate = TourCandidate[A, S, K, L](action: action, score: score,
            key: key, parent: frontier.currentParent)
        when L isnot void: candidate.leaf = self.getLeaf()
        self.moveBackward(action)
        frontier.selector.tourCommonPush(candidate, finished, group, true)

    # 葉の境界から経路の末尾を補い、指定した葉までのAction列を復元する。
    proc tourRestore[T, A](tree: TourTree[T, A], leaf: int): seq[A] =
        result = newSeq[A](tree.trace.len)
        result.tourCommonCopyRange(0, tree.trace, 0, tree.trace.len)
        var progress = 0
        for j in leaf..<tree.leaves.high:
            let rank = tree.leaves[j+1] - tree.leaves[j]
            if progress < rank:
                result.tourCommonCopyRange(result.len-rank, tree.tour, tree.leaves[j], rank-progress)
                progress = rank

    # 親の葉番号で計数整列し、候補全体のソートを避けて経路順の巡回位置を作る。
    proc tourOrder[T, A, S, K, L](tree: var TourTree[T, A],
            candidates: seq[TourCandidate[A, S, K, L]]) =
        tree.offsets.setLen(tree.leaves.len)
        for count in tree.offsets.mitems: count = 0
        for c in candidates: inc tree.offsets[c.parent]
        var total = 0
        for count in tree.offsets.mitems:
            let n = count
            count = total
            total += n
        tree.visitOrder.setLen(candidates.len)
        for i, c in candidates:
            tree.visitOrder[tree.offsets[c.parent]] = i
            inc tree.offsets[c.parent]

    # 共通祖先まで戻って別経路を適用し、採用候補だけを展開して次の経路配列を作る。
    proc tourExpand[T, A, S, K, L](tree: var TourTree[T, A],
            candidates: seq[TourCandidate[A, S, K, L]], frontier: var TourBeamFrontier[A, S, K, L]) =
        mixin moveForward, moveBackward, expand
        tree.tourOrder(candidates)
        let depth = tree.trace.len
        tree.trace.add(candidates[tree.visitOrder[^1]].action)
        tree.nextTour.setLen(tree.tour.len+candidates.len)
        tree.nextLeaves.setLen(candidates.len)
        var appended = 0
        var nextLeaf = 0
        tree.expandedLeaves.setLen(candidates.len)
        var previous = tree.leaves.high
        var applied = 0
        for pos in countdown(tree.visitOrder.high, 0):
            let slot = tree.visitOrder[pos]
            let parent = candidates[slot].parent
            var common = 0
            for j in parent..<previous:
                common = max(common, tree.leaves[j+1]-tree.leaves[j])
            for i in countdown(depth+applied-1, depth-common):
                tourCommonBoardBackward(tree.state, tree.trace[i])
            applied = 1
            tree.nextTour.tourCommonCopyRange(appended, tree.trace, depth-common, common+1)
            appended += common+1
            var progress = 0
            for j in parent..<previous:
                let rank = tree.leaves[j+1]-tree.leaves[j]
                if progress < rank:
                    tree.trace.tourCommonCopyRange(depth-rank, tree.tour, tree.leaves[j], rank-progress)
                    progress = rank
            tree.trace[depth] = candidates[slot].action
            for i in depth-common..depth: tourCommonBoardForward(tree.state, tree.trace[i])
            frontier.currentParent = nextLeaf
            tree.expandedLeaves[slot] = nextLeaf
            frontier.currentScore = candidates[slot].score
            frontier.currentHash = candidates[slot].key
            when L isnot void: frontier.currentLeaf = candidates[slot].leaf
            tourCommonLoadLeaf(tree.state, frontier, A)
            tree.state.expand(frontier)
            tree.nextLeaves[nextLeaf] = appended
            inc nextLeaf
            previous = parent
        tree.nextTour.setLen(appended)
        swap(tree.tour, tree.nextTour)
        swap(tree.leaves, tree.nextLeaves)

    # 1ターンずつ経路配列で探索し、終了時だけ最良の行動列を復元する。
    proc runTourBeam*[State, Action, Score, Key, Leaf](initial: State, beamWidth: int,
            maxTurns = 2000, minimize = true, groupLimit = 0,
            groupCount = 0, groupLocalHash = false): TourBeamResult[Action, Score] =
        mixin evaluate, expand, getHash, getLeaf
        when defined(debug):
            if maxTurns < 0: raise newException(ValueError, "maxTurns must be nonnegative")
        var frontier = initTourBeamFrontier[Action, Score, Key, Leaf](beamWidth, minimize, groupLimit, groupCount, groupLocalHash)
        var tree = TourTree[State, Action](state: initial, leaves: @[0])
        var current: seq[TourCandidate[Action, Score, Key, Leaf]]
        result.score = tree.state.evaluate()
        result.status = beamMaxTurns
        if tourCommonFinishedField(tree.state):
            result.status = beamFinished
            return
        for turn in 1..maxTurns:
            frontier.remaining = maxTurns-turn+1
            if turn == 1:
                frontier.currentScore = result.score
                frontier.currentHash = tree.state.getHash()
                when Leaf isnot void: frontier.currentLeaf = tree.state.getLeaf()
                tourCommonLoadLeaf(tree.state, frontier, Action)
                tree.state.expand(frontier)
            else:
                tree.tourExpand(current, frontier)
            let s = frontier.selector
            s.tourCommonSelectGroups()
            result.selectedCandidates += int64(s.candidates.len + ord(s.hasFinished))
            if s.hasFinished:
                result.score = s.finished.score
                result.actions = tree.tourRestore(s.finished.parent)
                result.actions.add(s.finished.action)
                result.turns = turn
                result.status = beamFinished
                return
            if s.candidates.len == 0:
                result.status = beamExhausted
                if current.len > 0:
                    let best = tourCommonBest(current, minimize)
                    result.score = current[best].score
                    result.actions = tree.tourRestore(tree.expandedLeaves[best])
                return
            result.turns = turn
            if turn == maxTurns:
                let best = tourCommonBest(s.candidates, minimize)
                result.score = s.candidates[best].score
                result.actions = tree.tourRestore(s.candidates[best].parent)
                result.actions.add(s.candidates[best].action)
                return
            swap(current, s.candidates)
            s.candidates.setLen(0)
            s.indices.clear()

    # 任意の葉情報を追加しない従来形式の評価値・Hashで探索する。
    template runTourBeam*[State, Action, Score, Key](initial: State, beamWidth: int,
            maxTurns = 2000, minimize = true, groupLimit = 0,
            groupCount = 0, groupLocalHash = false): TourBeamResult[Action, Score] =
        runTourBeam[State, Action, Score, Key, void](initial, beamWidth,
            maxTurns, minimize, groupLimit, groupCount, groupLocalHash)

    # State・Action・評価値・Hashの型を固定し、指定名の探索関数を定義する。
    template defineTourBeam*(name, State, Action, Score, Key: untyped, Leaf: untyped = void) =
        # 型を固定した1ターン遷移の探索条件をcoreへ渡す。
        template name(initial: State, beamWidth: int, maxTurns = 2000,
                minimize = true, groupLimit = 0, groupCount = 0, groupLocalHash = false): TourBeamResult[Action, Score] =
            runTourBeam[State, Action, Score, Key, Leaf](initial, beamWidth, maxTurns,
                minimize, groupLimit, groupCount, groupLocalHash)

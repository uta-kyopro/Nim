include ../header
import std/typetraits

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
        TourCandidate[Action, Score, Key] = object
            action: Action
            score: Score
            key: Key
            parent: int
        TourHashMap[Key] = object
            keys: seq[Key]
            values: seq[int]
            valid: seq[uint64]
            used: int
        TourSelector[Action, Score, Key] = ref object
            width, size: int
            minimize, hasFinished: bool
            candidates: seq[TourCandidate[Action, Score, Key]]
            indices: TourHashMap[Key]
            worst: seq[int]
            finished: TourCandidate[Action, Score, Key]
            groupLimit: int
            buckets: seq[seq[TourCandidate[Action, Score, Key]]]
        TourBeamFrontier*[Action, Score, Key] = object
            selector: TourSelector[Action, Score, Key]
            currentParent, remaining: int
        TourTree[State, Action] = object
            state: State
            # traceは現在位置までの経路、tourは葉の間で戻る経路の断片。
            trace, tour, nextTour: seq[Action]
            leaves, nextLeaves: seq[int]
            visitOrder, offsets, expandedLeaves: seq[int]

    # Stateに実在するboolフィールドだけを読み、旧判定関数形式は受け付けない。
    template tourFinishedField(state: typed): bool =
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

    # ビーム幅に応じた容量の重複除去用Hash表を確保する。
    proc initTourHashMap[K](width: int): TourHashMap[K] =
        var capacity = 16
        while capacity < width * 16: capacity *= 2
        result.keys = newSeq[K](capacity)
        result.values = newSeq[int](capacity)
        result.valid = newSeq[uint64]((capacity + 63) div 64)

    # 確保済みの配列を再利用し、Hash表の登録情報だけを消去する。
    proc clear[K](m: var TourHashMap[K]) =
        for word in m.valid.mitems: word = 0
        m.used = 0

    # キーを線形探索し、一致したスロットまたは登録先の空きスロットを返す。
    proc getIndex[K](m: TourHashMap[K], key: K): tuple[found: bool, slot: int] =
        let mask = m.keys.len - 1
        when K is SomeInteger:
            when K is SomeSignedInt:
                let bits = cast[uint64](int64(key))
            else:
                let bits = uint64(key)
            var i = int(bits and uint64(mask)) # 整数キーを再ハッシュしない。
        else:
            var i = int(hash(key)) and mask
        while (m.valid[i shr 6] and (1'u64 shl (i and 63))) != 0:
            if m.keys[i] == key: return (true, i)
            i = (i + 1) and mask
        (false, i)

    # 指定スロットにキーと候補インデックスを登録する。
    proc set[K](m: var TourHashMap[K], slot: int, key: K, value: int) =
        let bit = 1'u64 shl (slot and 63)
        if (m.valid[slot shr 6] and bit) == 0:
            m.valid[slot shr 6] = m.valid[slot shr 6] or bit
            inc m.used
        m.keys[slot] = key
        m.values[slot] = value

    # 採用中の候補だけでHash表を作り直し、追い出された候補のキーを除く。
    proc tourRebuildHash[A, S, K](s: TourSelector[A, S, K]) =
        s.indices.clear()
        for i, c in s.candidates:
            let (_, slot) = s.indices.getIndex(c.key)
            s.indices.set(slot, c.key, i)

    # 評価方向に従い、aがbより良いか判定する。
    template tourBetter[S](a, b: S, minimize: bool): bool =
        block:
            let first = a
            let second = b
            let isMinimum = minimize
            if isMinimum: first < second else: second < first

    # 有効な2候補のうち評価の悪いindexを返す（同点は左を優先）。
    template tourWorst[A, S, K](s: TourSelector[A, S, K], a, b: int): int =
        block:
            let selector = s
            let first = a
            let second = b
            if tourBetter(selector.candidates[first].score, selector.candidates[second].score,
                selector.minimize): second
            else: first

    # 幅到達時に一括構築し、余った葉は末尾候補を参照させて無効値チェックを省く。
    proc tourBuild[A, S, K](s: TourSelector[A, S, K]) =
        s.size = 1
        while s.size < s.width: s.size *= 2
        s.worst.setLen(s.size * 2)
        for i in 0..<s.width: s.worst[s.size+i] = i
        # 末尾候補だけの部分木は、候補の評価値が変わっても保持するindexが変わらない。
        for i in s.width..<s.size: s.worst[s.size+i] = s.width-1
        for i in countdown(s.size-1, 1):
            let left = i shl 1
            s.worst[i] = s.tourWorst(s.worst[left], s.worst[left or 1])

    # 指定候補の変更を反映し、セグ木の根まで最悪候補を更新する。
    proc tourUpdate[A, S, K](s: TourSelector[A, S, K], index: int) =
        var p = (s.size + index) shr 1
        while p > 0:
            let left = p shl 1
            s.worst[p] = s.tourWorst(s.worst[left], s.worst[left or 1])
            p = p shr 1

    # 1つの到達ターンへ候補を登録し、通常選抜・グループ保留・完了候補を処理する。
    proc tourPush[A, S, K](s: TourSelector[A, S, K],
        candidate: TourCandidate[A, S, K], finished: bool, group: int, scoreChecked: static[bool] = false): bool =
        if finished:
            if not s.hasFinished:
                s.hasFinished = true
                s.finished = candidate
                return true
            return false
        if s.groupLimit > 0:
            s.buckets[group].add(candidate)
            return true
        let full = s.candidates.len == s.width
        when not scoreChecked:
            if full and not tourBetter(candidate.score,
                s.candidates[s.worst[1]].score, s.minimize): return false
        if s.indices.used >= s.indices.keys.len * 7 div 10: s.tourRebuildHash()
        let (found, slot) = s.indices.getIndex(candidate.key)
        let old = if found: s.indices.values[slot] else: -1
        if old >= 0 and s.candidates[old].key == candidate.key:
            if not tourBetter(candidate.score, s.candidates[old].score, s.minimize): return false
            s.candidates[old] = candidate
            if full: s.tourUpdate(old)
        elif full:
            let index = s.worst[1]
            s.candidates[index] = candidate
            s.indices.set(slot, candidate.key, index)
            s.tourUpdate(index)
        else:
            s.indices.set(slot, candidate.key, s.candidates.len)
            s.candidates.add(candidate)
            if s.candidates.len == s.width: s.tourBuild()
        true

    # グループID順に重複を除去し、各グループの上位候補を確定する。
    proc tourSelectGroups[A, S, K](s: TourSelector[A, S, K]) =
        if s.groupLimit <= 0: return
        var seen = initHashSet[K](0)
        for bucket in s.buckets.mitems:
            # std/algorithm.sort is stable: equal scores retain registration order.
            let minimize = s.minimize
            bucket.sort(proc(a, b: TourCandidate[A, S, K]): int =
                if tourBetter(a.score, b.score, minimize): -1
                elif tourBetter(b.score, a.score, minimize): 1
                else: 0)
            var kept = 0
            for candidate in bucket:
                if candidate.key in seen: continue
                seen.incl(candidate.key)
                s.candidates.add(candidate)
                inc kept
                if kept == s.groupLimit: break
            bucket.setLen(0)


    # 次の1層の候補管理を初期化する。groupLimit > 0なら全体幅の代わりにグループ別選抜を使う。
    proc initTourBeamFrontier*[A, S, K](beamWidth: int, minimize = true,
            groupLimit = 0, groupCount = 0): TourBeamFrontier[A, S, K] =
        when defined(debug):
            if beamWidth <= 0: raise newException(ValueError, "beamWidth must be positive")
            if groupLimit < 0 or groupCount < 0 or (groupLimit > 0 and groupCount <= 0):
                raise newException(ValueError, "invalid group bucket dimensions")
        result.remaining = int.high
        result.selector = TourSelector[A, S, K](width: beamWidth, minimize: minimize,
            groupLimit: groupLimit,
            candidates: newSeqOfCap[TourCandidate[A, S, K]](if groupLimit > 0: 0 else: beamWidth))
        if groupLimit > 0:
            result.selector.buckets = newSeq[seq[TourCandidate[A, S, K]]](groupCount)
        else:
            result.selector.indices = initTourHashMap[K](beamWidth)

    # 現在の展開位置から探索上限までの残りターン数を返す。
    template remainingTurns*[A, S, K](frontier: TourBeamFrontier[A, S, K]): int =
        frontier.remaining

    # Hash取得前に足切りする。trueでも同じHashのより良い候補があれば不採用になる。
    proc canImprove*[A, S, K](frontier: TourBeamFrontier[A, S, K], score: S,
            finished = false, group = -1): bool =
        let s = frontier.selector
        when defined(debug):
            if s.groupLimit > 0 and (group < 0 or group >= s.buckets.len):
                raise newException(ValueError, "beam group out of range")
        if frontier.remaining <= 0: return false
        if finished: return not s.hasFinished
        s.groupLimit > 0 or s.candidates.len < s.width or
            tourBetter(score, s.candidates[s.worst[1]].score, s.minimize)

    # 評価済みの1ターン遷移を、展開中の親に自動で関連付けて登録する。
    proc push*[A, S, K](frontier: var TourBeamFrontier[A, S, K], action: A,
            score: S, key: K, finished = false, group = -1): bool {.discardable.} =
        if not frontier.canImprove(score, finished, group): return false
        frontier.selector.tourPush(TourCandidate[A, S, K](action: action, score: score,
            key: key, parent: frontier.currentParent), finished, group, true)

    # Actionを仮適用して評価・必要時のHash取得・巻き戻しを行い、候補を登録する。
    proc pushCandidate*[T, A, S, K](self: var T, frontier: var TourBeamFrontier[A, S, K],
            action: A, group = -1): bool {.discardable.} =
        mixin moveForward, moveBackward, evaluate, getHash
        if frontier.remaining <= 0: return false
        self.moveForward(action)
        let score = self.evaluate()
        let finished = tourFinishedField(self)
        if not frontier.canImprove(score, finished, group):
            self.moveBackward(action)
            return false
        let key = self.getHash()
        self.moveBackward(action)
        frontier.selector.tourPush(TourCandidate[A, S, K](action: action, score: score,
            key: key, parent: frontier.currentParent), finished, group, true)

    # 重ならない経路断片を一括コピーし、参照管理が必要なActionは通常代入する。
    proc tourCopyRange[A](dest: var seq[A], offset: int, source: seq[A], first, count: int) =
        if count <= 0: return
        when supportsCopyMem(A):
            copyMem(addr dest[offset], unsafeAddr source[first], count * sizeof(A))
        else:
            for i in 0..<count: dest[offset+i] = source[first+i]

    # 葉の境界から経路の末尾を補い、指定した葉までのAction列を復元する。
    proc tourRestore[T, A](tree: TourTree[T, A], leaf: int): seq[A] =
        result = newSeq[A](tree.trace.len)
        result.tourCopyRange(0, tree.trace, 0, tree.trace.len)
        var progress = 0
        for j in leaf..<tree.leaves.high:
            let rank = tree.leaves[j+1] - tree.leaves[j]
            if progress < rank:
                result.tourCopyRange(result.len-rank, tree.tour, tree.leaves[j], rank-progress)
                progress = rank

    # 親の葉番号で計数整列し、候補全体のソートを避けて経路順の巡回位置を作る。
    proc tourOrder[T, A, S, K](tree: var TourTree[T, A],
            candidates: seq[TourCandidate[A, S, K]]) =
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
    proc tourExpand[T, A, S, K](tree: var TourTree[T, A],
            candidates: seq[TourCandidate[A, S, K]], frontier: var TourBeamFrontier[A, S, K]) =
        mixin moveForward, moveBackward, expand
        tree.tourOrder(candidates)
        let depth = tree.trace.len
        tree.trace.add(candidates[tree.visitOrder[^1]].action)
        tree.nextTour.setLen(0)
        tree.nextLeaves.setLen(0)
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
                tree.state.moveBackward(tree.trace[i])
            applied = 1
            let appended = tree.nextTour.len
            tree.nextTour.setLen(appended+common+1)
            tree.nextTour.tourCopyRange(appended, tree.trace, depth-common, common+1)
            var progress = 0
            for j in parent..<previous:
                let rank = tree.leaves[j+1]-tree.leaves[j]
                if progress < rank:
                    tree.trace.tourCopyRange(depth-rank, tree.tour, tree.leaves[j], rank-progress)
                    progress = rank
            tree.trace[depth] = candidates[slot].action
            for i in depth-common..depth: tree.state.moveForward(tree.trace[i])
            frontier.currentParent = tree.nextLeaves.len
            tree.expandedLeaves[slot] = tree.nextLeaves.len
            tree.state.expand(frontier)
            tree.nextLeaves.add(tree.nextTour.len)
            previous = parent
        swap(tree.tour, tree.nextTour)
        swap(tree.leaves, tree.nextLeaves)

    # 候補配列を走査して最良スロットを返す。同点では小さいスロットを選ぶ。
    proc tourBest[A, S, K](candidates: seq[TourCandidate[A, S, K]], minimize: bool): int =
        for i in 1..<candidates.len:
            if tourBetter(candidates[i].score, candidates[result].score, minimize): result = i

    # 1ターンずつ経路配列で探索し、終了時だけ最良の行動列を復元する。
    proc runTourBeam*[State, Action, Score, Key](initial: State, beamWidth: int,
            maxTurns = 2000, minimize = true, groupLimit = 0,
            groupCount = 0): TourBeamResult[Action, Score] =
        mixin evaluate, expand
        when defined(debug):
            if maxTurns < 0: raise newException(ValueError, "maxTurns must be nonnegative")
        var frontier = initTourBeamFrontier[Action, Score, Key](beamWidth, minimize, groupLimit, groupCount)
        var tree = TourTree[State, Action](state: initial, leaves: @[0])
        var current: seq[TourCandidate[Action, Score, Key]]
        result.score = tree.state.evaluate()
        result.status = beamMaxTurns
        if tourFinishedField(tree.state):
            result.status = beamFinished
            return
        for turn in 1..maxTurns:
            frontier.remaining = maxTurns-turn+1
            if turn == 1:
                tree.state.expand(frontier)
            else:
                tree.tourExpand(current, frontier)
            let s = frontier.selector
            s.tourSelectGroups()
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
                    let best = tourBest(current, minimize)
                    result.score = current[best].score
                    result.actions = tree.tourRestore(tree.expandedLeaves[best])
                return
            result.turns = turn
            if turn == maxTurns:
                let best = tourBest(s.candidates, minimize)
                result.score = s.candidates[best].score
                result.actions = tree.tourRestore(s.candidates[best].parent)
                result.actions.add(s.candidates[best].action)
                return
            swap(current, s.candidates)
            s.candidates.setLen(0)
            s.indices.clear()

    # State・Action・評価値・Hashの型を固定し、指定名の探索関数を定義する。
    template defineTourBeam*(name, State, Action, Score, Key: untyped) =
        # 型を固定した1ターン遷移の探索条件をcoreへ渡す。
        template name(initial: State, beamWidth: int, maxTurns = 2000,
                minimize = true, groupLimit = 0, groupCount = 0): TourBeamResult[Action, Score] =
            runTourBeam[State, Action, Score, Key](initial, beamWidth, maxTurns,
                minimize, groupLimit, groupCount)

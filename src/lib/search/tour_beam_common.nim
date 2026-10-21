include ../header


# -------------------------------------------------------------------
# TourBeamCommonModule 1ターン遷移専用のビームサーチライブラリ(編集しない)
# -------------------------------------------------------------------
when not declared TourBeamCommonModule:
    const TourBeamCommonModule = true

    type
        TourCommonCandidate[Action, Score, Key, Leaf] = object
            action: Action
            score: Score
            key: Key
            parent: int
            when Leaf isnot void:
                leaf: Leaf
        TourCommonHashMap[Key] = object
            keys: seq[Key]
            values: seq[int]
            valid: seq[uint64]
            used: int
        # skipTourだけ遅延確保を使い、型と分岐はコンパイル時に確定する。
        TourCommonSelector[Action, Score, Key, Leaf; Lazy: static[bool]] = ref object
            width, size: int
            minimize, hasFinished: bool
            candidates: seq[TourCommonCandidate[Action, Score, Key, Leaf]]
            indices: TourCommonHashMap[Key]
            worst: seq[int]
            packed: seq[uint64]
            finished: TourCommonCandidate[Action, Score, Key, Leaf]
            groupLimit: int
            groupLocalHash: bool
            groups: seq[TourCommonSelector[Action, Score, Key, Leaf, Lazy]]
            orders: seq[int] # 群内の同点順序。通常選抜では使わない。
            nextOrder: int
            groupCount: int
            buckets: seq[seq[TourCommonCandidate[Action, Score, Key, Leaf]]]

    # 盤面専用フックがあれば使い、省略時は通常の適用処理を使う。
    template tourCommonBoardForward(state, action: untyped) =
        mixin moveBoardForward, moveForward
        when compiles(state.moveBoardForward(action)):
            when not compiles(state.moveBoardBackward(action)):
                {.error: "board-only transitions require both forward and backward hooks".}
            state.moveBoardForward(action)
        else:
            state.moveForward(action)

    # 盤面専用フックがあれば使い、省略時は通常の巻き戻し処理を使う。
    template tourCommonBoardBackward(state, action: untyped) =
        mixin moveBoardBackward, moveBackward
        when compiles(state.moveBoardBackward(action)):
            when not compiles(state.moveBoardForward(action)):
                {.error: "board-only transitions require both forward and backward hooks".}
            state.moveBoardBackward(action)
        else:
            state.moveBackward(action)

    # 任意の葉情報、または従来の評価値・Hashを展開直前に復元する。
    template tourCommonLoadLeaf(state, frontier, ActionType: untyped) =
        mixin loadLeaf, moveBoardForward, moveBoardBackward
        when compiles(frontier.currentLeaf):
            when compiles(state.loadLeaf(frontier.currentLeaf)):
                state.loadLeaf(frontier.currentLeaf)
            elif compiles(state.moveBoardForward(default(ActionType))) or
                    compiles(state.moveBoardBackward(default(ActionType))):
                {.error: "board-only transitions require loadLeaf(state, leaf)".}
        else:
            when compiles(state.loadLeaf(frontier.currentScore, frontier.currentHash)):
                state.loadLeaf(frontier.currentScore, frontier.currentHash)
            elif compiles(state.moveBoardForward(default(ActionType))) or
                    compiles(state.moveBoardBackward(default(ActionType))):
                {.error: "board-only transitions require loadLeaf".}

    # Stateに実在するboolフィールドだけを読み、旧判定関数形式は受け付けない。
    template tourCommonFinishedField(state: typed): bool =
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
    proc initTourCommonHashMap[K](width: int): TourCommonHashMap[K] =
        var capacity = 16
        while capacity < width * 16: capacity *= 2
        result.keys = newSeq[K](capacity)
        result.values = newSeq[int](capacity)
        result.valid = newSeq[uint64]((capacity + 63) div 64)

    # 確保済みの配列を再利用し、Hash表の登録情報だけを消去する。
    proc clear[K](m: var TourCommonHashMap[K]) =
        m.valid.fill(0'u64)
        m.used = 0

    # uint64のHashを再ハッシュせず線形探索し、一致または空きスロットを返す。
    proc getIndex[K](m: TourCommonHashMap[K], key: K): tuple[found: bool, slot: int] =
        let mask = m.keys.len - 1
        var i = cast[int](cast[uint64](key) and cast[uint64](mask))
        while (m.valid[i shr 6] and (1'u64 shl (i and 63))) != 0:
            if m.keys[i] == key: return (true, i)
            i = (i + 1) and mask
        (false, i)

    # 指定スロットにキーと候補インデックスを登録する。
    proc set[K](m: var TourCommonHashMap[K], slot: int, key: K, value: int) =
        let bit = 1'u64 shl (slot and 63)
        if (m.valid[slot shr 6] and bit) == 0:
            m.valid[slot shr 6] = m.valid[slot shr 6] or bit
            inc m.used
        m.keys[slot] = key
        m.values[slot] = value

    # 採用中の候補だけでHash表を作り直し、追い出された候補のキーを除く。
    proc tourCommonRebuildHash[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy]) =
        s.indices.clear()
        for i, c in s.candidates:
            let (_, slot) = s.indices.getIndex(c.key)
            s.indices.set(slot, c.key, i)

    # 評価方向に従い、aがbより良いか判定する。
    template tourCommonBetter[S](a, b: S, minimize: bool): bool =
        block:
            let first = a
            let second = b
            let isMinimum = minimize
            if isMinimum: first < second else: second < first

    # 有効な2候補のうち評価の悪いindexを返す（同点は左を優先）。
    template tourCommonWorst[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy], a, b: int, ordered: static[bool] = false): int =
        block:
            let selector = s
            let first = a
            let second = b
            if tourCommonBetter(selector.candidates[first].score, selector.candidates[second].score,
                selector.minimize): second
            else:
                when ordered:
                    if not tourCommonBetter(selector.candidates[second].score,
                            selector.candidates[first].score, selector.minimize) and
                            selector.orders[first] < selector.orders[second]: second
                    else: first
                else: first

    # 連続領域として渡し、葉番号の初期化をコンパイラがSIMD化できるようにする。
    proc tourCommonInitLeaves(values: var openArray[int], width: int) =
        for i in 0..<width: values[i] = i
        # 末尾候補だけの部分木は、評価値が変わっても保持するindexが変わらない。
        values.fill(width, values.high, width-1)

    const
        TourPackedScoreMin = -(1'i64 shl 47)
        TourPackedScoreMax = (1'i64 shl 47)-1
        TourPackedMaxWidth = 1 shl 16
        TourPackedIndexMask = (1'u64 shl 16)-1

    # 選抜へ渡す整数スコアの48bit契約をdebug時だけ確認し、releaseには判定を残さない。
    template tourCommonCheckScore(score: typed) =
        when defined(debug):
            when typeof(score) is SomeSignedInt:
                let value = int64(score)
                doAssert value >= TourPackedScoreMin and value <= TourPackedScoreMax,
                    "beam score must fit signed 48 bits"

    # 上位48bitは悪さ、下位16bitは小さい候補番号を優先する順位。幅は最大65,536。
    template tourPackedValue(score, index, minimize: typed): uint64 =
        block:
            let value = int64(score)
            tourCommonCheckScore(value)
            const scoreMask = (1'u64 shl 48)-1
            var rank = (cast[uint64](value) and scoreMask) xor (1'u64 shl 47)
            if not minimize: rank = rank xor scoreMask
            (rank shl 16) or (TourPackedIndexMask - uint64(index))

    # 根に保存したパック値から最悪候補の番号だけを取り出す。
    template tourPackedSlot(value: uint64): int =
        int(TourPackedIndexMask - (value and TourPackedIndexMask))

    # 1点を書き換え、候補配列へ戻らず左右のパック値だけを比較する。
    proc tourPackedUpdate(values: var openArray[uint64], size, index: int,
            value: uint64, duplicate: static[bool]) =
        var p = size + index
        values[p] = value
        p = p shr 1
        while p > 0:
            when duplicate:
                if (values[p] and TourPackedIndexMask) != TourPackedIndexMask - uint64(index): break
            let left = p shl 1
            values[p] = max(values[left], values[left or 1])
            p = p shr 1

    # 幅到達時に一括構築する。小幅では呼出し負担が勝ち、全体への効果は構築の割合による。
    proc tourCommonBuild[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy], ordered: static[bool] = false) =
        s.size = 1
        while s.size < s.width: s.size *= 2
        when not ordered and S is SomeSignedInt:
            when defined(debug): doAssert s.width <= TourPackedMaxWidth
            s.packed.setLen(s.size * 2)
            for i, candidate in s.candidates:
                s.packed[s.size+i] = tourPackedValue(candidate.score, i, s.minimize)
            for i in s.size+s.width..<s.packed.len: s.packed[i] = 0
            for i in countdown(s.size-1, 1):
                let left = i shl 1
                s.packed[i] = max(s.packed[left], s.packed[left or 1])
            s.worst.setLen(2)
            s.worst[1] = tourPackedSlot(s.packed[1])
            return
        s.worst.setLen(s.size * 2)
        tourCommonInitLeaves(s.worst.toOpenArray(s.size, s.worst.high), s.width)
        for i in countdown(s.size-1, 1):
            let left = i shl 1
            s.worst[i] = s.tourCommonWorst(s.worst[left], s.worst[left or 1], ordered)

    # 配列を借用して更新し、各段でのselectorの参照管理とフィールド再取得を省く。
    proc tourCommonUpdatePath[A, S, K, L](worst: var openArray[int],
            candidates: openArray[TourCommonCandidate[A, S, K, L]],
            size, index: int, minimize: bool, duplicate: static[bool],
            orders: openArray[int], ordered: static[bool]) =
        var p = (size+index) shr 1
        while p > 0:
            when duplicate:
                if worst[p] != index: break
            let left = p shl 1
            let first = worst[left]
            let second = worst[left or 1]
            # 0/-1のマスクで勝者を選び、同点の左優先を保ったまま評価値による分岐を避ける。
            var secondWins = tourCommonBetter(candidates[first].score, candidates[second].score, minimize)
            when ordered:
                if not secondWins and not tourCommonBetter(candidates[second].score, candidates[first].score, minimize):
                    secondWins = orders[first] < orders[second]
            let chooseSecond = -ord(secondWins)
            worst[p] = first xor ((first xor second) and chooseSecond)
            p = p shr 1

    # 指定候補の変更を反映し、セグ木の根まで最悪候補を更新する。
    proc tourCommonUpdate[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy], index: int, ordered: static[bool] = false) =
        when not ordered and S is SomeSignedInt:
            tourPackedUpdate(s.packed, s.size, index,
                tourPackedValue(s.candidates[index].score, index, s.minimize), false)
            s.worst[1] = tourPackedSlot(s.packed[1])
            return
        tourCommonUpdatePath(s.worst, s.candidates, s.size, index, s.minimize, false, s.orders, ordered)

    # 同一キーの改善は、変更スロットが更新前の最悪でなくなった階層から上を省く。
    proc tourCommonImproveDuplicate[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy], index: int, ordered: static[bool] = false) =
        when not ordered and S is SomeSignedInt:
            tourPackedUpdate(s.packed, s.size, index,
                tourPackedValue(s.candidates[index].score, index, s.minimize), true)
            s.worst[1] = tourPackedSlot(s.packed[1])
            return
        tourCommonUpdatePath(s.worst, s.candidates, s.size, index, s.minimize, true, s.orders, ordered)

    # 同じHashが群を跨がない場合、群内K件の最悪評価値で足切りする。
    template tourCommonGroupCanImprove(s, score, group: untyped): bool =
        block:
            let selector = s
            if not selector.groupLocalHash or selector.groups.len == 0 or selector.groups[group] == nil: true
            else:
                let child = selector.groups[group]
                child.candidates.len < child.width or
                    tourCommonBetter(score, child.candidates[child.worst[1]].score, child.minimize)

    # 1つの到達ターンへ候補を登録し、通常選抜・グループ保留・完了候補を処理する。
    proc tourCommonPush[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy],
        candidate: TourCommonCandidate[A, S, K, L], finished: bool, group: int, scoreChecked: static[bool] = false, ordered: static[bool] = false): bool =
        tourCommonCheckScore(candidate.score)
        if finished:
            if not s.hasFinished:
                s.hasFinished = true
                s.finished = candidate
                return true
            return false
        if s.groupLimit > 0:
            if s.groupLocalHash:
                if s.groups.len == 0: s.groups.setLen(s.groupCount)
                if s.groups[group] == nil:
                    s.groups[group] = TourCommonSelector[A, S, K, L, Lazy](width: s.groupLimit,
                        minimize: s.minimize, indices: initTourCommonHashMap[K](s.groupLimit),
                        candidates: newSeqOfCap[TourCommonCandidate[A, S, K, L]](s.groupLimit),
                        orders: newSeqOfCap[int](s.groupLimit))
                return s.groups[group].tourCommonPush(candidate, false, -1, false, true)
            when Lazy:
                if s.buckets.len == 0: s.buckets.setLen(s.groupCount)
            s.buckets[group].add(candidate)
            return true
        when Lazy:
            if s.indices.keys.len == 0:
                s.indices = initTourCommonHashMap[K](s.width)
                s.candidates = newSeqOfCap[TourCommonCandidate[A, S, K, L]](s.width)
        let full = s.candidates.len == s.width
        when not scoreChecked:
            if full and not tourCommonBetter(candidate.score,
                s.candidates[s.worst[1]].score, s.minimize): return false
        if s.indices.used >= s.indices.keys.len * 7 div 10: s.tourCommonRebuildHash()
        let (found, slot) = s.indices.getIndex(candidate.key)
        let old = if found: s.indices.values[slot] else: -1
        if old >= 0 and s.candidates[old].key == candidate.key:
            if not tourCommonBetter(candidate.score, s.candidates[old].score, s.minimize): return false
            s.candidates[old] = candidate
            when ordered:
                s.orders[old] = s.nextOrder
                inc s.nextOrder
            if full: s.tourCommonImproveDuplicate(old, ordered)
        elif full:
            let index = s.worst[1]
            s.candidates[index] = candidate
            when ordered:
                s.orders[index] = s.nextOrder
                inc s.nextOrder
            s.indices.set(slot, candidate.key, index)
            s.tourCommonUpdate(index, ordered)
        else:
            s.indices.set(slot, candidate.key, s.candidates.len)
            s.candidates.add(candidate)
            when ordered:
                s.orders.add(s.nextOrder)
                inc s.nextOrder
            if s.candidates.len == s.width: s.tourCommonBuild(ordered)
        true

    # グループID順に重複を除去し、各グループの上位候補を確定する。
    proc tourCommonSelectGroups[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy]) =
        if s.groupLimit <= 0: return
        if s.groupLocalHash:
            for group in 0..<s.groups.len:
                let child = s.groups[group]
                if child == nil: continue
                var order = newSeq[int](child.candidates.len)
                for i in 0..<order.len: order[i] = i
                order.sort(proc(a, b: int): int =
                    if tourCommonBetter(child.candidates[a].score, child.candidates[b].score, s.minimize): -1
                    elif tourCommonBetter(child.candidates[b].score, child.candidates[a].score, s.minimize): 1
                    else: cmp(child.orders[a], child.orders[b]))
                for i in order: s.candidates.add(child.candidates[i])
                child.candidates.setLen(0)
                child.orders.setLen(0)
                child.indices.clear()
                child.nextOrder = 0
            return
        var bound = 0
        for bucket in s.buckets: bound += min(bucket.len, s.groupLimit)
        # 採用数の上限に対して2倍以上の容量を確保し、以降は使用済みビットだけ消す。
        if (s.indices.keys.len shr 1) < bound:
            s.indices = initTourCommonHashMap[K]((bound + 7) shr 3)
        else:
            s.indices.clear()
        for bucket in s.buckets.mitems:
            # std/algorithm.sort is stable: equal scores retain registration order.
            let minimize = s.minimize
            bucket.sort(proc(a, b: TourCommonCandidate[A, S, K, L]): int =
                if tourCommonBetter(a.score, b.score, minimize): -1
                elif tourCommonBetter(b.score, a.score, minimize): 1
                else: 0)
            var kept = 0
            for candidate in bucket:
                let (found, slot) = s.indices.getIndex(candidate.key)
                if found: continue
                s.indices.set(slot, candidate.key, s.candidates.len)
                s.candidates.add(candidate)
                inc kept
                if kept == s.groupLimit: break
            bucket.setLen(0)

    # 重ならない経路断片を一括コピーし、参照管理が必要なActionは通常代入する。
    proc tourCommonCopyRange[A](dest: var seq[A], offset: int, source: seq[A], first, count: int) =
        if count <= 0: return
        when supportsCopyMem(A):
            copyMem(addr dest[offset], unsafeAddr source[first], count * sizeof(A))
        else:
            for i in 0..<count: dest[offset+i] = source[first+i]

    # 候補配列を走査して最良スロットを返す。同点では小さいスロットを選ぶ。
    proc tourCommonBest[A, S, K, L](candidates: seq[TourCommonCandidate[A, S, K, L]], minimize: bool): int =
        for i in 1..<candidates.len:
            if tourCommonBetter(candidates[i].score, candidates[result].score, minimize): result = i

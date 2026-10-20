import std/typetraits

# 両coreがheader.nimの後にincludeする、非公開の共通型・選抜器・巡回補助処理。
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
            finished: TourCommonCandidate[Action, Score, Key, Leaf]
            groupLimit: int
            when Lazy:
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
    template tourCommonWorst[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy], a, b: int): int =
        block:
            let selector = s
            let first = a
            let second = b
            if tourCommonBetter(selector.candidates[first].score, selector.candidates[second].score,
                selector.minimize): second
            else: first

    # 連続領域として渡し、葉番号の初期化をコンパイラがSIMD化できるようにする。
    proc tourCommonInitLeaves(values: var openArray[int], width: int) =
        for i in 0..<width: values[i] = i
        # 末尾候補だけの部分木は、評価値が変わっても保持するindexが変わらない。
        values.fill(width, values.high, width-1)

    # 幅到達時に一括構築する。小幅では呼出し負担が勝ち、全体への効果は構築の割合による。
    proc tourCommonBuild[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy]) =
        s.size = 1
        while s.size < s.width: s.size *= 2
        s.worst.setLen(s.size * 2)
        tourCommonInitLeaves(s.worst.toOpenArray(s.size, s.worst.high), s.width)
        for i in countdown(s.size-1, 1):
            let left = i shl 1
            s.worst[i] = s.tourCommonWorst(s.worst[left], s.worst[left or 1])

    # 配列を借用して更新し、各段でのselectorの参照管理とフィールド再取得を省く。
    proc tourCommonUpdatePath[A, S, K, L](worst: var openArray[int],
            candidates: openArray[TourCommonCandidate[A, S, K, L]],
            size, index: int, minimize: bool, duplicate: static[bool]) =
        var p = (size+index) shr 1
        while p > 0:
            when duplicate:
                if worst[p] != index: break
            let left = p shl 1
            let first = worst[left]
            let second = worst[left or 1]
            # 0/-1のマスクで勝者を選び、同点の左優先を保ったまま評価値による分岐を避ける。
            let chooseSecond = -ord(tourCommonBetter(candidates[first].score, candidates[second].score, minimize))
            worst[p] = first xor ((first xor second) and chooseSecond)
            p = p shr 1

    # 指定候補の変更を反映し、セグ木の根まで最悪候補を更新する。
    proc tourCommonUpdate[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy], index: int) =
        tourCommonUpdatePath(s.worst, s.candidates, s.size, index, s.minimize, false)

    # 同一キーの改善は、変更スロットが更新前の最悪でなくなった階層から上を省く。
    proc tourCommonImproveDuplicate[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy], index: int) =
        tourCommonUpdatePath(s.worst, s.candidates, s.size, index, s.minimize, true)

    # 1つの到達ターンへ候補を登録し、通常選抜・グループ保留・完了候補を処理する。
    proc tourCommonPush[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy],
        candidate: TourCommonCandidate[A, S, K, L], finished: bool, group: int, scoreChecked: static[bool] = false): bool =
        if finished:
            if not s.hasFinished:
                s.hasFinished = true
                s.finished = candidate
                return true
            return false
        if s.groupLimit > 0:
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
            if full: s.tourCommonImproveDuplicate(old)
        elif full:
            let index = s.worst[1]
            s.candidates[index] = candidate
            s.indices.set(slot, candidate.key, index)
            s.tourCommonUpdate(index)
        else:
            s.indices.set(slot, candidate.key, s.candidates.len)
            s.candidates.add(candidate)
            if s.candidates.len == s.width: s.tourCommonBuild()
        true

    # グループID順に重複を除去し、各グループの上位候補を確定する。
    proc tourCommonSelectGroups[A, S, K, L; Lazy: static[bool]](s: TourCommonSelector[A, S, K, L, Lazy]) =
        if s.groupLimit <= 0: return
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

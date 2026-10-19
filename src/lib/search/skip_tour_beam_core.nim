include ../header
import std/typetraits

## オイラーツアー配列で経路を保持する世代スキップ対応ビームサーチ。
## Stateは1つだけ保持し、候補ごとのコピーや親・兄弟リンクは使わない。
when not declared SkipTourBeamCoreModule:
    const SkipTourBeamCoreModule* = true

    # 盤面専用フックがあれば使い、省略時は通常の適用処理を使う。
    template skipTourBoardForward(state, action: untyped) =
        mixin moveBoardForward, moveForward
        when compiles(state.moveBoardForward(action)):
            when not compiles(state.moveBoardBackward(action)):
                {.error: "board-only transitions require both forward and backward hooks".}
            state.moveBoardForward(action)
        else:
            state.moveForward(action)

    # 盤面専用フックがあれば使い、省略時は通常の巻き戻し処理を使う。
    template skipTourBoardBackward(state, action: untyped) =
        mixin moveBoardBackward, moveBackward
        when compiles(state.moveBoardBackward(action)):
            when not compiles(state.moveBoardForward(action)):
                {.error: "board-only transitions require both forward and backward hooks".}
            state.moveBoardBackward(action)
        else:
            state.moveBackward(action)

    # 展開直前に葉の生値を復元する。盤面専用フックを使う場合はloadLeafも実装する。
    template skipTourLoadLeaf(state, leafScore, leafKey, ActionType: untyped) =
        mixin loadLeaf, moveBoardForward, moveBoardBackward
        when compiles(state.loadLeaf(leafScore, leafKey)):
            state.loadLeaf(leafScore, leafKey)
        elif compiles(state.moveBoardForward(default(ActionType))) or
                compiles(state.moveBoardBackward(default(ActionType))):
            {.error: "board-only transitions require loadLeaf".}

    type
        SkipTourBeamStatus* = enum
            beamFinished, beamMaxTurns, beamExhausted
        SkipTourBeamResult*[Action, Score] = object
            score*: Score
            actions*: seq[Action]
            turns*: int
            status*: SkipTourBeamStatus
            selectedCandidates*: int64
        SkipTourCandidate[Action, Score, Key] = object
            action: Action
            score: Score
            key: Key
            parent: int
        SkipTourHashMap[Key] = object
            keys: seq[Key]
            values: seq[int]
            valid: seq[uint64]
            used: int
        SkipTourSelector[Action, Score, Key] = ref object
            width, size: int
            minimize, hasFinished: bool
            candidates: seq[SkipTourCandidate[Action, Score, Key]]
            indices: SkipTourHashMap[Key]
            worst: seq[int]
            finished: SkipTourCandidate[Action, Score, Key]
            groupLimit, groupCount: int
            buckets: seq[seq[SkipTourCandidate[Action, Score, Key]]]
        SkipTourBeamFrontier*[Action, Score, Key] = object
            currentScore*: Score # 展開中の葉に保存されていた評価値。
            currentHash*: Key # 展開中の葉に保存されていたHash。
            selectors: Deque[SkipTourSelector[Action, Score, Key]]
            width, groupLimit, groupCount, currentParent, remaining: int
            minimize: bool
        SkipTourTree[State, Action] = object
            state: State
            prefix, actions, nextActions: seq[Action]
            # 現在地の位置。非負は辺番号、-1は削除済み、-深さ-2は確定接頭辞。
            traceIds: seq[int]
            trace: seq[Action]
            events, nextEvents, filtered: seq[int]
            needed, direct: seq[bool]
            stack, remap, head, next: seq[int]
            saved: int
            confirmedPrefix: int # Stateと履歴IDの一致を確認済みの確定接頭辞長。
            actionCount, eventCount: int

    # Stateに実在するboolフィールドだけを読み、旧判定関数形式は受け付けない。
    template skipTourFinishedField(state: typed): bool =
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
    proc initSkipTourHashMap[K](width: int): SkipTourHashMap[K] =
        var capacity = 16
        while capacity < width * 16: capacity *= 2
        result.keys = newSeq[K](capacity)
        result.values = newSeq[int](capacity)
        result.valid = newSeq[uint64]((capacity + 63) div 64)

    # 確保済みの配列を再利用し、Hash表の登録情報だけを消去する。
    proc clear[K](m: var SkipTourHashMap[K]) =
        for word in m.valid.mitems: word = 0
        m.used = 0

    # キーを線形探索し、一致したスロットまたは登録先の空きスロットを返す。
    proc getIndex[K](m: SkipTourHashMap[K], key: K): tuple[found: bool, slot: int] =
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
    proc set[K](m: var SkipTourHashMap[K], slot: int, key: K, value: int) =
        let bit = 1'u64 shl (slot and 63)
        if (m.valid[slot shr 6] and bit) == 0:
            m.valid[slot shr 6] = m.valid[slot shr 6] or bit
            inc m.used
        m.keys[slot] = key
        m.values[slot] = value

    # 採用中の候補だけでHash表を作り直し、追い出された候補のキーを除く。
    proc skipTourRebuildHash[A, S, K](s: SkipTourSelector[A, S, K]) =
        s.indices.clear()
        for i, c in s.candidates:
            let (_, slot) = s.indices.getIndex(c.key)
            s.indices.set(slot, c.key, i)

    # 評価方向に従い、aがbより良いか判定する。
    template skipTourBetter[S](a, b: S, minimize: bool): bool =
        block:
            let first = a
            let second = b
            let isMinimum = minimize
            if isMinimum: first < second else: second < first

    # 有効な2候補のうち評価の悪いindexを返す（同点は左を優先）。
    template skipTourWorst[A, S, K](s: SkipTourSelector[A, S, K], a, b: int): int =
        block:
            let selector = s
            let first = a
            let second = b
            if skipTourBetter(selector.candidates[first].score, selector.candidates[second].score,
                selector.minimize): second
            else: first

    # 幅到達時に一括構築し、余った葉は末尾候補を参照させて無効値チェックを省く。
    proc skipTourBuild[A, S, K](s: SkipTourSelector[A, S, K]) =
        s.size = 1
        while s.size < s.width: s.size *= 2
        s.worst.setLen(s.size * 2)
        for i in 0..<s.width: s.worst[s.size+i] = i
        # 末尾候補だけの部分木は、候補の評価値が変わっても保持するindexが変わらない。
        for i in s.width..<s.size: s.worst[s.size+i] = s.width-1
        for i in countdown(s.size-1, 1):
            let left = i shl 1
            s.worst[i] = s.skipTourWorst(s.worst[left], s.worst[left or 1])

    # 指定候補の変更を反映し、セグ木の根まで最悪候補を更新する。
    proc skipTourUpdate[A, S, K](s: SkipTourSelector[A, S, K], index: int) =
        var p = (s.size + index) shr 1
        while p > 0:
            let left = p shl 1
            s.worst[p] = s.skipTourWorst(s.worst[left], s.worst[left or 1])
            p = p shr 1

    # 同一キーの改善は、変更スロットが更新前の最悪でなくなった階層から上を省く。
    proc skipTourImproveDuplicate[A, S, K](s: SkipTourSelector[A, S, K], index: int) =
        var p = (s.size+index) shr 1
        while p > 0:
            if s.worst[p] != index: break
            let left = p shl 1
            s.worst[p] = s.skipTourWorst(s.worst[left], s.worst[left or 1])
            p = p shr 1

    # 1つの到達ターンへ候補を登録し、通常選抜・グループ保留・完了候補を処理する。
    proc skipTourPush[A, S, K](s: SkipTourSelector[A, S, K],
        candidate: SkipTourCandidate[A, S, K], finished: bool, group: int, scoreChecked: static[bool] = false): bool =
        if finished:
            if not s.hasFinished:
                s.hasFinished = true
                s.finished = candidate
                return true
            return false
        if s.groupLimit > 0:
            if s.buckets.len == 0: s.buckets.setLen(s.groupCount)
            s.buckets[group].add(candidate)
            return true
        if s.indices.keys.len == 0:
            s.indices = initSkipTourHashMap[K](s.width)
            s.candidates = newSeqOfCap[SkipTourCandidate[A, S, K]](s.width)
        let full = s.candidates.len == s.width
        when not scoreChecked:
            if full and not skipTourBetter(candidate.score,
                s.candidates[s.worst[1]].score, s.minimize): return false
        if s.indices.used >= s.indices.keys.len * 7 div 10: s.skipTourRebuildHash()
        let (found, slot) = s.indices.getIndex(candidate.key)
        let old = if found: s.indices.values[slot] else: -1
        if old >= 0 and s.candidates[old].key == candidate.key:
            if not skipTourBetter(candidate.score, s.candidates[old].score, s.minimize): return false
            s.candidates[old] = candidate
            if full: s.skipTourImproveDuplicate(old)
        elif full:
            let index = s.worst[1]
            s.candidates[index] = candidate
            s.indices.set(slot, candidate.key, index)
            s.skipTourUpdate(index)
        else:
            s.indices.set(slot, candidate.key, s.candidates.len)
            s.candidates.add(candidate)
            if s.candidates.len == s.width: s.skipTourBuild()
        true

    # グループID順に重複を除去し、各グループの上位候補を確定する。
    proc skipTourSelectGroups[A, S, K](s: SkipTourSelector[A, S, K]) =
        if s.groupLimit <= 0: return
        var seen = initHashSet[K](0)
        for bucket in s.buckets.mitems:
            # std/algorithm.sort is stable: equal scores retain registration order.
            let minimize = s.minimize
            bucket.sort(proc(a, b: SkipTourCandidate[A, S, K]): int =
                if skipTourBetter(a.score, b.score, minimize): -1
                elif skipTourBetter(b.score, a.score, minimize): 1
                else: 0)
            var kept = 0
            for candidate in bucket:
                if candidate.key in seen: continue
                seen.incl(candidate.key)
                s.candidates.add(candidate)
                inc kept
                if kept == s.groupLimit: break
            bucket.setLen(0)


    # 到達世代ごとの選抜器を作る。確保した領域は世代を進めても再利用する。
    proc skipTourSelector[A, S, K](f: SkipTourBeamFrontier[A, S, K]): SkipTourSelector[A, S, K] =
        result = SkipTourSelector[A, S, K](width: f.width, minimize: f.minimize,
            groupLimit: f.groupLimit, groupCount: f.groupCount)

    # 固定幅と到達世代別の候補管理を初期化する。
    proc initSkipTourBeamFrontier*[A, S, K](beamWidth: int, minimize = true,
            groupLimit = 0, groupCount = 0): SkipTourBeamFrontier[A, S, K] =
        when defined(debug):
            if beamWidth <= 0: raise newException(ValueError, "beamWidth must be positive")
            if groupLimit < 0 or groupCount < 0 or (groupLimit > 0 and groupCount <= 0):
                raise newException(ValueError, "invalid group bucket dimensions")
        result.width = beamWidth
        result.minimize = minimize
        result.groupLimit = groupLimit
        result.groupCount = groupCount
        result.remaining = int.high
        result.currentParent = -1

    # 現在位置から探索上限までの残り世代数を返す。
    template remainingTurns*[A, S, K](frontier: SkipTourBeamFrontier[A, S, K]): int =
        frontier.remaining

    # 世代とグループを検証し、Hash取得前に候補を足切りする。
    proc canImprove*[A, S, K](frontier: SkipTourBeamFrontier[A, S, K], score: S,
            step = 1, finished = false, group = -1): bool =
        when defined(debug):
            if step <= 0: raise newException(ValueError, "beam step must be positive")
            if frontier.groupLimit > 0 and (group < 0 or group >= frontier.groupCount):
                raise newException(ValueError, "beam group out of range")
        if step > frontier.remaining: return false
        if step > frontier.selectors.len: return true
        let s = frontier.selectors[step-1]
        if finished: return not s.hasFinished
        s.groupLimit > 0 or s.candidates.len < s.width or
            skipTourBetter(score, s.candidates[s.worst[1]].score, s.minimize)

    # 選抜済みの評価値と現在の親を指定step先へ登録する。
    proc skipTourRegister[A, S, K](f: var SkipTourBeamFrontier[A, S, K], action: A,
            score: S, key: K, step: int, finished: bool, group: int): bool =
        while f.selectors.len < step: f.selectors.addLast(f.skipTourSelector())
        f.selectors[step-1].skipTourPush(SkipTourCandidate[A, S, K](
            action: action, score: score, key: key, parent: f.currentParent), finished, group, true)

    # 評価済み候補を、展開中の親から指定step先へ登録する。
    proc push*[A, S, K](frontier: var SkipTourBeamFrontier[A, S, K], action: A,
            score: S, key: K, finished = false, step = 1, group = -1): bool {.discardable.} =
        if not frontier.canImprove(score, step, finished, group): return false
        frontier.skipTourRegister(action, score, key, step, finished, group)

    # 仮適用・評価・必要時のHash取得・巻き戻し後、指定step先へ候補を登録する。
    proc pushCandidate*[T, A, S, K](self: var T, frontier: var SkipTourBeamFrontier[A, S, K],
            action: A, step = 1, group = -1): bool {.discardable.} =
        mixin moveForward, moveBackward, evaluate, getHash, moveBoardForward, moveBoardBackward, loadLeaf
        when defined(debug):
            if step <= 0: raise newException(ValueError, "beam step must be positive")
        if step > frontier.remaining: return false
        self.moveForward(action)
        let score = self.evaluate()
        let finished = skipTourFinishedField(self)
        if not frontier.canImprove(score, step, finished, group):
            self.moveBackward(action)
            return false
        let key = self.getHash()
        self.moveBackward(action)
        frontier.skipTourRegister(action, score, key, step, finished, group)

    # 重ならないAction区間を一括コピーし、参照管理が必要な型は通常代入する。
    proc skipTourCopyRange[A](dest: var seq[A], offset: int, source: seq[A], first, count: int) =
        if count <= 0: return
        when supportsCopyMem(A):
            copyMem(addr dest[offset], unsafeAddr source[first], count*sizeof(A))
        else:
            for i in 0..<count: dest[offset+i] = source[first+i]

    # 共通接頭辞とツアー中のスタックから、指定した親までのAction列を復元する。
    proc skipTourPath[T, A](tree: SkipTourTree[T, A], parent: int): seq[A] =
        result = newSeq[A](tree.prefix.len)
        result.skipTourCopyRange(0, tree.prefix, 0, tree.prefix.len)
        if parent < 0: return
        for event in tree.events:
            if event > 0:
                result.add(tree.actions[event-1])
                if event-1 == parent: return
            else:
                result.setLen(result.len-1)

    # 世代終了時の最良候補を走査する。同点は小さいスロットを優先する。
    proc skipTourBest[A, S, K](candidates: seq[SkipTourCandidate[A, S, K]], minimize: bool): int =
        for i in 1..<candidates.len:
            if skipTourBetter(candidates[i].score, candidates[result].score, minimize): result = i

    # 選抜器が参照する旧親を、新しいツアー配列の位置へ置き換える。
    proc skipTourRemap[A, S, K](s: SkipTourSelector[A, S, K], remap: seq[int]) =
        template fix(c: untyped) =
            if c.parent >= 0: c.parent = max(-1, remap[c.parent])
            elif c.parent < -1: c.parent = -c.parent-2
        for c in s.candidates.mitems: fix(c)
        if s.hasFinished: fix(s.finished)
        for bucket in s.buckets.mitems:
            for c in bucket.mitems: fix(c)

    # 展開が必要になった時だけ、前の現在地から対象の親へ差分移動する。
    proc skipTourMoveParent[T, A](tree: var SkipTourTree[T, A],
            firstMove: var bool, commonDepth: var int) =
        mixin moveForward, moveBackward
        let depth = tree.prefix.len+tree.stack.len
        var common = min(commonDepth, depth)
        if firstMove:
            common = tree.confirmedPrefix
            while common < min(tree.trace.len, depth):
                let id = if common < tree.prefix.len: -common-2
                    else: tree.stack[common-tree.prefix.len]
                if tree.traceIds[common] != id: break
                inc common
            firstMove = false
        for i in countdown(tree.trace.high, common): skipTourBoardBackward(tree.state, tree.trace[i])
        tree.trace.setLen(depth)
        if common < tree.prefix.len:
            tree.trace.skipTourCopyRange(common, tree.prefix, common, tree.prefix.len-common)
            for i in common..<tree.prefix.len: skipTourBoardForward(tree.state, tree.trace[i])
        for i in max(common, tree.prefix.len)..<depth:
            let node = tree.stack[i-tree.prefix.len]
            tree.trace[i] = tree.actions[node]
            skipTourBoardForward(tree.state, tree.trace[i])
        commonDepth = depth

    # 親ごとの候補リストを逆順の先頭追加で作り、スロット昇順を保つ。
    proc skipTourGroupChildren[T, A, S, K](tree: var SkipTourTree[T, A],
            chosen: seq[SkipTourCandidate[A, S, K]]) =
        if tree.head.len < tree.actions.len+1: tree.head.setLen(tree.actions.len+1)
        tree.next.setLen(chosen.len)
        for slot in countdown(chosen.high, 0):
            let parent = chosen[slot].parent+1
            tree.next[slot] = tree.head[parent]
            tree.head[parent] = slot+1

    # 同じ親から選ばれた子を展開し、最後の子のStateをそのまま保持する。
    proc skipTourChildren[T, A, S, K](tree: var SkipTourTree[T, A],
            chosen: seq[SkipTourCandidate[A, S, K]], best, parent: int,
            frontier: var SkipTourBeamFrontier[A, S, K], firstMove: var bool,
            commonDepth, newSaved, remaining: var int) =
        mixin expand
        var link = tree.head[parent+1]
        tree.head[parent+1] = 0
        while link != 0:
            let slot = link-1
            link = tree.next[slot]
            tree.skipTourMoveParent(firstMove, commonDepth)
            let action = chosen[slot].action
            let node = tree.actionCount
            tree.nextActions[node] = action
            inc tree.actionCount
            tree.nextEvents[tree.eventCount] = node+1
            inc tree.eventCount
            if slot == best: newSaved = node
            tree.trace.add(action)
            skipTourBoardForward(tree.state, action)
            frontier.currentParent = -node-2
            frontier.currentScore = chosen[slot].score
            frontier.currentHash = chosen[slot].key
            skipTourLoadLeaf(tree.state, frontier.currentScore, frontier.currentHash, A)
            tree.state.expand(frontier)
            tree.nextEvents[tree.eventCount] = -node-1
            inc tree.eventCount
            dec remaining
            # ID列は次世代の最初の移動でしか使わないため、最後の現在地だけ保存する。
            if remaining == 0:
                tree.traceIds.setLen(tree.trace.len)
                for i in tree.confirmedPrefix..<tree.prefix.len: tree.traceIds[i] = -i-2
                tree.confirmedPrefix = tree.prefix.len
                for i, old in tree.stack: tree.traceIds[tree.prefix.len+i] = tree.remap[old]
                tree.traceIds[^1] = node

    # 通常候補・完了候補・未選抜のグループ保留があるかを調べる。
    template skipTourHasCandidates[A, S, K](selector: SkipTourSelector[A, S, K]): bool =
        block:
            let pendingSelector = selector
            var found = pendingSelector.hasFinished or pendingSelector.candidates.len > 0
            if not found:
                for bucket in pendingSelector.buckets:
                    if bucket.len > 0:
                        found = true
                        break
            found

    # 空世代の省略回数が奇数なら、入退場イベントを反転して巡回順だけを合わせる。
    proc skipTourReverse[T, A](tree: var SkipTourTree[T, A]) =
        for i in 0..<(tree.events.len shr 1):
            let other = tree.events.high-i
            let event = tree.events[i]
            tree.events[i] = -tree.events[other]
            tree.events[other] = -event

    # 将来候補が参照する親が残っているかを調べる。
    proc skipTourHasPending[A, S, K](frontier: SkipTourBeamFrontier[A, S, K]): bool =
        for selector in frontier.selectors.items:
            if selector.hasFinished or selector.candidates.len > 0: return true
            for bucket in selector.buckets:
                if bucket.len > 0: return true

    # 待機候補がない層は旧ツアーを1回だけ巡回し、採用した枝の経路だけを直接残す。
    proc skipTourAdvanceSingle[T, A, S, K](tree: var SkipTourTree[T, A],
            chosen: seq[SkipTourCandidate[A, S, K]], best: int,
            frontier: var SkipTourBeamFrontier[A, S, K]) =
        tree.remap.setLen(tree.actions.len)
        tree.skipTourGroupChildren(chosen)
        var first = 0
        var last = tree.events.len
        let oldPrefix = tree.prefix.len
        # 既に全枝に共通する接頭辞は、採用親に到達する直前まで確定できる。
        if tree.head[0] == 0:
            while first < last and tree.events[first] == -tree.events[last-1]:
                let node = tree.events[first]-1
                if tree.head[node+1] != 0: break
                tree.remap[node] = -tree.prefix.len-2
                tree.prefix.add(tree.actions[node])
                inc first
                dec last
        for i in 0..<min(first, tree.traceIds.len-oldPrefix):
            let node = tree.events[i]-1
            if tree.traceIds[oldPrefix+i] != node: break
            tree.traceIds[oldPrefix+i] = tree.remap[node]
        tree.nextActions.setLen(tree.actions.len+chosen.len)
        tree.nextEvents.setLen(tree.events.len+2*chosen.len)
        tree.actionCount = 0
        tree.eventCount = 0
        tree.stack.setLen(0)
        # filteredは、この経路の開いている新しい辺番号のスタックとして再利用する。
        tree.filtered.setLen(0)
        var commonKept = 0
        var firstMove = true
        var commonDepth = 0
        var newSaved = -1
        var remaining = chosen.len
        template expandParent(parent: int) =
            for i in countdown(tree.filtered.high, commonKept):
                tree.nextEvents[tree.eventCount] = -tree.filtered[i]-1
                inc tree.eventCount
            tree.filtered.setLen(commonKept)
            for i in commonKept..<tree.stack.len:
                let old = tree.stack[i]
                let node = tree.actionCount
                tree.remap[old] = node
                tree.nextActions[node] = tree.actions[old]
                inc tree.actionCount
                tree.nextEvents[tree.eventCount] = node+1
                inc tree.eventCount
                tree.filtered.add(node)
            commonKept = tree.stack.len
            tree.skipTourChildren(chosen, best, parent, frontier,
                firstMove, commonDepth, newSaved, remaining)
        for position in countdown(last-1, first):
            let event = -tree.events[position]
            if event > 0:
                tree.stack.add(event-1)
            else:
                let old = -event-1
                if tree.head[old+1] != 0: expandParent(old)
                tree.stack.setLen(tree.stack.len-1)
                commonKept = min(commonKept, tree.stack.len)
                commonDepth = min(commonDepth, tree.prefix.len+tree.stack.len)
        if tree.head[0] != 0: expandParent(-1)
        for i in countdown(tree.filtered.high, 0):
            tree.nextEvents[tree.eventCount] = -tree.filtered[i]-1
            inc tree.eventCount
        when defined(debug): doAssert remaining == 0
        tree.saved = newSaved
        # 展開中に新しく予約された候補は、新しい親番号へ直すだけでよい。
        for selector in frontier.selectors.items: selector.skipTourRemap(tree.remap)
        tree.nextActions.setLen(tree.actionCount)
        tree.nextEvents.setLen(tree.eventCount)
        swap(tree.actions, tree.nextActions)
        swap(tree.events, tree.nextEvents)

    # 待機経路を圧縮し、逆向きに巡回して前世代の末尾に近い枝から展開する。
    proc skipTourAdvance[T, A, S, K](tree: var SkipTourTree[T, A],
            chosen: seq[SkipTourCandidate[A, S, K]], best: int,
            frontier: var SkipTourBeamFrontier[A, S, K]) =
        tree.needed.setLen(tree.actions.len)
        tree.direct.setLen(tree.actions.len)
        tree.remap.setLen(tree.actions.len)
        for i in 0..<tree.actions.len:
            tree.needed[i] = false
            tree.direct[i] = false
            tree.remap[i] = -1
        var rootNeeded = false
        template mark(parent: int) =
            if parent < 0: rootNeeded = true
            else:
                tree.needed[parent] = true
                tree.direct[parent] = true
        for c in chosen: mark(c.parent)
        for s in frontier.selectors.items:
            for c in s.candidates: mark(c.parent)
            if s.hasFinished: mark(s.finished.parent)
            for bucket in s.buckets:
                for c in bucket: mark(c.parent)
        if chosen.len == 0: mark(tree.saved)
        tree.stack.setLen(0)
        for event in tree.events:
            if event > 0: tree.stack.add(event-1)
            else:
                let node = tree.stack[^1]
                tree.stack.setLen(tree.stack.len-1)
                if tree.needed[node] and tree.stack.len > 0: tree.needed[tree.stack[^1]] = true
        tree.filtered.setLen(0)
        for event in tree.events:
            if tree.needed[abs(event)-1]: tree.filtered.add(event)
        # 共通接頭辞を経路から分離する。Stateは最後の展開位置に保持する。
        var first = 0
        var last = tree.filtered.len
        while not rootNeeded and first < last and tree.filtered[first] == -tree.filtered[last-1]:
            let node = tree.filtered[first]-1
            tree.remap[node] = -tree.prefix.len-2
            tree.prefix.add(tree.actions[node])
            tree.needed[node] = false
            rootNeeded = tree.direct[node]
            inc first
            dec last
        tree.skipTourGroupChildren(chosen)
        tree.nextActions.setLen(0)
        tree.nextEvents.setLen(0)
        # 保持するActionの連続区間をまとめて詰め、旧番号の変換表を作る。
        var source = 0
        while source < tree.actions.len:
            if not tree.needed[source]:
                inc source
                continue
            let begin = source
            let offset = tree.nextActions.len
            while source < tree.actions.len and tree.needed[source]:
                tree.remap[source] = offset+source-begin
                inc source
            tree.nextActions.setLen(offset+source-begin)
            tree.nextActions.skipTourCopyRange(offset, tree.actions, begin, source-begin)
        tree.actionCount = tree.nextActions.len
        tree.eventCount = 0
        tree.nextActions.setLen(tree.actionCount+chosen.len)
        tree.nextEvents.setLen(tree.filtered.len+2*chosen.len)
        # 接頭辞へ移った現在地の番号だけを先に確定する。残りは最初の移動まで旧番号。
        for id in tree.traceIds.mitems:
            if id >= 0 and tree.remap[id] < -1: id = tree.remap[id]
        let oldSaved = tree.saved
        var newSaved = -1
        var firstMove = true
        var commonDepth = 0
        var remaining = chosen.len
        # 配列を逆に読み、入る・戻るを反転すれば反対向きのツアーになる。
        for pos in countdown(last-1, first):
            let event = -tree.filtered[pos]
            if event > 0:
                let old = event-1
                let node = tree.remap[old]
                tree.nextEvents[tree.eventCount] = node+1
                inc tree.eventCount
                tree.stack.add(old)
            else:
                let old = -event-1
                if tree.head[old+1] != 0:
                    tree.skipTourChildren(chosen, best, old, frontier, firstMove, commonDepth, newSaved, remaining)
                tree.stack.setLen(tree.stack.len-1)
                commonDepth = min(commonDepth, tree.prefix.len+tree.stack.len)
                tree.nextEvents[tree.eventCount] = -tree.remap[old]-1
                inc tree.eventCount
        # 根の候補は末尾に置き、先頭での不要な根への復帰を避ける。
        for pos in countdown(first-1, 0):
            let old = tree.filtered[pos]-1
            if tree.head[old+1] != 0:
                tree.skipTourChildren(chosen, best, old, frontier,
                    firstMove, commonDepth, newSaved, remaining)
        if tree.head[0] != 0:
            tree.skipTourChildren(chosen, best, -1, frontier, firstMove, commonDepth, newSaved, remaining)
        when defined(debug): doAssert remaining == 0
        if chosen.len == 0:
            for id in tree.traceIds.mitems:
                if id >= 0: id = tree.remap[id]
        tree.saved = if chosen.len > 0: newSaved elif oldSaved < 0: -1 else: max(-1, tree.remap[oldSaved])
        for s in frontier.selectors.items: s.skipTourRemap(tree.remap)
        tree.nextActions.setLen(tree.actionCount)
        tree.nextEvents.setLen(tree.eventCount)
        swap(tree.actions, tree.nextActions)
        swap(tree.events, tree.nextEvents)

    # 指定世代へ進み、待機経路を含む配列だけで探索と行動列の復元を行う。
    proc runSkipTourBeam*[State, Action, Score, Key](initial: State, beamWidth: int,
            maxTurns = 2000, minimize = true, groupLimit = 0,
            groupCount = 0): SkipTourBeamResult[Action, Score] =
        mixin evaluate, expand, getHash
        when defined(debug):
            if maxTurns < 0: raise newException(ValueError, "maxTurns must be nonnegative")
        var frontier = initSkipTourBeamFrontier[Action, Score, Key](beamWidth, minimize, groupLimit, groupCount)
        var tree = SkipTourTree[State, Action](state: initial, saved: -1)
        result.score = tree.state.evaluate()
        result.status = beamMaxTurns
        if skipTourFinishedField(tree.state):
            result.status = beamFinished
            return
        if maxTurns == 0: return
        frontier.remaining = maxTurns
        frontier.currentScore = result.score
        frontier.currentHash = tree.state.getHash()
        skipTourLoadLeaf(tree.state, frontier.currentScore, frontier.currentHash, Action)
        tree.state.expand(frontier)
        var turn = 1
        var reversePending = false
        while turn <= maxTurns:
            if frontier.selectors.len == 0:
                result.status = beamExhausted
                result.actions = tree.skipTourPath(tree.saved)
                return
            let s = frontier.selectors.popFirst()
            if not s.skipTourHasCandidates():
                # 空の選抜器を再利用し、次の到着時刻までStateも経路も変更しない。
                frontier.selectors.addLast(s)
                var skipped = 1
                while skipped < frontier.selectors.len and
                        not frontier.selectors[skipped-1].skipTourHasCandidates():
                    inc skipped
                if skipped == frontier.selectors.len and
                        not frontier.selectors[skipped-1].skipTourHasCandidates():
                    result.status = beamExhausted
                    result.actions = tree.skipTourPath(tree.saved)
                    return
                skipped = min(skipped, maxTurns-turn+1)
                for i in 1..<skipped:
                    frontier.selectors.addLast(frontier.selectors.popFirst())
                if (skipped and 1) != 0: reversePending = not reversePending
                turn += skipped
                continue
            s.skipTourSelectGroups()
            result.selectedCandidates += int64(s.candidates.len + ord(s.hasFinished))
            var best = -1
            if s.hasFinished or s.candidates.len > 0:
                best = if s.hasFinished: -1 else: skipTourBest(s.candidates, minimize)
                let candidate = if s.hasFinished: s.finished else: s.candidates[best]
                result.score = candidate.score
                result.turns = turn
                if s.hasFinished or turn == maxTurns:
                    result.actions = tree.skipTourPath(candidate.parent)
                    result.actions.add(candidate.action)
                    if s.hasFinished: result.status = beamFinished
                    return
            if turn == maxTurns: break
            if reversePending:
                tree.skipTourReverse()
                reversePending = false
            frontier.remaining = maxTurns-turn
            if s.candidates.len > 0 and not frontier.skipTourHasPending():
                tree.skipTourAdvanceSingle(s.candidates, best, frontier)
            else:
                tree.skipTourAdvance(s.candidates, best, frontier)
            s.candidates.setLen(0)
            s.indices.clear()
            s.hasFinished = false
            # 少なくとも最大step分は選抜器を保持し、Hash表の再確保を避ける。
            frontier.selectors.addLast(s)
            if not frontier.skipTourHasPending():
                result.status = beamExhausted
                result.actions = tree.skipTourPath(tree.saved)
                return
            inc turn
        result.actions = tree.skipTourPath(tree.saved)

    # 問題の型を固定した探索関数を指定名で定義する。
    template defineSkipTourBeam*(name, State, Action, Score, Key: untyped) =
        # 初期Stateと固定幅・世代上限・グループ設定をcoreへ渡す。
        template name(initial: State, beamWidth: int, maxTurns = 2000,
                minimize = true, groupLimit = 0, groupCount = 0): SkipTourBeamResult[Action, Score] =
            runSkipTourBeam[State, Action, Score, Key](initial, beamWidth, maxTurns,
                minimize, groupLimit, groupCount)

include ../header

## 差分更新・巻き戻しによるビームサーチ。標準選抜 O(log W)、幅Wは実行時指定。
## 状態を候補ごとにコピーせず、共通経路を探索木で共有する。stepによる複数ターン遷移に対応。
when not declared ThunderBeamCoreModule:
    const ThunderBeamCoreModule* = true

    type
        BeamStatus* = enum
            beamFinished, beamMaxTurns, beamExhausted, beamTimeLimit
        BeamResult*[Action, Score] = object
            score*: Score
            actions*: seq[Action]
            turns*: int
            status*: BeamStatus
            selectedCandidates*: int64 ## 選抜済み未完了候補数 + 各層の完了候補数（最大1）。
        BeamCandidate[Action, Score, Key] = object
            action: Action
            score: Score
            key: Key
            parent: int
        BeamHashMap[Key] = object
            keys: seq[Key]
            values: seq[int]
            valid: seq[uint64]
            used: int
        ObjectPool[T] = object
            data: seq[T]
            garbage: seq[int]
        BeamSelector[Action, Score, Key] = ref object
            width: int
            minimize: bool
            candidates: seq[BeamCandidate[Action, Score, Key]]
            indices: BeamHashMap[Key]
            worst: seq[int]
            size: int
            hasFinished: bool
            finished: BeamCandidate[Action, Score, Key]
            groupLimit: int
            buckets: seq[seq[BeamCandidate[Action, Score, Key]]]
        BeamFrontier*[Action, Score, Key] = object
            selectors: Deque[BeamSelector[Action, Score, Key]]
            width, stepMax, remaining: int
            minimize: bool
            groupLimit, groupCount: int
        BeamNode[Action] = object
            action: Action
            parent, child, left, right: int
            retainedUntil: int
            active: bool
        BeamTree[State, Action] = object
            state: State
            nodes: ObjectPool[BeamNode[Action]]
            root, turn, saved: int
            removals: Deque[seq[int]]

    # 指定インデックスのプール要素を参照し、可変プールならその要素を変更できる。
    template `[]`[T](pool: ObjectPool[T], i: int): untyped = pool.data[i]
    # 指定インデックスのプール要素を置き換える。
    template `[]=`[T](pool: var ObjectPool[T], i: int, value: T) = pool.data[i] = value

    # ビーム幅に応じた容量の重複除去用Hash表を確保する。
    proc initBeamHashMap[K](width: int): BeamHashMap[K] =
        var capacity = 16
        while capacity < width * 16: capacity *= 2
        result.keys = newSeq[K](capacity)
        result.values = newSeq[int](capacity)
        result.valid = newSeq[uint64]((capacity + 63) div 64)

    # 確保済みの配列を再利用し、Hash表の登録情報だけを消去する。
    proc clear[K](m: var BeamHashMap[K]) =
        for word in m.valid.mitems: word = 0
        m.used = 0

    # キーを線形探索し、一致したスロットまたは登録先の空きスロットを返す。
    proc getIndex[K](m: BeamHashMap[K], key: K): tuple[found: bool, slot: int] =
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
    proc set[K](m: var BeamHashMap[K], slot: int, key: K, value: int) =
        let bit = 1'u64 shl (slot and 63)
        if (m.valid[slot shr 6] and bit) == 0:
            m.valid[slot shr 6] = m.valid[slot shr 6] or bit
            inc m.used
        m.keys[slot] = key
        m.values[slot] = value

    # 採用中の候補だけでHash表を作り直し、追い出された候補のキーを除く。
    proc beamRebuildHash[A, S, K](s: BeamSelector[A, S, K]) =
        s.indices.clear()
        for i, c in s.candidates:
            let (_, slot) = s.indices.getIndex(c.key)
            s.indices.set(slot, c.key, i)

    # 評価方向に従い、aがbより良いか判定する。
    template beamBetter[S](a, b: S, minimize: bool): bool =
        block:
            let first = a
            let second = b
            let isMinimum = minimize
            if isMinimum: first < second else: second < first

    # 無効な葉を除き、2候補のうち評価の悪いインデックスを返す。
    template beamWorst[A, S, K](s: BeamSelector[A, S, K], a, b: int): int =
        block:
            let selector = s
            let first = a
            let second = b
            if first < 0: second
            elif second < 0: first
            elif beamBetter(selector.candidates[first].score, selector.candidates[second].score,
                selector.minimize): second
            else: first

    # 候補が幅に達した時点で、最悪候補を管理するセグ木を構築する。
    proc beamBuild[A, S, K](s: BeamSelector[A, S, K]) =
        s.size = 1
        while s.size < s.width: s.size *= 2
        s.worst.setLen(s.size * 2)
        for i in 0..<s.worst.len: s.worst[i] = -1
        for i in 0..<s.width: s.worst[s.size+i] = i
        for i in countdown(s.size-1, 1):
            let left = i shl 1
            s.worst[i] = s.beamWorst(s.worst[left], s.worst[left or 1])

    # 指定候補の変更を反映し、セグ木の根まで最悪候補を更新する。
    proc beamUpdate[A, S, K](s: BeamSelector[A, S, K], index: int) =
        var p = (s.size + index) shr 1
        while p > 0:
            let left = p shl 1
            s.worst[p] = s.beamWorst(s.worst[left], s.worst[left or 1])
            p = p shr 1

    # 1つの到達ターンへ候補を登録し、通常選抜・グループ保留・完了候補を処理する。
    proc beamPush[A, S, K](s: BeamSelector[A, S, K],
        candidate: BeamCandidate[A, S, K], finished: bool, group: int): bool =
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
        if full and not beamBetter(candidate.score,
            s.candidates[s.worst[1]].score, s.minimize): return false
        if s.indices.used >= s.indices.keys.len * 7 div 10: s.beamRebuildHash()
        let (found, slot) = s.indices.getIndex(candidate.key)
        let old = if found: s.indices.values[slot] else: -1
        if old >= 0 and s.candidates[old].key == candidate.key:
            if not beamBetter(candidate.score, s.candidates[old].score, s.minimize): return false
            s.candidates[old] = candidate
            if full: s.beamUpdate(old)
        elif full:
            let index = s.worst[1]
            s.candidates[index] = candidate
            s.indices.set(slot, candidate.key, index)
            s.beamUpdate(index)
        else:
            s.indices.set(slot, candidate.key, s.candidates.len)
            s.candidates.add(candidate)
            if s.candidates.len == s.width: s.beamBuild()
        true

    # グループID順に重複を除去し、各グループの上位候補を確定する。
    proc beamSelectGroups[A, S, K](s: BeamSelector[A, S, K]) =
        if s.groupLimit <= 0: return
        var seen = initHashSet[K](0)
        for bucket in s.buckets.mitems:
            # std/algorithm.sort is stable: equal scores retain registration order.
            let minimize = s.minimize
            bucket.sort(proc(a, b: BeamCandidate[A, S, K]): int =
                if beamBetter(a.score, b.score, minimize): -1
                elif beamBetter(b.score, a.score, minimize): 1
                else: 0)
            var kept = 0
            for candidate in bucket:
                if candidate.key in seen: continue
                seen.incl(candidate.key)
                s.candidates.add(candidate)
                inc kept
                if kept == s.groupLimit: break
            bucket.setLen(0)

    # 現在の展開位置から探索上限までに残されたターン数を返す。
    template remainingTurns*[A, S, K](frontier: BeamFrontier[A, S, K]): int =
        frontier.remaining

    # 到達ターン・評価値・完了判定から、Hash計算前に候補を足切りする。
    proc canImprove*[A, S, K](frontier: BeamFrontier[A, S, K], score: S,
        step = 1, finished = false, group = -1): bool =
        ## falseならpushは必ず不採用。trueでもキー重複などで不採用になり得る。
        when defined(debug):
            if step <= 0: raise newException(ValueError, "beam step must be positive")
            if frontier.groupLimit > 0 and (group < 0 or group >= frontier.groupCount):
                raise newException(ValueError, "beam group out of range")
        if step > frontier.remaining: return false
        if step > frontier.selectors.len: return true
        let s = frontier.selectors[step-1]
        if finished: return not s.hasFinished
        # グループ方式は選抜時まで閾値が確定しないため、保守的に受け付ける。
        if s.groupLimit > 0 or s.candidates.len < s.width: return true
        beamBetter(score, s.candidates[s.worst[1]].score, s.minimize)

    # 評価済みの遷移を指定step先へ登録し、親の保持に必要な最大stepを記録する。
    proc push*[A, S, K](frontier: var BeamFrontier[A, S, K], action: A,
        score: S, key: K, parent: int, finished = false, step = 1,
        group = -1): bool {.discardable.} =
        ## score/key/finishedは遷移後の値。stepは正のターン消費量。
        when defined(debug):
            if step <= 0: raise newException(ValueError, "beam step must be positive")
            if frontier.groupLimit > 0 and (group < 0 or group >= frontier.groupCount):
                raise newException(ValueError, "beam group out of range")
        if step > frontier.remaining: return false
        while frontier.selectors.len < step:
            frontier.selectors.addLast(BeamSelector[A, S, K](
                width: frontier.width, minimize: frontier.minimize,
                candidates: newSeqOfCap[BeamCandidate[A, S, K]](
                    if frontier.groupLimit > 0: 0 else: frontier.width),
                indices: (if frontier.groupLimit > 0: default(BeamHashMap[K])
                    else: initBeamHashMap[K](frontier.width)),
                groupLimit: frontier.groupLimit,
                buckets: newSeq[seq[BeamCandidate[A, S, K]]](frontier.groupCount)))
        result = frontier.selectors[step-1].beamPush(
            BeamCandidate[A, S, K](action: action, score: score, key: key, parent: parent), finished, group)
        if result: frontier.stepMax = max(frontier.stepMax, step)

    # 空きインデックスを再利用し、なければプールを拡張してノードを確保する。
    proc beamAllocate[T, A](tree: var BeamTree[T, A], node: BeamNode[A]): int =
        if tree.nodes.garbage.len == 0:
            result = tree.nodes.data.len
            tree.nodes.data.add(node)
        else:
            result = system.pop(tree.nodes.garbage)
            tree.nodes[result] = node

    # 選抜済み候補を親へ接続し、その葉へ至る枝を次の展開対象にする。
    proc beamAddLeaf[T, A, S, K](tree: var BeamTree[T, A], candidate: BeamCandidate[A, S, K]): int {.discardable.} =
        let parent = candidate.parent
        let sibling = tree.nodes[parent].child
        let node = tree.beamAllocate(BeamNode[A](action: candidate.action,
            parent: parent, child: -1, left: -1, right: sibling, active: true))
        result = node
        tree.nodes[parent].child = node
        if sibling >= 0: tree.nodes[sibling].left = node
        var v = parent
        while not tree.nodes[v].active:
            tree.nodes[v].active = true
            if v == tree.root: break
            v = tree.nodes[v].parent

    # 保存中・将来参照中のノードを保護しながら、不要な葉と祖先を解放する。
    proc beamRemoveLeaf[T, A](tree: var BeamTree[T, A], index: int) =
        var v = index
        while v != tree.root:
            # 短い枝が枯れても、将来ターンの候補が参照する親は解放しない。
            if v == tree.saved or tree.nodes[v].retainedUntil >= tree.turn: break
            let node = tree.nodes[v]
            if node.left < 0: tree.nodes[node.parent].child = node.right
            else: tree.nodes[node.left].right = node.right
            if node.right >= 0: tree.nodes[node.right].left = node.left
            tree.nodes.garbage.add(v)
            if tree.nodes[node.parent].child >= 0: break
            v = node.parent

    # 保持期限を迎えたノードを調べ、不要になった葉を削除する。
    proc beamPrune[T, A](tree: var BeamTree[T, A]) =
        if tree.removals.len == 0: return
        var expired = tree.removals.popFirst()
        for v in expired:
            if tree.nodes[v].child < 0: tree.beamRemoveLeaf(v)
        expired.setLen(0)
        tree.removals.addLast(expired)

    # 分岐が1本だけで将来参照もなければ、Stateを進めて探索木の根を移す。
    proc beamUpdateRoot[T, A](tree: var BeamTree[T, A]) =
        mixin moveForward
        var child = tree.nodes[tree.root].child
        while child >= 0 and tree.nodes[child].right < 0 and
            tree.nodes[tree.root].retainedUntil < tree.turn:
            tree.root = child
            tree.state.moveForward(tree.nodes[child].action)
            child = tree.nodes[child].child

    # 有効な子をたどってStateを進め、次に展開する葉へ移動する。
    proc beamMoveToLeaf[T, A](tree: var BeamTree[T, A], index: int): int =
        mixin moveForward
        var v = index
        var child = tree.nodes[v].child
        while child >= 0:
            while child >= 0 and not tree.nodes[child].active:
                child = tree.nodes[child].right
            when defined(debug):
                doAssert child >= 0, "beam active subtree has no active child"
            tree.nodes[v].active = false
            v = child
            tree.state.moveForward(tree.nodes[v].action)
            child = tree.nodes[v].child
        tree.nodes[v].active = false
        v

    # Stateを祖先へ巻き戻し、未展開の兄弟があればその枝へ移動する。
    proc beamMoveToAncestor[T, A](tree: var BeamTree[T, A], index: int): int =
        mixin moveForward, moveBackward
        var v = index
        while v != tree.root:
            tree.state.moveBackward(tree.nodes[v].action)
            var sibling = tree.nodes[v].right
            while sibling >= 0:
                if tree.nodes[sibling].active:
                    tree.state.moveForward(tree.nodes[sibling].action)
                    return sibling
                sibling = tree.nodes[sibling].right
            v = tree.nodes[v].parent
        tree.root

    # 枝を整理して有効な葉をDFSで展開し、将来候補が使う親ノードを保持する。
    proc beamDfs[T, A, S, K](tree: var BeamTree[T, A], frontier: var BeamFrontier[A, S, K]) =
        mixin expand
        tree.beamPrune()
        tree.beamUpdateRoot()
        var v = tree.root
        if not tree.nodes[v].active: return
        while true:
            v = tree.beamMoveToLeaf(v)
            frontier.stepMax = 1
            tree.state.expand(v, frontier)
            tree.nodes[v].retainedUntil = tree.turn + frontier.stepMax - 1
            while tree.removals.len < frontier.stepMax: tree.removals.addLast(@[])
            tree.removals[frontier.stepMax-1].add(v)
            v = tree.beamMoveToAncestor(v)
            if v == tree.root: break

    # 指定ノードから親をたどり、初期状態からの行動列を復元する。
    proc beamPath[T, A](tree: BeamTree[T, A], index: int): seq[A] =
        var v = index
        while tree.nodes[v].parent >= 0:
            result.add(tree.nodes[v].action)
            v = tree.nodes[v].parent
        result.reverse()

    # 登録済み候補を維持し、今後作成・再利用する選抜器の幅を変更する。
    template beamResize[A, S, K](frontier: var BeamFrontier[A, S, K], newWidth: int) =
        # 元コード同様、登録済み候補は削らずselectorの再利用時に反映する。
        frontier.width = newWidth

    # 累積幅・経過時間・残りターンから、縮小後のビーム幅を見積もる。
    proc beamAdjustedWidth(current, minimum: int, totalWidth, elapsed, limit: float,
        remaining: int): int =
        if elapsed <= 0 or remaining <= 0: return current
        if elapsed >= limit: return minimum
        # 元コード: 累積幅 * (1 - 経過時間率) / 経過時間率 / 残りターン。
        let estimate = totalWidth * ((limit - elapsed) / elapsed) / float(remaining)
        if estimate >= float(current): return current
        if estimate <= float(minimum): return minimum
        int(estimate)

    # 正の時間制限が指定されている場合に、開始時刻からの超過を判定する。
    template beamExpired(start: MonoTime, limit: float): bool =
        block:
            let startedAt = start
            let limitSeconds = limit
            limitSeconds > 0 and float(getMonoTime().ticks - startedAt.ticks) / 1e9 >= limitSeconds

    # 差分適用・巻き戻しで展開と選抜を繰り返し、最良の行動列と終了状態を返す。
    proc runThunderBeam*[State, Action, Score, Key](initial: State, beamWidth: int,
        maxTurns = 2000, minimize = true, timeLimitSec = 0.0,
        minBeamWidth = 0, widthUpdateInterval = 256,
        stopOnTimeLimit = true, groupLimit = 0, groupCount = 0): BeamResult[Action, Score] =
        mixin evaluate, isFinished
        when defined(debug):
            if beamWidth <= 0: raise newException(ValueError, "beamWidth must be positive")
            if maxTurns < 0: raise newException(ValueError, "maxTurns must be nonnegative")
            if timeLimitSec < 0: raise newException(ValueError, "timeLimitSec must be nonnegative")
            if minBeamWidth < 0 or minBeamWidth > beamWidth:
                raise newException(ValueError, "minBeamWidth must be in 0..beamWidth")
            if widthUpdateInterval <= 0:
                raise newException(ValueError, "widthUpdateInterval must be positive")
            if minBeamWidth > 0 and timeLimitSec <= 0:
                raise newException(ValueError, "adaptive width requires timeLimitSec > 0")
            if groupLimit > 0 and minBeamWidth > 0:
                raise newException(ValueError, "group selection requires fixed width")
            if groupLimit < 0 or groupCount < 0 or (groupLimit > 0 and groupCount <= 0):
                raise newException(ValueError, "invalid group bucket dimensions")
        let start = getMonoTime()
        var tree = BeamTree[State, Action](state: initial,
            nodes: ObjectPool[BeamNode[Action]](
                data: newSeqOfCap[BeamNode[Action]](beamWidth * 4),
                garbage: newSeqOfCap[int](beamWidth * 4)))
        result.score = tree.state.evaluate()
        if tree.state.isFinished():
            result.status = beamFinished
            return
        result.status = beamMaxTurns
        if maxTurns == 0: return
        tree.root = tree.beamAllocate(BeamNode[Action](
            parent: -1, child: -1, left: -1, right: -1, active: true))
        var frontier = BeamFrontier[Action, Score, Key](width: beamWidth, minimize: minimize,
            groupLimit: groupLimit, groupCount: groupCount)
        var totalWidth = 0.0
        for turn in 1..maxTurns:
            if groupLimit == 0 and minBeamWidth > 0 and turn mod widthUpdateInterval == 0 and turn < maxTurns:
                let elapsed = float(getMonoTime().ticks - start.ticks) / 1e9
                let width = beamAdjustedWidth(frontier.width, minBeamWidth, totalWidth,
                    elapsed, timeLimitSec, maxTurns - turn)
                if width < frontier.width: frontier.beamResize(width)
            tree.turn = turn
            frontier.remaining = maxTurns - turn + 1
            tree.beamDfs(frontier)
            if frontier.selectors.len == 0:
                result.status = beamExhausted
                result.actions = tree.beamPath(tree.saved)
                return
            let selector = frontier.selectors.popFirst()
            selector.beamSelectGroups()
            result.selectedCandidates += int64(selector.candidates.len + ord(selector.hasFinished))
            totalWidth += float((frontier.width + selector.candidates.len) shr 1)
            var bestIndex = -1
            if selector.hasFinished or selector.candidates.len > 0:
                var candidate: BeamCandidate[Action, Score, Key]
                if selector.hasFinished: candidate = selector.finished
                else:
                    candidate = selector.candidates[0]
                    bestIndex = 0
                    for i, c in selector.candidates:
                        if beamBetter(c.score, candidate.score, minimize):
                            candidate = c
                            bestIndex = i
                result.score = candidate.score
                result.turns = turn
                if selector.hasFinished or turn == maxTurns:
                    result.actions = tree.beamPath(candidate.parent)
                    result.actions.add(candidate.action)
                    if selector.hasFinished: result.status = beamFinished
                    return
            let previous = tree.saved
            for i, candidate in selector.candidates:
                let node = tree.beamAddLeaf(candidate)
                if i == bestIndex: tree.saved = node
            if previous != tree.saved and tree.nodes[previous].child < 0:
                tree.beamRemoveLeaf(previous)
            selector.candidates.setLen(0)
            selector.width = frontier.width
            selector.indices.clear()
            selector.hasFinished = false
            frontier.selectors.addLast(selector)
            var pending = tree.nodes[tree.root].active
            for s in frontier.selectors.items:
                if s.hasFinished or s.candidates.len > 0: pending = true
                for bucket in s.buckets.items:
                    if bucket.len > 0: pending = true
            if not pending:
                result.status = beamExhausted
                result.actions = tree.beamPath(tree.saved)
                return
            if stopOnTimeLimit and beamExpired(start, timeLimitSec):
                result.status = beamTimeLimit
                result.actions = tree.beamPath(tree.saved)
                return
        result.actions = tree.beamPath(tree.saved)

    # State・Action・評価値・キーの型を固定し、指定名の探索関数を定義する。
    template defineThunderBeam*(name, State, Action, Score, Key: untyped) =
        ## 問題ごとに一度定義すると name(initial, beamWidth, ...) で呼べる。
        # 型を固定した探索条件をrunThunderBeamへ渡す。
        template name(initial: State, beamWidth: int, maxTurns = 2000,
            minimize = true, timeLimitSec = 0.0,
            minBeamWidth = 0, widthUpdateInterval = 256,
            stopOnTimeLimit = true, groupLimit = 0, groupCount = 0): BeamResult[Action, Score] =
            runThunderBeam[State, Action, Score, Key](initial, beamWidth, maxTurns,
                minimize, timeLimitSec, minBeamWidth, widthUpdateInterval, stopOnTimeLimit,
                groupLimit, groupCount)

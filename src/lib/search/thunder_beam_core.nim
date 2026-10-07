## 差分更新・巻き戻しによるビームサーチ。候補選択 O(log W)、幅Wは実行時指定。
## 状態を候補ごとにコピーせず、共通経路を探索木で共有する。stepによる複数ターン遷移に対応。
when not declared ThunderBeamCoreModule:
    const ThunderBeamCoreModule* = true
    import std/[hashes, deques, algorithm, monotimes]

    type
        BeamStatus* = enum
            beamFinished, beamMaxTurns, beamExhausted, beamTimeLimit
        BeamResult*[Action, Score] = object
            score*: Score
            actions*: seq[Action]
            turns*: int
            status*: BeamStatus
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
        BeamFrontier*[Action, Score, Key] = object
            selectors: Deque[BeamSelector[Action, Score, Key]]
            width, stepMax, remaining: int
            minimize: bool
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

    proc `[]`[T](pool: ObjectPool[T], i: int): T {.inline.} = pool.data[i]
    proc `[]`[T](pool: var ObjectPool[T], i: int): var T {.inline.} = pool.data[i]
    proc `[]=`[T](pool: var ObjectPool[T], i: int, value: T) {.inline.} = pool.data[i] = value

    proc initBeamHashMap[K](width: int): BeamHashMap[K] =
        var capacity = 16
        while capacity < width * 16: capacity *= 2
        result.keys = newSeq[K](capacity)
        result.values = newSeq[int](capacity)
        result.valid = newSeq[uint64]((capacity + 63) div 64)

    proc clear[K](m: var BeamHashMap[K]) =
        for word in m.valid.mitems: word = 0
        m.used = 0

    proc getIndex[K](m: BeamHashMap[K], key: K): tuple[found: bool, slot: int] {.inline.} =
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

    proc set[K](m: var BeamHashMap[K], slot: int, key: K, value: int) {.inline.} =
        let bit = 1'u64 shl (slot and 63)
        if (m.valid[slot shr 6] and bit) == 0:
            m.valid[slot shr 6] = m.valid[slot shr 6] or bit
            inc m.used
        m.keys[slot] = key
        m.values[slot] = value

    proc beamRebuildHash[A, S, K](s: BeamSelector[A, S, K]) =
        s.indices.clear()
        for i, c in s.candidates:
            let (_, slot) = s.indices.getIndex(c.key)
            s.indices.set(slot, c.key, i)

    proc beamBetter[S](a, b: S, minimize: bool): bool {.inline.} =
        if minimize: a < b else: b < a

    proc beamWorst[A, S, K](s: BeamSelector[A, S, K], a, b: int): int =
        if a < 0: return b
        if b < 0: return a
        if beamBetter(s.candidates[a].score, s.candidates[b].score, s.minimize): b else: a

    proc beamBuild[A, S, K](s: BeamSelector[A, S, K]) =
        s.size = 1
        while s.size < s.width: s.size *= 2
        s.worst.setLen(s.size * 2)
        for i in 0..<s.worst.len: s.worst[i] = -1
        for i in 0..<s.width: s.worst[s.size+i] = i
        for i in countdown(s.size-1, 1):
            s.worst[i] = s.beamWorst(s.worst[i*2], s.worst[i*2+1])

    proc beamUpdate[A, S, K](s: BeamSelector[A, S, K], index: int) =
        var p = (s.size + index) div 2
        while p > 0:
            s.worst[p] = s.beamWorst(s.worst[p*2], s.worst[p*2+1])
            p = p div 2

    proc beamResize[A, S, K](frontier: var BeamFrontier[A, S, K], width: int) =
        # 元コード同様、登録済み候補は削らずselectorの再利用時に反映する。
        frontier.width = width

    proc beamAdjustedWidth(current, minimum: int, totalWidth, elapsed, limit: float,
        remaining: int): int =
        if elapsed <= 0 or remaining <= 0: return current
        if elapsed >= limit: return minimum
        # 元コード: 累積幅 * (1 - 経過時間率) / 経過時間率 / 残りターン。
        let estimate = totalWidth * ((limit - elapsed) / elapsed) / float(remaining)
        if estimate >= float(current): return current
        if estimate <= float(minimum): return minimum
        int(estimate)

    proc beamPush[A, S, K](s: BeamSelector[A, S, K],
        candidate: BeamCandidate[A, S, K], finished: bool): bool =
        if finished:
            if not s.hasFinished:
                s.hasFinished = true
                s.finished = candidate
                return true
            return false
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

    proc push*[A, S, K](frontier: var BeamFrontier[A, S, K], action: A,
        score: S, key: K, parent: int, finished = false, step = 1): bool {.discardable.} =
        ## score/key/finishedは遷移後の値。stepは正のターン消費量。
        if step <= 0: raise newException(ValueError, "beam step must be positive")
        if step > frontier.remaining: return false
        while frontier.selectors.len < step:
            frontier.selectors.addLast(BeamSelector[A, S, K](
                width: frontier.width, minimize: frontier.minimize,
                candidates: newSeqOfCap[BeamCandidate[A, S, K]](frontier.width),
                indices: initBeamHashMap[K](frontier.width)))
        result = frontier.selectors[step-1].beamPush(
            BeamCandidate[A, S, K](action: action, score: score, key: key, parent: parent), finished)
        if result: frontier.stepMax = max(frontier.stepMax, step)

    proc beamAllocate[T, A](tree: var BeamTree[T, A], node: BeamNode[A]): int =
        if tree.nodes.garbage.len == 0:
            result = tree.nodes.data.len
            tree.nodes.data.add(node)
        else:
            result = tree.nodes.garbage.pop()
            tree.nodes[result] = node

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

    proc beamPrune[T, A](tree: var BeamTree[T, A]) =
        if tree.removals.len == 0: return
        var expired = tree.removals.popFirst()
        for v in expired:
            if tree.nodes[v].child < 0: tree.beamRemoveLeaf(v)
        expired.setLen(0)
        tree.removals.addLast(expired)

    proc beamUpdateRoot[T, A](tree: var BeamTree[T, A]) =
        mixin moveForward
        var child = tree.nodes[tree.root].child
        while child >= 0 and tree.nodes[child].right < 0 and
            tree.nodes[tree.root].retainedUntil < tree.turn:
            tree.root = child
            tree.state.moveForward(tree.nodes[child].action)
            child = tree.nodes[child].child

    proc beamMoveToLeaf[T, A](tree: var BeamTree[T, A], index: int): int =
        mixin moveForward
        var v = index
        var child = tree.nodes[v].child
        while child >= 0:
            while child >= 0 and not tree.nodes[child].active:
                child = tree.nodes[child].right
            doAssert child >= 0, "beam active subtree has no active child"
            tree.nodes[v].active = false
            v = child
            tree.state.moveForward(tree.nodes[v].action)
            child = tree.nodes[v].child
        tree.nodes[v].active = false
        v

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

    proc beamExpired(start: MonoTime, limit: float): bool {.inline.} =
        limit > 0 and float(getMonoTime().ticks - start.ticks) / 1e9 >= limit

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

    proc beamPath[T, A](tree: BeamTree[T, A], index: int): seq[A] =
        var v = index
        while tree.nodes[v].parent >= 0:
            result.add(tree.nodes[v].action)
            v = tree.nodes[v].parent
        result.reverse()

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

    proc runThunderBeam*[State, Action, Score, Key](initial: State, beamWidth: int,
        maxTurns = 2000, minimize = true, timeLimitSec = 0.0,
        minBeamWidth = 0, widthUpdateInterval = 256,
        stopOnTimeLimit = true): BeamResult[Action, Score] =
        mixin evaluate, isFinished
        if beamWidth <= 0: raise newException(ValueError, "beamWidth must be positive")
        if maxTurns < 0: raise newException(ValueError, "maxTurns must be nonnegative")
        if timeLimitSec < 0: raise newException(ValueError, "timeLimitSec must be nonnegative")
        if minBeamWidth < 0 or minBeamWidth > beamWidth:
            raise newException(ValueError, "minBeamWidth must be in 0..beamWidth")
        if widthUpdateInterval <= 0:
            raise newException(ValueError, "widthUpdateInterval must be positive")
        if minBeamWidth > 0 and timeLimitSec <= 0:
            raise newException(ValueError, "adaptive width requires timeLimitSec > 0")
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
        var frontier = BeamFrontier[Action, Score, Key](width: beamWidth, minimize: minimize)
        var totalWidth = 0.0
        for turn in 1..maxTurns:
            if minBeamWidth > 0 and turn mod widthUpdateInterval == 0 and turn < maxTurns:
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
            totalWidth += float((frontier.width + selector.candidates.len) div 2)
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
            if not pending:
                result.status = beamExhausted
                result.actions = tree.beamPath(tree.saved)
                return
            if stopOnTimeLimit and beamExpired(start, timeLimitSec):
                result.status = beamTimeLimit
                result.actions = tree.beamPath(tree.saved)
                return
        result.actions = tree.beamPath(tree.saved)

    template defineThunderBeam*(name, State, Action, Score, Key: untyped) =
        ## 問題ごとに一度定義すると name(initial, beamWidth, ...) で呼べる。
        proc name(initial: State, beamWidth: int, maxTurns = 2000,
            minimize = true, timeLimitSec = 0.0,
            minBeamWidth = 0, widthUpdateInterval = 256,
            stopOnTimeLimit = true): BeamResult[Action, Score] =
            runThunderBeam[State, Action, Score, Key](initial, beamWidth, maxTurns,
                minimize, timeLimitSec, minBeamWidth, widthUpdateInterval, stopOnTimeLimit)

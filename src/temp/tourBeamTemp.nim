
#[
nim cpp -r -d:release -d:is_local main.nim < in.txt > out.txt
nim cpp -r -d:debug -d:is_local main.nim < in.txt > out.txt
https://github.com/uta-kyopro/Nim
]#

{.hints:off checks:off warnings:off assertions:off optimization:speed.}
when defined(debug): {.checks:on.}
{.passC: "-O3 -march=native -mtune=native".}
# {.define: interactive.}

when not declared Importer:
    const Importer = true
    import std/[os, bitops, macros, hashes, typetraits,
                algorithm, sequtils, setutils, strformat, strutils,
                deques, heapqueue, options, sets, tables,
                monotimes, times, math, random, rationals]
    import atcoder/[dsu, scc,
                    fenwicktree, segtree, lazysegtree,
                    maxflow, mincostflow, twosat]
    import atcoder/string as acstring       #
    import atcoder/math as acmath           # pow_mod
    import atcoder/extra/math/divisor       # 約数列挙
    import atcoder/extra/math/eratosthenes  # 素数列挙
    macro ImportExpand(s:untyped):untyped = parseStmt($s)
    ImportExpand "#{.memoized.} \nproc memoize[A, B](f: proc(a: A): B): proc(a: A): B =\n  var cache = initTable[A, B]()\n  result = proc(a: A): B =\n    cache.withValue(a, value):\n      return value[]\n    result = f(a)\n    cache[a] = result\n\nproc getSignature(fun: NimNode): (NimNode, NimNode) =\n  result[0] = fun.params()[0]\n  result[1] = newTree(nnkArgList)\n  for i in 1 ..< fun.params.len:\n    let idents = fun.params[i]\n    let (typ, default) = (idents[^2], idents[^1])\n    for j in 0 ..< idents.len-2:\n      result[1].add(newTree(nnkIdentDefs, idents[j], typ, default))\n\nproc toIdents(args: NimNode): NimNode =\n  if args.len == 1:\n    result = args[0][0]\n  else:\n    result = newTree(nnkTupleConstr)\n    for arg in args:\n      result.add(arg[0])\n\nproc toTypes(args: NimNode): NimNode =\n  if args.len == 1:\n    result = args[0][1]\n  else:\n    result = newTree(nnkPar)\n    for arg in args:\n      result.add(arg[1])\n\ntype OwnedCache = object\n  sym: NimNode\n  decl: NimNode\n  reset: NimNode\n\nproc declCache(owner, argType, retType: NimNode): OwnedCache =\n  result.sym = genSym(nskVar, \"cache\")\n  template cacheImpl(cache, argType, retType) =\n    var cache = initTable[argType, retType]()\n  result.decl = getAst(cacheImpl(result.sym, argType, retType))\n  template declResetCache(cacheName, owner) =\n    template `resetCache owner`() =\n      cacheName.clear()\n  result.reset = getAst(declResetCache(result.sym, owner.name))\n\nproc declCacheNiladic(owner, argType, retType: NimNode): OwnedCache =\n  result.sym = genSym(nskVar, \"cache\")\n  template cacheImpl(cache, retType) =\n    var cache: Option[retType] = none(retType)\n  result.decl = getAst(cacheImpl(result.sym, retType))\n  template declResetCache(cacheName, owner, retType) =\n    template `resetCache owner`() =\n      cacheName = none(retType)\n  result.reset = getAst(declResetCache(result.sym, owner.name, retType))\n\nproc destructurizedCall(fun, args: NimNode): NimNode =\n  result = newCall(fun)\n  if args.kind != nnkTupleConstr:\n    result.add(args)\n  else:\n    for arg in args:\n      result.add(arg)\n\nproc destrTupNode(lhs, rhs: NimNode): NimNode =\n  if lhs.kind != nnkTupleConstr:\n    result = newLetStmt(lhs, rhs)\n  else:\n    var vartup = newNimNode(nnkVarTuple)\n    for nam in lhs:\n      vartup.add(nam)\n    vartup.add(newEmptyNode())\n    vartup.add(rhs)\n    result = newTree(nnkLetSection, vartup)\n\nmacro memoized*(e: untyped): auto =\n  let (retType, args) = getSignature(e)\n  let nams = args.toIdents()\n  let atyp = args.toTypes()\n  let hasArgs = args.len > 0\n  let cache = if hasArgs:\n    declCache(e, atyp, retType)\n  else:\n    declCacheNiladic(e, atyp, retType)\n  let mem = newProc(name = genSym(nskProc, \"memoized\"))\n  mem.params = newNimNode(nnkFormalParams).add(e.params[0])\n  let org = e.copy()\n  org.name = genSym(nskProc, \"impl\")\n  mem.body = newStmtList().add(org)\n  if hasArgs:\n    let argSym = genSym(nskParam, \"arg\")\n    mem.params.add(newTree(nnkIdentDefs, argSym, atyp, newEmptyNode()))\n    let darg = nams.destrTupNode(argSym)\n    let dcall = org.name.destructurizedCall(nams)\n    mem.body.add(darg).add(newAssignment(ident(\"result\"), dcall))\n  else:\n    mem.body.add(newAssignment(ident(\"result\"), newCall(org.name)))\n  let fun = newProc(name = e.name)\n  fun.params = e.params.copy\n  template funImpl(impl, cache, fun, lhs, rhs) =\n    impl\n    let lhs = rhs\n    cache.withValue(lhs, value):\n      return value[]\n    let computed = fun(lhs)\n    cache[lhs] = computed\n    return computed\n  template funImplNiladic(impl, cache, fun) =\n    impl\n    if options.isNone(cache):\n      cache = some(fun())\n  if hasArgs:\n    let packSym = genSym(nskLet, \"pack\")\n    fun.body = getAst(funImpl(mem, cache.sym, mem.name, packSym, nams))\n  else:\n    fun.body = getAst(funImplNiladic(mem, cache.sym, mem.name))\n    fun.body.add(newAssignment(ident(\"result\"), newCall(ident(\"get\"), cache.sym)))\n  result = newStmtList(cache.decl, fun, cache.reset)\nexport tables.`[]=`, tables.`[]`, options.`get`"
when not declared InputHelper:
    const InputHelper = true
    const ICAP = 64 shl 20
    var ibuf: array[ICAP+64, char]
    var ip, ilen = 0
    when defined(windows):
        proc cRead(fd: cint, p: pointer, n: cuint): cint {.importc:"_read", header:"<io.h>".}
        template fastRead(p, n): int = int(cRead(0, p, cuint(n)))
    else:
        proc cRead(fd: cint, p: pointer, n: csize_t): int {.importc:"read", header:"<unistd.h>".}
        template fastRead(p, n): int = cRead(0, p, csize_t(n))
    proc refill(): bool =
        when defined(interactive):
            ip = 0
            ilen = 0
        else:
            if ilen >= ICAP: return false
        let n = fastRead(addr ibuf[ilen], ICAP-ilen)
        if n <= 0: return false
        ilen += n; return true
    when defined(interactive):
        template need() =
            if ip >= ilen: discard refill()
        template skip() =
            while true:
                need()
                if ibuf[ip] > ' ': break
                inc ip
    else:
        var inputLoaded = false
        proc loadInput() =
            if inputLoaded: return
            while refill(): discard
            inputLoaded = true
        template need() = discard
        template skip() =
            loadInput()
            while ibuf[ip] <= ' ': inc ip
    proc nxtInt[T: SomeInteger](): T =
        skip()
        let neg = ibuf[ip] == '-'
        ip += ord(neg)
        while true:
            need()
            let d = ord(ibuf[ip])-48
            if d.uint > 9: break
            result = result*10 + T(d)
            inc ip
        if neg: result = -result
    proc nxtStr(): string =
        skip(); let l = ip
        while true:
            need()
            if ibuf[ip] <= ' ': break
            inc ip
        result = newString(ip-l)
        copyMem(addr result[0], addr ibuf[l], ip-l)
    proc nxtChar(): char = skip(); result = ibuf[ip]; inc ip
    proc nxtFloat[T: SomeFloat](): T = T(nxtStr().parseFloat)
    template input(t: typedesc[string]): string = nxtStr()
    template input(t: typedesc[char]): char = nxtChar()
    template input(t: typedesc[SomeInteger]): SomeInteger = nxtInt[t]()
    template input(t: typedesc[SomeFloat]): SomeFloat = nxtFloat[t]()
    template input(t: typedesc, n: int): seq[t] = newSeqWith(n, input(t))
    template input(t: typedesc, n, m: int): seq[seq[t]] = newSeqWith(n, input(t, m))
    macro input(ts: varargs[auto]): untyped = parseExpr("(" & ts.toSeq.mapIt("input(" & it.repr & "),").join & ")")
    template input(n: int, ts: varargs[auto]): untyped = newSeqWith(n, input(ts))
when not declared OutputHelper:
    const OutputHelper = true
    template print[T](x: varargs[T, `$`]) = stdout.writeLine x
    template flush() = stdout.flushFile()
    when defined(is_local):
        template debug[T](x: varargs[T, `$`]) = stderr.writeLine x
    else:
        template debug[T](x: varargs[T, `$`]) = discard
when not declared UserOperator:
    const UserOperator = true
    template pass: untyped = discard
    proc chmax[T](x: var T, y: T): bool = (if x < y: (x = y; return true;) return false)
    proc chmin[T](x: var T, y: T): bool = (if x > y: (x = y; return true;) return false)
    proc `max=`[T](x: var T, y: T) = (if x < y: x = y)  # 最大値代入
    proc `min=`[T](x: var T, y: T) = (if x > y: x = y)  # 最小値代入
    proc `**`(x: SomeInteger, y: Natural): SomeInteger = x ^ y  # 整数累乗
    proc `**=`(x: var SomeInteger, y: Natural) = x = x ^ y      # 整数累乗
    proc `%`[T: SomeInteger](x, y: T): T =
        result = x mod y
        when T is SomeSignedInt:
            if result != 0 and ((result < 0) != (y < 0)):
                result += y
    proc `%=`[T: SomeInteger](x: var T, y: T) = x = x % y
    proc `//`[T: SomeInteger](x, y: T): T =
        result = x div y
        when T is SomeSignedInt:
            let remainder = x mod y
            if remainder != 0 and ((remainder < 0) != (y < 0)):
                result.dec
    proc `//=`[T: SomeInteger](x: var T, y: T) = x = x // y # 負の無限大方向への丸め
    proc `>>`(x: SomeInteger, y: int): SomeInteger = x shr y
    proc `<<`(x: SomeInteger, y: int): SomeInteger = x shl y
    proc `>>=`(x: var SomeInteger, y: int) = x = (x shr y)
    proc `<<=`(x: var SomeInteger, y: int) = x = (x shl y)
    proc `|`(a, b: bool): bool = a or b
    proc `|=`(a: var bool, b: bool) = a = (a or b)
    proc `|`(a, b: SomeInteger): SomeInteger = a or b
    proc `|=`(a: var SomeInteger, b: SomeInteger) = a = (a or b)
    proc `&`(a, b: bool): bool = a and b
    proc `&=`(a: var bool, b: bool) = a = (a and b)
    proc `&`(a, b: SomeInteger): SomeInteger = a and b
    proc `&=`(a: var SomeInteger, b: SomeInteger) = a = (a and b)
    proc `^`(x, y: bool): bool = x xor y    # ^ をxorに再定義
    proc `^=`(x: var bool, y: bool) = x = (x xor y)
    proc `^`(x, y: SomeInteger): SomeInteger = x xor y
    proc `^=`(x: var SomeInteger, y: SomeInteger) = x = (x xor y)
    proc pop[T](s: var seq[T]): T {.noSideEffect, discardable.} = system.pop(s)
    proc initHashSet[T]():Hashset[T] = initHashSet[T](0)
    proc clear[T](self:var Hashset[T]) = self = initHashSet[T](0)
when not declared SortedTreeUtil:
    const SortedTreeUtil = true
    import atcoder/extra/structure/set_map except items
    template `[]`[T: SomeSortedTree](self:var T, k: int) =
        *self.kth_element(k)
    template lowerBoundIndex[T: SomeSortedTree](self:var T, x: T.K) =
        self.lower_bound(x).index
    template upperBoundIndex[T: SomeSortedTree](self:var T, x: T.K) =
        self.upper_bound(x).index
when not declared ModIntdeclaration:
    const ModIntdeclaration = true
    import atcoder/modint, atcoder/extra/math/combination
    type mint = modint998244353
    # type mint = modint1000000007
    # var cmb: Combination[mint]
when not declared TimeModule:   # プログラムの実行時間を計測するライブラリ
    const TimeModule = true
    type Timer = object
        start: int64
    proc initTimer(): Timer =
        result.start = getMonoTime().ticks()
    proc reset(self: var Timer) =
        self.start = getMonoTime().ticks()
    proc getTime(self: Timer): float =
        return (getMonoTime().ticks()-self.start).float/1000_000_000.0
    proc getTime_ns(self: Timer): int =
        return cast[int](getMonoTime().ticks()-self.start)
    template elapsedNs(self: Timer): int64 =
        int64(self.getTime_ns())
    template elapsedSec(self: Timer): float =
        self.getTime()
    proc ratio(self: Timer, timeLimitSec: float): float =
        self.getTime() / timeLimitSec
    template expired(self: Timer, timeLimitSec: float): bool =
        self.getTime() >= timeLimitSec
    var timer = initTimer()
when not declared HeaderConstants:
    const HeaderConstants = true
    const inf = int.high // 2
    const dyx = @[(-1, 0), (0, 1), (1, 0), (0, -1)]
    const dyx8 = @[(-1, 0), (0, 1), (1, 0), (0, -1), (-1, -1), (-1, 1), (1, -1), (1, 1)]
    const MOD = 998244353
    # const MOD = 10**9 + 7
    const ascii_lower = "abcdefghijklmnoselfrstuvwxyz"
    const ascii_upper = "ABCDEFGHIJKLMNOselfRSTUVWXYZ"

# -------------------------------------------------------------------
# input
# -------------------------------------------------------------------
let N = input(int)


# -------------------------------------------------------------------
# parameter
# -------------------------------------------------------------------
let beamWidth = 100
let maxTurns = 1000

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

# -------------------------------------------------------------------
# TourBeamCoreModule 1ターン遷移専用のビームサーチライブラリ(編集しない)
# -------------------------------------------------------------------
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

# -------------------------------------------------------------------
# TourBeamModule 1ターン遷移専用のビームサーチライブラリ(ユーザー編集範囲)
# -------------------------------------------------------------------
when not declared TourBeamModule:
    const TourBeamModule* = true

    type
        # scoreは符号付き48bit範囲（-2^47..2^47-1）に収める。中間計算はintでよい。
        # 通常の整数選抜は幅65,536まで。範囲外への自動切り替えは行わず、debug時だけ確認する。
        CostType* = int
        HashType* = uint64
        LeafData* = object # TODO: 葉ごとに保存し、巡回中の更新を省きたい情報をまとめる。
            score*: CostType
            hash*: HashType
        Action* = object # TODO: 1回の遷移と巻き戻しに必要な情報を入れる。
        State* = object # TODO: 盤面・差分計算用の情報を追加する。
            score*: CostType # TODO: 初期化し、適用・巻き戻しで差分更新する。
            hash*: HashType # TODO: 初期化し、適用・巻き戻しで差分更新する。
            isFinished*: bool # TODO: 完了時にtrue。固定ターン探索はfalseのままでよい。
        Frontier* = TourBeamFrontier[Action, CostType, HashType, LeafData]

    # 保持している評価値を返す。必要なら評価式へ書き換える。
    template evaluate*(self: State): CostType = self.score

    # TODO: 将来の遷移に影響する状態を反映したHashを返す（既定はself.hash）。
    template getHash*(self: State): HashType = self.hash

    # 候補の試算：moveForward → evaluate/getHash/getLeaf → moveBackward。
    # 採用候補への移動：共通祖先までmoveBoardBackward → moveBoardForward → loadLeaf → expand。
    # TODO: 候補の試算と最終Action列の再生に使う。盤面・評価値・Hash・補助情報・isFinishedを全て更新する。
    proc moveForward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveForward")

    # TODO: 候補の試算を取り消し、moveForwardが変更した全情報を元に戻す。
    proc moveBackward*(self: var State, action: Action) =
        raise newException(ValueError, "implement moveBackward")

    # Board付きの2関数は任意。どちらも定義しなければ通常のmoveForward/moveBackwardで移動する。
    # TODO: 採用候補へ移動するため、盤面・巻き戻し履歴・isFinishedを更新する。
    # loadLeafで上書きする評価値・Hash・補助情報の更新は省略できる。省略した値を巡回処理から参照しない。
    proc moveBoardForward*(self: var State, action: Action) =
        self.moveForward(action) # まずはこのままでよい。高速化する場合だけ保存値の更新を省く。

    # TODO: 採用候補間を戻るため、moveBoardForwardが更新する盤面・履歴・isFinishedを元に戻す。
    proc moveBoardBackward*(self: var State, action: Action) =
        self.moveBackward(action) # forward側と同じ保存値の更新を省く。

    # 葉への保存は巡回中の差分計算を省く一方、候補の保存・コピー量を増やす。
    # 軽い加減算は差分更新が速い場合もあるため、保存する情報は実測で判断する。
    # TODO: 遷移後のStateから保存したい値を返す。評価値と異なる実コストなども追加できる。
    template getLeaf*(self: State): LeafData =
        LeafData(score: self.score, hash: self.hash)

    # TODO: getLeafで保存した値をStateへ戻す。盤面・履歴は巡回処理が復元する。
    template loadLeaf*(self: var State, leaf: LeafData) =
        self.score = leaf.score
        self.hash = leaf.hash

    # TODO: 合法なActionを列挙してself.pushCandidateで登録し、終了時のStateを元に戻す。
    proc expand*(self: var State, frontier: var Frontier) =
        # self.pushCandidate(frontier, action)
        # バケット化する場合は self.pushCandidate(frontier, action, group = groupId)
        raise newException(ValueError, "implement expand")

    # 編集不要：初期Stateと探索条件をcoreに渡し、最良の行動列を返す。
    template tourBeam*(initial: State, beamWidth: int, maxTurns = 2000,
            minimize = true, groupLimit = 0, groupCount = 0, groupLocalHash = false): TourBeamResult[Action, CostType] =
        runTourBeam[State, Action, CostType, HashType, LeafData](initial, beamWidth,
            maxTurns, minimize, groupLimit, groupCount, groupLocalHash)


# -------------------------------------------------------------------
type Solver = object



proc prepare(self:var Solver) =
    pass


proc solve(self:var Solver) =
    pass
    # let answer = tourBeam(initialState, beamWidth = 1000, maxTurns = 100)
    # echo answer.score
    # echo answer.actions

# -------------------------------------------------------------------
proc output(self:var Solver) =
    # stdout.writeLine ""
    pass

# -------------------------------------------------------------------
# main
# -------------------------------------------------------------------
proc main() =
    var solver = Solver()
    solver.prepare()
    solver.solve()
    solver.output()
    debug ""
    debug fmt"{timer.getTime}"

main()




# nim cpp -r -d:danger --mm:arc -d:isLocal thunder_beam.nim < in.txt > out.txt
# nim cpp -r -d:release -d:isLocal thunder_beam.nim < in.txt > out.txt
# nim cpp -r -d:debug -d:isLocal thunder_beam.nim < in.txt > out.txt
when not defined(debug): {.hints:off checks:off warnings:off assertions:off optimization:speed.}
when defined(debug): {.hints:off checks:on warnings:off assertions:off optimization:speed.}
# {.passC: "-O3 -march=native".}
{.passC: "-Ofast -march=native -flto -ffast-math".}


when not declared Importer:
    import std/[os, bitops, macros, hashes, 
        algorithm, sequtils, setutils, strformat, strutils,
        deques, heapqueue, options, sets, tables,
        monotimes, times, math, random, rationals]

    import atcoder/math as atmath, atcoder/string as atstr
    import atcoder/dsu, atcoder/scc
    import atcoder/maxflow, atcoder/mincostflow
    import atcoder/fenwicktree, atcoder/segtree, atcoder/lazysegtree
    macro ImportExpand(s:untyped):untyped = parseStmt($s)
    ImportExpand "#{.memoized.} \nproc memoize[A, B](f: proc(a: A): B): proc(a: A): B =\n  var cache = initTable[A, B]()\n  result = proc(a: A): B =\n    if cache.hasKey(a):\n      result = cache[a]\n    else:\n      result = f(a)\n      cache[a] = result\n\nproc getSignature(fun: NimNode): (NimNode, NimNode) =\n  result[0] = fun.params()[0]\n  result[1] = newTree(nnkArgList)\n  for i in 1 ..< fun.params.len:\n    let idents = fun.params[i]\n    let (typ, default) = (idents[^2], idents[^1])\n    for j in 0 ..< idents.len-2:\n      result[1].add(newTree(nnkIdentDefs, idents[j], typ, default))\n\nproc toIdents(args: NimNode): NimNode =\n  if args.len == 1:\n    result = args[0][0]\n  else:\n    result = newTree(nnkPar)\n    for arg in args:\n      result.add(arg[0])\n\nproc toTypes(args: NimNode): NimNode =\n  if args.len == 1:\n    result = args[0][1]\n  else:\n    result = newTree(nnkPar)\n    for arg in args:\n      result.add(arg[1])\n\ntype OwnedCache = object\n  sym: NimNode\n  decl: NimNode\n  reset: NimNode\n\nproc declCache(owner, argType, retType: NimNode): OwnedCache =\n  result.sym = genSym(nskVar, \"cache\")\n  template cacheImpl(cache, argType, retType) =\n    var cache = initTable[argType, retType]()\n  result.decl = getAst(cacheImpl(result.sym, argType, retType))\n  template declResetCache(cacheName, owner) =\n    template `resetCache owner`() =\n      cacheName.clear()\n  result.reset = getAst(declResetCache(result.sym, owner.name))\n\nproc declCacheNiladic(owner, argType, retType: NimNode): OwnedCache =\n  result.sym = genSym(nskVar, \"cache\")\n  template cacheImpl(cache, retType) =\n    var cache: Option[retType] = none(retType)\n  result.decl = getAst(cacheImpl(result.sym, retType))\n  template declResetCache(cacheName, owner, retType) =\n    template `resetCache owner`() =\n      cacheName = none(retType)\n  result.reset = getAst(declResetCache(result.sym, owner.name, retType))\n\nproc destructurizedCall(fun, args: NimNode): NimNode =\n  result = newCall(fun)\n  if args.kind != nnkPar:\n    result.add(args)\n  else:\n    for arg in args:\n      result.add(arg)\n\nproc destrTupNode(lhs, rhs: NimNode): NimNode =\n  if lhs.kind != nnkPar:\n    result = newLetStmt(lhs, rhs)\n  else:\n    var vartup = newNimNode(nnkVarTuple)\n    for nam in lhs:\n      vartup.add(nam)\n    vartup.add(newEmptyNode())\n    vartup.add(rhs)\n    result = newTree(nnkLetSection, vartup)\n\nmacro memoized*(e: untyped): auto =\n  let (retType, args) = getSignature(e)\n  let nams = args.toIdents()\n  let atyp = args.toTypes()\n  let hasArgs = args.len > 0\n  let cache = if hasArgs:\n    declCache(e, atyp, retType)\n  else:\n    declCacheNiladic(e, atyp, retType)\n  let mem = newProc(name = genSym(nskProc, \"memoized\"))\n  mem.params = newNimNode(nnkFormalParams).add(e.params[0])\n  let org = e.copy()\n  org.name = genSym(nskProc, \"impl\")\n  mem.body = newStmtList().add(org)\n  if hasArgs:\n    let argSym = genSym(nskParam, \"arg\")\n    mem.params.add(newTree(nnkIdentDefs, argSym, atyp, newEmptyNode()))\n    let darg = nams.destrTupNode(argSym)\n    let dcall = org.name.destructurizedCall(nams)\n    mem.body.add(darg).add(newAssignment(ident(\"result\"), dcall))\n  else:\n    mem.body.add(newAssignment(ident(\"result\"), newCall(org.name)))\n  let fun = newProc(name = e.name)\n  fun.params = e.params.copy\n  template funImpl(impl, cache, fun, lhs, rhs) =\n    impl\n    let lhs = rhs\n    if not cache.hasKey(lhs):\n      cache[lhs] = fun(lhs)\n  template funImplNiladic(impl, cache, fun) =\n    impl\n    if options.isNone(cache):\n      cache = some(fun())\n  if hasArgs:\n    let packSym = genSym(nskLet, \"pack\")\n    fun.body = getAst(funImpl(mem, cache.sym, mem.name, packSym, nams))\n    fun.body.add(newAssignment(ident(\"result\"), newCall(ident(\"[]\"), cache.sym, nams)))\n  else:\n    fun.body = getAst(funImplNiladic(mem, cache.sym, mem.name))\n    fun.body.add(newAssignment(ident(\"result\"), newCall(ident(\"get\"), cache.sym)))\n  result = newStmtList(cache.decl, fun, cache.reset)\nexport tables.`[]=`, tables.`[]`, options.`get`"
when not declared InputHelper:
    let readNext = iterator(getsChar: bool = false): string {.closure.} =
        while true:
            for s in stdin.readLine.splitWhitespace:
                if getsChar: 
                    for c in s: 
                        yield $c
                else: 
                    yield s
    template input(t: typedesc[string]): string = readNext()
    template input(t: typedesc[char]): char = readNext(true)[0]
    template input(t: typedesc[SomeInteger]): SomeInteger = readNext().parseInt.t
    template input(t: typedesc[SomeFloat]): SomeFloat = readNext().parseFloat.t
    template input(t: typedesc, n: int): seq[t] = # seq[type]
        newSeqWith(n, input(t))
    template input(t: typedesc, n1, n2: int): seq[seq[t]] = # seq[seq[type]]
        newSeqWith(n1, newSeqWith(n2, input(t)))
    macro input(ts: varargs[auto]): untyped =   # tuple
        let tupStr = ts.toSeq.mapIt(&"input({it.repr}),").join
        parseExpr(&"({tupStr})")
    template input(n: int, ts: varargs[auto]): untyped =    # seq[tuple]
        newSeqWith(n, input(ts))
when not declared OutputHelper:
    template print[T](x: varargs[T, `$`]) = stdout.writeLine x
    template flush() = stdout.flushFile()
    when defined(debug):
        template debug[T](x: varargs[T, `$`]) = stderr.writeLine x
    else:   
        template debug[T](x: varargs[T, `$`]) = discard
when not declared UserOperator:
    template pass: untyped = discard
    proc chmax[T](x: var T, y: T): bool = (if x < y: (x = y; return true;) return false)
    proc chmin[T](x: var T, y: T): bool = (if x > y: (x = y; return true;) return false)
    proc `max=`[T](x: var T, y: T) = (if x < y: x = y)  # 最大値代入
    proc `min=`[T](x: var T, y: T) = (if x > y: x = y)  # 最小値代入
    proc `**`(x: SomeInteger, y: Natural): SomeInteger = x ^ y  # 整数累乗
    proc `**=`(x: var SomeInteger, y: Natural) = x = x ^ y      # 整数累乗
    proc `%`(x: SomeInteger, y: SomeInteger): SomeInteger = (((x mod y) + y) mod y)
    proc `%=`(x: var SomeInteger, y: SomeInteger) = x = x % y
    proc `//`(x: SomeInteger, y: SomeInteger): SomeInteger = ((x - (x%y)) div y)
    proc `//=`(x: var SomeInteger, y: SomeInteger) = x = x // y # 負の無限大方向への丸め
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
    proc pop[T](s: var seq[T]): T {.inline, noSideEffect, discardable.} =
        let L = s.len-1; result = s[L]; setLen(s, L)
    proc initHashSet[T]():Hashset[T] = initHashSet[T](0)
    proc clear[T](self:var Hashset[T]) = self = initHashSet[T](0)
when not declared Header:
    const inf = int.high // 2
    # const dyx4 = @[(-1, 0), (0, 1), (1, 0), (0, -1)]  # for (dy, dx) in dyx:
    # const dyx8 = @[(-1, 0), (0, 1), (1, 0), (0, -1), (-1, -1), (-1, 1), (1, -1), (1, 1)]
        
    template toInt8(v: SomeInteger): int8 = (cast[int8](v))
    template toInt16(v: SomeInteger): int16 = (cast[int16](v))
    template toInt32(v: SomeInteger): int32 = (cast[int32](v))
    template toUint8(v: SomeInteger): uint8 = (cast[uint8](v))
    template toUint16(v: SomeInteger): uint16 = (cast[uint16](v))
    template toUint32(v: SomeInteger): uint32 = (cast[uint32](v))

    # var rng {.compileTime.} = initRand(0x1337DEADBEEF)
    # const logList = newSeqWith(0x10000, ln(rng.rand(1.0)))   # 1048576

let local = defined(isLocal)
when not defined(second_compile) and not defined(isLocal):
    # const tmp = staticExec("nim cpp -d:release -o:a.out -d:second_compile Main.nim")
    const tmp = staticExec("nim cpp -d:danger --mm:orc -o:a.out -d:second_compile Main.nim")
    static:
        echo tmp
        quit()

when not declared TimeModule:
    # プログラムの実行時間を計測するライブラリ
    # インクルードした時点から計測が開始されるため、
    # timer.getTime()を呼べば現時点の実行時間がわかる
    type Timer = object
        start: int64
    proc initTimer(): Timer= result.start = getMonoTime().ticks()
    proc getTime(self:var Timer): float = 
        return (getMonoTime().ticks()-self.start).float/1000_000_000.0
    proc getTime_ns(self:var Timer): int = 
        return cast[int](getMonoTime().ticks()-self.start)
    var timer = initTimer()

# seqと同等に扱える固定長stack
when not declared StackModule:
    type Stack*[N:static[int], T] = object
        len: int
        data: array[N, T]

    proc initStack*[N:static[int], T](): Stack[N, T] = discard
    proc `[]`*[N:static[int], T](self:var Stack[N, T], i: Natural): var T = (self.data[i])
    proc `[]=`*[N:static[int], T](self:var Stack[N, T], i: Natural, value: T) = (self.data[i]=value)
    proc `[]`*[N:static[int], T](self:var Stack[N, T], i: BackwardsIndex): var T = (self.data[self.len-int(i)])
    proc `[]=`*[N:static[int], T](self:var Stack[N, T], i: BackwardsIndex, value: T) = (self.data[self.len-int(i)]=value)
    proc add*[N:static[int], T](self:var Stack[N, T], value: T) =
        self.data[self.len] = value
        inc(self.len)
    proc push*[N:static[int], T](self:var Stack[N, T], value: T) = self.add(value)
    proc pop*[N:static[int], T](self:var Stack[N, T]):T {.discardable.}=
        dec(self.len)
        self.data[self.len]
    template clear*[N:static[int], T](self:var Stack[N, T]) = (self.len = 0)
    iterator items[N:static[int], T](self:var Stack[N, T]): T =
        var i = 0
        while i < self.len:
            yield self.data[i]
            i.inc

when not declared BitSetModule:
    const BitWidth = 64
    const BitWidthLog2 = 6
    const MaxBitSetSize = (1 << 16)
    const memoBitDivMod = (0..MaxBitSetSize).toSeq().mapIt((it>>BitWidthLog2, it&(BitWidth-1)))

    type BitSet[N: static[int]] = object
        data: array[(N+BitWidth-1)>>BitWidthLog2, uint64]
    proc initBitSet(N: static[int]): BitSet[N]= discard
    proc initBitSet0(N: static[int]): BitSet[N]= discard
    proc initBitSet1(N: static[int]): BitSet[N]= result.data.fill(uint64.high)
    proc clear(b:var BitSet)= b.data.fill(uint64(0))
    proc `[]`(b:var BitSet, n: SomeInteger): bool =
        let (q, r) = memoBitDivMod[n]
        return b.data[q].testBit(r)
    proc `[]=`(b:var BitSet, n: SomeInteger, t: int) =
        let (q, r) = memoBitDivMod[n]
        if t==0: b.data[q].clearBit(r)
        elif t==1: b.data[q].setBit(r)
    proc `[]=`(b:var BitSet, n: SomeInteger, t: bool) =
        let (q, r) = memoBitDivMod[n]
        if t: b.data[q].setBit(r)
        else: b.data[q].clearBit(r)

# -------------------------------------------------------------------
# input
# -------------------------------------------------------------------
const N = 30
const M = N*(N+1)//2
var B: seq[seq[int]]
for i in 1..N:
    B.add(input(int, i))
    
# var targetCoefficient: int
# var horizontalCost: int
# if local:
#     targetCoefficient = getEnv("rate1", fmt"{targetCoefficient}").parseInt
#     horizontalCost = getEnv("rate2", fmt"{horizontalCost}").parseInt

# -------------------------------------------------------------------
# parameter
# -------------------------------------------------------------------
const targetCoefficient = 600
const horizontalCost = 10

# -------------------------------------------------------------------
# config
# -------------------------------------------------------------------
const timeLimit = 1.95
const maxTurn = 2000
const maxBeamWidth = 3000
const minBeamWidth = 1000
var beamWidth = maxBeamWidth
const nodesCapacity = maxBeamWidth*4
const hashMapCapacity = (1 << 16) # 0x10000, 65536
const hashMapMask = hashMapCapacity-1
const hashMapRebuildThreshold = hashMapCapacity*7//10

# ビームサーチライブラリのType宣言(ユーザー編集)
when not declared UserTypeModule:
    type HashType = int
    type CostType = int

    # 状態遷移を行うために必要な情報
    # メモリ使用量をできるだけ小さくしてください
    type Action = int

    # 深さ優先探索に沿って更新する情報をまとめたクラス
    type State = object
        targetBall, potential: int
        hash: HashType
        b: array[N, array[N, int]]
        pos: array[M, (int, int)]
        targetBallHistory: Stack[maxBeamWidth, int]
        hashHistory: Stack[maxBeamWidth, HashType]

# ビームサーチライブラリのType宣言
when not declared TypeModule:
    import atcoder/segtree
        
    type ObjectPool[T] = object
        data: seq[T]
        garbage: seq[int]
        
    type HashMap[T] = object
        valid: BitSet[hashMapCapacity]
        data: array[hashMapCapacity, (int, T)]
        used: int
        
    # 展開するノードの候補を表す構造体
    type Candidate = object
        action: Action
        hash: HashType
        parent: int
        cost: CostType
        
    proc opMaxSegTree(a, b: (CostType, int)): (CostType, int) =
        if a[0] >= b[0]: return a
        else: return b
    proc eMaxSegTree(): (CostType, int) = (-inf, -1)
    type MaxSegTreeType = SegTreeType[(CostType, int)](opMaxSegTree, eMaxSegTree)

    type Selector = ref object
        beamWidth: int                      # ビーム幅
        candidates: Stack[maxBeamWidth, Candidate]          # 次の状態の候補リスト(ビーム幅まで保持)
        hash2index: HashMap[int]            # ハッシュ値からindexへ置き換える
        full: bool                          # セグ木を生成したか
        costs: seq[(CostType, int)]
        finishedCandidates: seq[Candidate]  # 完了状態になった候補リスト
        maxSegTree: MaxSegTreeType          # コストが高い盤面を調べる

    type MulutiSelector = object
        selectors: Deque[Selector]      # nターン先の行動まで管理
        stepMax: int

    type Node = object  # 探索木（二重連鎖木）のノード
        action: Action
        cost: CostType
        hash: HashType
        parent, child, left, right: int
        active: bool
        
    type Tree = object      # 探索木（二重連鎖木）
        state: State    # 遷移する盤面
        nodes: ObjectPool[Node]
        root: int
        removeNodes: Deque[seq[int]]

# -------------------------------------------------------------------
# util
# -------------------------------------------------------------------
# ユーザー関数
when not declared UserModule:
    
    template getPyramidIndex(y, x: int): int = 
        (y * (y+1) // 2 + x)
    const hashMask = ((1<<23)-1)<<9
    template updateTargetPosition(hash: HashType, y, x: int): HashType =
        ((hash & hashMask) | getPyramidIndex(y, x))
    proc updateSortedPosition(hash: HashType, y, x: int): HashType =
        var zobristHash = getPyramidIndex(y, x)
        zobristHash |= 0x200    # 512 (10bit)
        zobristHash *= zobristHash
        zobristHash *= zobristHash
        return hash ^ (zobristHash & hashMask)

    # proc initAction(y1, x1, y2, x2, y3, x3: int): Action =
    #     result = ( y1 | (x1 << 8) |
    #         (y2 << 16) | (x2 << 24) |
    #         (y3 << 32) | (x3 << 40))
    template initAction(y1, x1, y2, x2, y3, x3: int): Action =
        ( y1 | (x1 << 8) |
        (y2 << 16) | (x2 << 24) |
        (y3 << 32) | (x3 << 40))

    # proc decode(self: Action, y1, x1, y2, x2, y3, x3:var int) =
    template decode(self: Action) =
        y1 = self & 0xFF
        x1 = (self >> 8) & 0xFF
        y2 = (self >> 16) & 0xFF
        x2 = (self >> 24) & 0xFF
        y3 = (self >> 32) & 0xFF
        x3 = (self >> 40) & 0xFF

    template canMoveLeft(self: State, y, x: int): bool =
        ((x > 0) and (self.b[y-1][x-1] > self.b[y][x]))

    template canMoveRight(self: State, y, x: int): bool =
        ((x < y) and (self.b[y-1][x] > self.b[y][x]))

    proc updateTargetBall(self:var State, targetBall: int, h: HashType): (int, HashType) =
        var hash = h
        var ball = targetBall
        # for ball in targetBall..<M:
        while ball < M:
            let (y, x) = self.pos[ball]
            if self.canMoveLeft(y, x) or self.canMoveRight(y, x):
                hash = updateTargetPosition(hash, y, x)
                return (ball, hash)
            hash = updateSortedPosition(hash, y, x)
            ball += 1
        return (M, hash)

    proc swapBalls(self:var State, y1, x1, y2, x2: int) =
        let b1 = self.b[y1][x1]
        let b2 = self.b[y2][x2]
        swap(self.b[y1][x1], self.b[y2][x2])
        swap(self.pos[b1], self.pos[b2])

# -------------------------------------------------------------------
# Beam Search Library
# -------------------------------------------------------------------
# ユーザーが編集する関数
when not declared UserBeamSearchModule:
    # 初期状態の定義
    proc initState(): State =
        var self = State()

        for y in 0..<N:
            for x in 0..y:
                self.b[y][x] = B[y][x]
                self.pos[B[y][x]] = (y, x)

        let (ball, hash) = self.updateTargetBall(0, 0)
        self.targetBall = ball

        return self
    
    # 盤面評価関数
    template evaluate(self:var State): CostType =
        (self.potential - targetCoefficient*self.targetBall)

    # actionを実行して次の状態に遷移する
    proc moveForward(self:var State, action: Action) =
        self.hashHistory.add(self.hash)
        self.targetBallHistory.add(self.targetBall)

        var y1, x1, y2, x2, y3, x3: int
        # action.decode(y1, x1, y2, x2, y3, x3)
        action.decode()

        if y1!=y2:
            self.potential += self.b[y1][x1] - self.b[y2][x2]
        else:
            self.potential -= horizontalCost

        self.swapBalls(y1, x1, y2, x2)
        if x3 < N:
            self.potential += self.b[y3][x3] - self.b[y1][x1]
            self.swapBalls(y1, x1, y3, x3)

        (self.targetBall, self.hash) = self.updateTargetBall(
            self.targetBall, self.hash)

    # actionを実行する前の状態に遷移する
    # 今の状態は、親からactionを実行して遷移した状態である
    proc moveBackward(self:var State, action: Action) =
        var y1, x1, y2, x2, y3, x3: int
        # action.decode(y1, x1, y2, x2, y3, x3)
        action.decode()

        if x3 < N:
            self.swapBalls(y1, x1, y3, x3)
            self.potential -= self.b[y3][x3] - self.b[y1][x1]
        self.swapBalls(y1, x1, y2, x2)
        if y1!=y2:
            self.potential -= self.b[y1][x1] - self.b[y2][x2]
        else:
            self.potential += horizontalCost

        self.hash = self.hashHistory.pop()
        self.targetBall = self.targetBallHistory.pop()

    # 次の状態候補を全てselectorに追加する
    proc push(self:var MulutiSelector, action: Action, cost: CostType, hash: HashType, parent: int, finished: bool, step: int): bool {.discardable.}
    proc expand(self:var State, parent: int, multiSelector:var MulutiSelector) =
        proc push2(self:var State, parent: int, multiSelector:var MulutiSelector, 
            y1, x1, y2, x2: int) =
            var action = initAction(y1, x1, y2, x2, N, N)

            self.moveForward(action)
            var hash = self.hash
            var cost = self.evaluate()
            var finished = (self.targetBall == M)
            self.moveBackward(action)

            multiSelector.push(action, cost, hash, parent, finished, 1)
        
        proc push3(self:var State, parent: int, multiSelector:var MulutiSelector, 
            y1, x1, y2, x2, y3, x3: int) =
            var action = initAction(y1, x1, y2, x2, y3, x3)

            self.moveForward(action)
            var hash = self.hash
            var cost = self.evaluate()
            var finished = (self.targetBall == M)
            self.moveBackward(action)

            multiSelector.push(action, cost, hash, parent, finished, 2)

        var (y, x) = self.pos[self.targetBall]
        if self.canMoveLeft(y, x):
            self.push2(parent, multiSelector, y, x, y-1, x-1)
            if self.canMoveLeft(y-1, x-1):
                self.push3(parent, multiSelector, y-1, x-1, y-2, x-2, y, x)
            if self.canMoveRight(y-1, x-1):
                self.push3(parent, multiSelector, y-1, x-1, y-2, x-1, y, x)
            if x-1 > 0 and self.b[y-1][x-1]<self.b[y-1][x-2]:   # 真左
                self.push3(parent, multiSelector, y-1, x-1, y-1, x-2, y, x)
            if y-1 > x-1 and self.b[y-1][x-1]<self.b[y-1][x]:   # 真右
                self.push3(parent, multiSelector, y-1, x-1, y-1, x, y, x)

        if self.canMoveRight(y, x):
            self.push2(parent, multiSelector, y, x, y-1, x)
            if self.canMoveLeft(y-1, x):
                self.push3(parent, multiSelector, y-1, x, y-2, x-1, y, x)
            if self.canMoveRight(y-1, x):
                self.push3(parent, multiSelector, y-1, x, y-2, x, y, x)
            if x > 0 and self.b[y-1][x]<self.b[y-1][x-1]:   # 真左
                self.push3(parent, multiSelector, y-1, x, y-1, x-1, y, x)
            if y-1 > x and self.b[y-1][x]<self.b[y-1][x+1]:   # 真右
                self.push3(parent, multiSelector, y-1, x, y-1, x+1, y, x)

        if x > 0 and self.b[y][x]<self.b[y][x-1]:   # 真左
            self.push2(parent, multiSelector, y, x, y, x-1)
        if y > x and self.b[y][x]<self.b[y][x+1]:   # 真右
            self.push2(parent, multiSelector, y, x, y, x+1)

# ターンをスキップできる差分更新ビームサーチライブラリ
when not declared SkipBeamSearchModule:

    # メモリの再利用を行いつつ集合を管理するクラス
    when not declared ObjectPoolModule:
        proc initObjectPool[T](cap: int): ObjectPool[T] = 
            result.data = newSeqOfCap[T](cap)
            
        # 配列と同じようにアクセスできる
        proc `[]`[T](self:var ObjectPool[T], i: SomeInteger):var T = self.data[i]

        # 要素を追加し、追加されたインデックスを返す
        proc push[T](self:var ObjectPool[T], a: T): int {.discardable.} =
            if self.garbage.len==0:
                self.data.add(a)
                return self.data.len-1
            let i = self.garbage.pop()
            self.data[i] = a
            return i

        # 要素を（見かけ上）削除する
        proc pop[T](self:var ObjectPool[T], i: SomeInteger) =
            self.garbage.add(i)

        # 管理しているデータ量
        proc size(self: ObjectPool): int = (self.data.len-self.garbage.len)

    # Key: int にハッシュ関数を適用しない, 連想配列
    when not declared HashMapModule:
        # capは格納する要素数よりも4~16倍ほど大きくする
        proc initHashMap[T](): HashMap[T] = discard

        # 戻り値 (存在有無: bool, index: int)
        proc getIndex[T](self:var HashMap[T], key: int): (bool, int) =
            var i = key & hashMapMask
            for _ in 0..<hashMapCapacity:
                if not self.valid[i]:
                    return (false, i)
                if self.data[i][0]==key:
                    return (true, i)
                i = (i+1) & hashMapMask
            return (false, -1)

        # 指定したindexにkeyとvalueを格納する
        proc set[T](self:var HashMap[T], i: SomeInteger, key: int, val: T) =
            if not self.valid[i]:
                self.used.inc
            self.valid[i] = true
            self.data[i] = (key, val)

        # 指定したindexのvalueを返す
        proc get[T](self:var HashMap[T], i: SomeInteger): T = self.data[i][1]

        proc clear(self:var HashMap) =
            # self.valid.fill(false)
            self.valid.clear()
            self.used = 0

    # ノードの候補から実際に追加するものを選ぶクラス
    when not declared SelectorModule:
        proc initSelector(): Selector =
            result = new Selector
            result.beamWidth = beamWidth
            # result.candidates = newSeqOfCap[Candidate](beamWidth)
            result.costs = (0..<beamWidth).toSeq().mapIt((0, it))

        proc rebuildHashMap(self: Selector) =
            self.hash2index.clear()
            for j in 0..<self.candidates.len:
                let (_, i) = self.hash2index.getIndex(self.candidates[j].hash)
                self.hash2index.set(i, self.candidates[j].hash, j)

        # 候補を追加する
        # ターン数最小化型の問題で、candidateによって実行可能解が得られる場合にのみ finished = true とする
        # ビーム幅分の候補をCandidateを追加したときにsegment treeを構築する
        proc push(self: Selector, action: Action, cost: CostType, 
            hash: HashType, parent: int, finished: bool): bool {.discardable.} =
            if finished:
                self.finishedCandidates.add(Candidate(
                    action: action, hash: hash, parent: parent, cost: cost))
                return true

            # 保持しているどの候補よりもコストが小さくないとき
            if self.full and cost >= self.maxSegTree.all_prod()[0]:
                return false

            if self.hash2index.used >= hashMapRebuildThreshold:
                self.rebuildHashMap()

            var (valid, i) = self.hash2index.getIndex(hash)
            if i == -1:
                self.rebuildHashMap()
                (valid, i) = self.hash2index.getIndex(hash)

            # ハッシュ値が等しいものが存在しているとき
            if valid:
                let j = self.hash2index.get(i)
                if hash == self.candidates[j].hash:
                    if self.full:       # segment treeが構築されている場合
                        if cost < self.maxSegTree.get(j)[0]:
                            self.candidates[j] = Candidate(
                                action: action, hash: hash, parent: parent, cost: cost)
                            self.maxSegTree.set(j, (cost, j))
                            return true
                    elif cost < self.costs[j][0]: # segment treeが構築されていない場合
                        self.candidates[j] = Candidate(
                            action: action, hash: hash, parent: parent, cost: cost)
                        self.costs[j][0] = cost
                        return true
                    return false

            if self.full: # segment treeが構築されている場合
                let j = self.maxSegTree.all_prod()[1]
                self.hash2index.set(i, hash, j)
                self.candidates[j] = Candidate(
                    action: action, hash: hash, parent: parent, cost: cost)
                self.maxSegTree.set(j, (cost, j))

            else: # segment treeが構築されていない場合
                let j = self.candidates.len
                self.hash2index.set(i, hash, j)
                self.candidates.add(Candidate(
                    action: action, hash: hash, parent: parent, cost: cost))
                self.costs[j][0] = cost

                # 保持している候補がビーム幅分になったときにsegment treeを構築する
                if self.candidates.len == self.beamWidth:
                    self.full = true
                    self.maxSegTree = MaxSegTreeType.init(self.costs)
            return true

        # 実行可能解が見つかったか
        template haveFinished(self: Selector): bool =
            self.finishedCandidates.len > 0

        # 実行可能解に到達する「候補」を返す
        template getFinishedCandidate(self: Selector): seq[Candidate] =
            self.finishedCandidates

        # 最もよいCandidateを返す
        proc calculateBestCandidate(self: Selector): Candidate =
            var best: int
            if self.full:
                for i in 0..<self.beam_width:
                    if self.maxSegTree.get(i)[0] < self.maxSegTree.get(best)[0]:
                        best = i
                return self.candidates[best]
            else:
                for i in 0..<self.candidates.len:
                    if self.costs[i][0] == 0: continue
                    if self.costs[i][0] < self.costs[best][0]:
                        best = i
                return self.candidates[best]

        template clear(self: Selector) =
            if self.beamWidth != beamWidth:
                self.beamWidth = beamWidth
                self.costs = (0..<beamWidth).toSeq().mapIt((0, it))
            self.candidates.clear()
            self.hash2index.clear()
            self.full = false

    # ターン毎に候補を管理する
    when not declared MulutiSelectorModule:
        proc initMultiSelector(): MulutiSelector =
            result.stepMax = 1

        # 候補を追加する, step は何ターン後に遷移するかを表す
        proc push(self:var MulutiSelector, action: Action, cost: CostType, 
            hash: HashType, parent: int, finished: bool, step: int): bool {.discardable.} =
            while self.selectors.len < step:
                self.selectors.addLast(initSelector())
            if self.selectors[step-1].push(action, cost, hash, parent, finished):
                self.stepMax.max= step
                return true
            return false

    # 探索木（二重連鎖木）のノード
    when not declared NodeModule:
        proc initRootNode(action: Action, cost: CostType, hash: HashType): Node =
            Node(action: action, cost: cost, hash: hash,
                parent: -1, child: -1, left: -1, right: -1, active: true)

        proc initNode(cand: Candidate, right: int): Node =
            Node(action: cand.action, cost: cand.cost, hash: cand.hash,
                parent: cand.parent, child: -1, left: -1, right: right, active: true)

    # 二重連鎖木に対する操作をまとめたクラス
    when not declared TreeModule:
        proc initTree(state: State, cap: int, root: Node): Tree =
            result.state = state
            result.nodes = initObjectPool[Node](cap)
            result.root = result.nodes.push(root)

        # 不要になった葉を再帰的に削除する
        proc removeLeaf(self:var Tree, u: int) =
            var v = u
            while true:
                let left = self.nodes[v].left
                let right = self.nodes[v].right
                if left == -1:  # parent-me-right => parent-right
                    let parent = self.nodes[v].parent
                    # if parent == -1: return  # 想定外
                    self.nodes.pop(v)
                    self.nodes[parent].child = right
                    if right != -1:
                        self.nodes[right].left = -1
                        return
                    v = parent  # right=-1のため、parentも削除対象
                else:           # left-me-right => left-right
                    self.nodes.pop(v)
                    self.nodes[left].right = right
                    if right != -1:
                        self.nodes[right].left = left
                    return

        # 不要になったノードを全て削除する
        proc removeUselessNodes(self:var Tree) =
            if self.removeNodes.len == 0: return
            var nodes = self.removeNodes.popFirst()
            for v in nodes:
                if self.nodes[v].child == -1:
                    self.removeLeaf(v)
            nodes.setLen(0)     # オブジェクトの再利用(高速化)
            self.removeNodes.addLast(nodes)

        # 根から一本道の部分は往復しないようにする
        proc updateRoot(self:var Tree) =
            var child = self.nodes[self.root].child
            while child != -1 and self.nodes[child].right == -1:
                self.root = child
                self.state.moveForward(self.nodes[child].action)
                child = self.nodes[child].child

        # ノードvの子孫で、最も左にある葉に移動する
        proc move2leaf(self:var Tree, i: int): int =
            var v = i
            var child = self.nodes[v].child
            while child != -1:
                # activeなノードが見つかるまで右に移動する
                while not self.nodes[child].active:
                    child = self.nodes[child].right
                self.nodes[v].active = false
                v = child
                self.state.moveForward(self.nodes[child].action)
                child = self.nodes[child].child
            self.nodes[v].active = false
            return v

        # ノードvの先祖で、右への分岐があるところまで移動する
        proc move2ancestor(self:var Tree, i: int): int =
            var v = i
            while v != self.root:
                self.state.moveBackward(self.nodes[v].action)
                # activeなノードが見つかるまで右に移動する
                var u = self.nodes[v].right
                while u != -1:
                    if self.nodes[u].active:
                        self.state.moveForward(self.nodes[u].action)
                        return u
                    u = self.nodes[u].right
                v = self.nodes[v].parent
            return self.root

        # 状態を更新しながら深さ優先探索を行い、次のノードの候補を全てselectorに追加する
        proc dfs(self:var Tree, multiSelector:var MulutiSelector) =
            self.removeUselessNodes()
            self.updateRoot()

            var v = self.root
            # activeなノードがないとき
            if not self.nodes[v].active: return

            while true:
                v = self.move2leaf(v)

                multiSelector.stepMax = 1
                self.state.expand(v, multiSelector)

                while self.removeNodes.len < multiSelector.stepMax:
                    self.removeNodes.addLast(@[])

                # ノード展開後は削除ノード候補に追加
                self.removeNodes[multiSelector.stepMax-1].add(v)

                v = self.move2ancestor(v)
                if v == self.root: break

        # 根からノードvまでのパスを取得する
        proc getPath(self:var Tree, i: int): seq[Action] =
            var v = i
            var path: seq[Action]
            while self.nodes[v].parent != -1:
                path.add(self.nodes[v].action)
                v = self.nodes[v].parent
            return path.reversed()

        # 新しいノードを追加する
        proc addLeaf(self:var Tree, cand: Candidate): int {.discardable.} =
            var parent = cand.parent
            var sibling = self.nodes[parent].child
            var v = self.nodes.push(initNode(cand, sibling))

            self.nodes[parent].child = v

            if sibling != -1:
                self.nodes[sibling].left = v

            # 祖先をactivateする
            var u = parent
            while not self.nodes[u].active:
                self.nodes[u].active = true
                if u == self.root: break
                u = self.nodes[u].parent
            return v

    # ビームサーチを行う関数
    proc beamSearch(state: State, root: Node): seq[Action] =
        var tree = initTree(state, nodesCapacity, root)
        var multiSelector = initMultiSelector()
        var totalWidth = 0
        var startTime = timer.getTime()

        for turn in 1..maxTurn:
            
            # 累積ビーム幅と残り時間でビーム幅可変
            if turn & 0xFF == 0:
                let elapsedRatio = (timer.getTime()-startTime) / (timeLimit-startTime)
                var nxtWidth = (
                    totalWidth.float * (1.0-elapsedRatio) / elapsedRatio).int // (maxTurn-turn)
                beamWidth = nxtWidth.clamp(minBeamWidth, beamWidth)

            # Euler Tour で selector に候補を追加する
            tree.dfs(multiSelector)

            # 次の候補を保持したSelectorを取り出す
            var selector = multiSelector.selectors.popFirst()
            totalWidth += (beamWidth + selector.candidates.len) // 2

            # ターン数最小化型の問題で実行可能解が見つかったとき
            if selector.haveFinished():
                var cand = selector.getFinishedCandidate()[0]
                var ret = tree.getPath(cand.parent)
                ret.add(cand.action)
                return ret

            # ターン数固定型の問題で全ターンが終了したとき
            if turn == maxTurn:
                var cand = selector.calculateBestCandidate()
                var ret = tree.getPath(cand.parent)
                ret.add(cand.action)
                return ret

            # 新しいノードを追加する
            for cand in selector.candidates:
                tree.addLeaf(cand)

            # Selectorを使い回す
            selector.clear()
            multiSelector.selectors.addLast(selector)

# ----------------------------------------------------------------
type Solver = object
    ans: seq[Action]

proc prepare(self:var Solver) =
    pass

proc solve(self:var Solver) =
    var state = initState()
    var root = initRootNode(initAction(0,0,0,0,0,0), state.evaluate(), 0)   # action, cost, hash
    self.ans = beamSearch(state, root)

proc output(self:var Solver) =
    var cnt = self.ans.len
    for action in self.ans:
        var y1, x1, y2, x2, y3, x3: int
        # action.decode(y1, x1, y2, x2, y3, x3)
        action.decode()

        if x3 < N:
            cnt += 1

    stdout.writeLine cnt
    for action in self.ans:
        var y1, x1, y2, x2, y3, x3: int
        # action.decode(y1, x1, y2, x2, y3, x3)
        action.decode()

        stdout.writeLine fmt"{y1} {x1} {y2} {x2}"
        if x3 < N:
            stdout.writeLine fmt"{y1} {x1} {y3} {x3}"

    stderr.writeLine fmt"score: {100000-5*cnt}"

proc main() =
    var solver = Solver()
    solver.prepare()
    solver.solve()
    solver.output()

main()
stderr.writeLine timer.getTime()

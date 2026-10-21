
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


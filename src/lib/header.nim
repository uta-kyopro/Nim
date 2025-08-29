
{.hints:off checks:off warnings:off assertions:off optimization:speed.}
when defined(debug): {.checks:on.}
{.passC: "-O3 -march=native -mtune=native".}

when not declared Importer:
    import std/[os, bitops, macros, hashes, 
                algorithm, sequtils, setutils, strformat, strutils,
                deques, heapqueue, options, sets, tables,
                monotimes, times, math, random, rationals]

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
    template input(t: typedesc, n: int): seq[t] =           # seq[type]
        newSeqWith(n, input(t))
    template input(t: typedesc, n1, n2: int): seq[seq[t]] = # seq[seq[type]]
        newSeqWith(n1, newSeqWith(n2, input(t)))
    macro input(ts: varargs[auto]): untyped =               # tuple
        let tupStr = ts.toSeq.mapIt(&"input({it.repr}),").join
        parseExpr(&"({tupStr})")
    template input(n: int, ts: varargs[auto]): untyped =    # seq[tuple]
        newSeqWith(n, input(ts))

when not declared OutputHelper:
    template print[T](x: varargs[T, `$`]) = stdout.writeLine x
    template flush() = stdout.flushFile()
    when defined(is_local):
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



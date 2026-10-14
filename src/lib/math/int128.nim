## GCC/ClangのC++バックエンド用128bit整数。
## signedの演算結果は範囲内であることが前提。unsignedの演算はmod 2^128。
## 入力・変換・除算・シフト・signedの桁あふれ検査はdebug時のみ。
when not declared Int128Module:
    const Int128Module* = true
    when not defined(cpp):
        {.error: "int128 requires the C++ backend (nim cpp)".}
    {.emit: """
        #ifndef __SIZEOF_INT128__
        #error "This compiler/target does not support __int128"
        #endif
    """.}
    import std/[algorithm, hashes, bitops]
    export bitops
    {.push checks: off.}
    when defined(debug):
        {.checks: on.}

    type
        Int128* {.importcpp: "__int128", nodecl, bycopy.} = object
        UInt128* {.importcpp: "unsigned __int128", nodecl, bycopy.} = object
        Integer128* = Int128 | UInt128

    proc signed128(x: int64): Int128 {.importcpp: "((__int128)(#))", nodecl.}
    proc unsigned128(x: uint64): UInt128 {.importcpp: "((unsigned __int128)(#))", nodecl.}
    proc signedBits(x: UInt128): Int128 {.importcpp: "((__int128)(#))", nodecl.}
    proc unsignedBits(x: Int128): UInt128 {.importcpp: "((unsigned __int128)(#))", nodecl.}
    proc lowBits(x: UInt128): uint64 {.importcpp: "((unsigned long long)(#))", nodecl.}
    proc rawInteger[T: SomeInteger, U: Integer128](x: U): T {.
        importcpp: "(('0)(#))", nodecl.}
    proc rawAdd[T: Integer128](a, b: T): T {.importcpp: "((#) + (#))", nodecl.}
    proc rawSub[T: Integer128](a, b: T): T {.importcpp: "((#) - (#))", nodecl.}
    proc rawMul[T: Integer128](a, b: T): T {.importcpp: "((#) * (#))", nodecl.}
    proc rawDiv[T: Integer128](a, b: T): T {.importcpp: "((#) / (#))", nodecl.}
    proc rawMod[T: Integer128](a, b: T): T {.importcpp: "((#) % (#))", nodecl.}
    proc rawShl[T: Integer128](a: T, b: int): T {.importcpp: "((#) << (#))", nodecl.}
    proc rawShr[T: Integer128](a: T, b: int): T {.importcpp: "((#) >> (#))", nodecl.}
    proc addOverflow(a, b: Int128, dest: var Int128): bool {.
        importcpp: "__builtin_add_overflow(#, #, &(#))", nodecl.}
    proc subOverflow(a, b: Int128, dest: var Int128): bool {.
        importcpp: "__builtin_sub_overflow(#, #, &(#))", nodecl.}
    proc mulOverflow(a, b: Int128, dest: var Int128): bool {.
        importcpp: "__builtin_mul_overflow(#, #, &(#))", nodecl.}

    proc initInt128*[T: SomeInteger](x: T): Int128 =
        when T is SomeSignedInt: signed128(int64(x))
        else: signedBits(unsigned128(uint64(x)))
    proc initUInt128*[T: SomeInteger](x: T): UInt128 =
        when T is SomeSignedInt:
            when defined(debug):
                doAssert x >= 0, "negative integer cannot convert to UInt128"
            unsignedBits(signed128(int64(x)))
        else: unsigned128(uint64(x))

    proc `==`*(a, b: Int128): bool {.importcpp: "((#) == (#))", nodecl.}
    proc `==`*(a, b: UInt128): bool {.importcpp: "((#) == (#))", nodecl.}
    proc `<`*[T: Integer128](a, b: T): bool {.importcpp: "((#) < (#))", nodecl.}
    proc `<=`*[T: Integer128](a, b: T): bool {.importcpp: "((#) <= (#))", nodecl.}
    proc high*(t: typedesc[UInt128]): UInt128 = rawSub(unsigned128(0), unsigned128(1))
    proc low*(t: typedesc[UInt128]): UInt128 = unsigned128(0)
    proc high*(t: typedesc[Int128]): Int128 = signedBits(rawShr(high(UInt128), 1))
    proc low*(t: typedesc[Int128]): Int128 = signedBits(rawShl(unsigned128(1), 127))

    proc toInt128*(x: UInt128): Int128 =
        when defined(debug):
            doAssert x <= unsignedBits(high(Int128)), "UInt128 exceeds Int128 range"
        signedBits(x)
    proc toInt128*(x: Int128): Int128 = x
    proc toInt128*[T: SomeInteger](x: T): Int128 = initInt128(x)
    proc toUInt128*(x: Int128): UInt128 =
        when defined(debug):
            doAssert initInt128(0) <= x, "negative Int128 cannot convert to UInt128"
        unsignedBits(x)
    proc toUInt128*(x: UInt128): UInt128 = x
    proc toUInt128*[T: SomeInteger](x: T): UInt128 = initUInt128(x)
    proc initInt128*(x: UInt128): Int128 = toInt128(x)
    proc initInt128*(x: Int128): Int128 = x
    proc initUInt128*(x: Int128): UInt128 = toUInt128(x)
    proc initUInt128*(x: UInt128): UInt128 = x

    proc toInt*[T: SomeInteger](x: Int128): T =
        when defined(debug):
            doAssert initInt128(low(T)) <= x and x <= initInt128(high(T)),
                "Int128 exceeds destination integer range"
        rawInteger[T, Int128](x)
    proc toInt*[T: SomeInteger](x: UInt128): T =
        when defined(debug):
            doAssert x <= initUInt128(high(T)), "UInt128 exceeds destination integer range"
        rawInteger[T, UInt128](x)

    proc `+`*[T: Integer128](a, b: T): T =
        when defined(debug) and T is Int128:
            let overflow = addOverflow(a, b, result)
            doAssert not overflow, "Int128 addition overflow"
        else: result = rawAdd(a, b)
    proc `-`*[T: Integer128](a, b: T): T =
        when defined(debug) and T is Int128:
            let overflow = subOverflow(a, b, result)
            doAssert not overflow, "Int128 subtraction overflow"
        else: result = rawSub(a, b)
    proc `*`*[T: Integer128](a, b: T): T =
        when defined(debug) and T is Int128:
            let overflow = mulOverflow(a, b, result)
            doAssert not overflow, "Int128 multiplication overflow"
        else: result = rawMul(a, b)
    proc `-`*[T: Integer128](a: T): T =
        when T is Int128: initInt128(0) - a
        else: rawSub(unsigned128(0), a)
    proc checkDivision[T: Integer128](a, b: T) =
        when defined(debug):
            when T is Int128:
                doAssert not (a == low(Int128) and b == initInt128(-1)), "Int128 division overflow"
                doAssert not (b == initInt128(0)), "division by zero"
            else:
                doAssert not (b == initUInt128(0)), "division by zero"
    proc `div`*[T: Integer128](a, b: T): T =
        when defined(debug): checkDivision(a, b)
        rawDiv(a, b)
    proc `mod`*[T: Integer128](a, b: T): T =
        when defined(debug): checkDivision(a, b)
        rawMod(a, b)
    proc `and`*[T: Integer128](a, b: T): T {.importcpp: "((#) & (#))", nodecl.}
    proc `or`*[T: Integer128](a, b: T): T {.importcpp: "((#) | (#))", nodecl.}
    proc `xor`*[T: Integer128](a, b: T): T {.importcpp: "((#) ^ (#))", nodecl.}
    proc `not`*[T: Integer128](a: T): T {.importcpp: "(~(#))", nodecl.}
    proc `shl`*[T: Integer128](a: T, count: int): T =
        when defined(debug): doAssert count in 0..127, "invalid 128bit shift count"
        when T is Int128:
            result = signedBits(rawShl(unsignedBits(a), count))
            when defined(debug):
                doAssert rawShr(result, count) == a, "Int128 left shift overflow"
        else: result = rawShl(a, count)
    proc `shr`*[T: Integer128](a: T, count: int): T =
        when defined(debug): doAssert count in 0..127, "invalid 128bit shift count"
        rawShr(a, count)
    proc cmp*[T: Integer128](a, b: T): int =
        if a < b: -1
        elif b < a: 1
        else: 0
    proc abs*(x: Int128): Int128 =
        if x < initInt128(0): -x else: x
    proc hash*(x: UInt128): Hash =
        !$((hash(lowBits(x)) !& hash(lowBits(rawShr(x, 64)))))
    proc hash*(x: Int128): Hash = hash(unsignedBits(x))
    proc popCount*(x: UInt128): int =
        ## 立っているbitの数。0では0、最大128。O(1)。
        bitops.popCount(lowBits(x)) + bitops.popCount(lowBits(rawShr(x, 64)))
    proc popCount*(x: Int128): int = popCount(unsignedBits(x))
    proc countSetBits*(x: UInt128): int = popCount(x)
    proc countSetBits*(x: Int128): int = popCount(x)
    proc firstSetBit*(x: UInt128): int =
        ## bitopsと同じ1始まり。ゼロなら0。O(1)。
        let lower = lowBits(x)
        if lower != 0: return bitops.firstSetBit(lower)
        let upper = lowBits(rawShr(x, 64))
        if upper != 0: return 64 + bitops.firstSetBit(upper)
        0
    proc firstSetBit*(x: Int128): int = firstSetBit(unsignedBits(x))
    proc countTrailingZeroBits*(x: UInt128): int =
        ## 非ゼロなら0始まりの最下位bit位置。ゼロの扱いもbitopsに合わせる。
        when defined(noUndefinedBitOpts):
            if x == initUInt128(0): return 0
        elif defined(debug):
            doAssert not (x == initUInt128(0)), "countTrailingZeroBits requires nonzero input"
        let lower = lowBits(x)
        if lower != 0: return bitops.countTrailingZeroBits(lower)
        64 + bitops.countTrailingZeroBits(lowBits(rawShr(x, 64)))
    proc countTrailingZeroBits*(x: Int128): int = countTrailingZeroBits(unsignedBits(x))
    iterator getSetBits*(x: UInt128): int =
        ## 立っているbit位置を昇順に列挙。O(popCount(x))、元の値は変更しない。
        var remaining = x
        while not (remaining == initUInt128(0)):
            yield countTrailingZeroBits(remaining)
            remaining = remaining and (remaining - initUInt128(1))
    iterator getSetBits*(x: Int128): int =
        for index in getSetBits(unsignedBits(x)):
            yield index
    proc `+=`*[T: Integer128](a: var T, b: T) = a = a + b
    proc `-=`*[T: Integer128](a: var T, b: T) = a = a - b
    proc `*=`*[T: Integer128](a: var T, b: T) = a = a * b
    proc inc*[T: Integer128](a: var T) =
        when T is Int128: a += initInt128(1)
        else: a += initUInt128(1)
    proc dec*[T: Integer128](a: var T) =
        when T is Int128: a -= initInt128(1)
        else: a -= initUInt128(1)

    proc `$`*(x: UInt128): string =
        var value = x
        let ten = initUInt128(10)
        if value == low(UInt128): return "0"
        while not (value == low(UInt128)):
            result.add(char(ord('0') + int(lowBits(value mod ten))))
            value = value div ten
        result.reverse()
    proc `$`*(x: Int128): string =
        if x < initInt128(0): "-" & $(rawSub(unsigned128(0), unsignedBits(x)))
        else: $unsignedBits(x)

    proc parseMagnitude(s: string, limit: UInt128, signed: bool): (UInt128, bool) =
        when defined(debug): doAssert s.len > 0, "empty 128bit integer"
        var start = 0
        let negative = s[0] == '-'
        if negative or s[0] == '+': start = 1
        when defined(debug):
            doAssert start < s.len, "128bit integer has no digits"
            doAssert signed or not negative, "negative UInt128 input"
        let ten = initUInt128(10)
        var magnitude = initUInt128(0)
        for i in start..<s.len:
            when defined(debug): doAssert s[i] in {'0'..'9'}, "invalid decimal digit"
            let digit = initUInt128(ord(s[i]) - ord('0'))
            when defined(debug):
                doAssert magnitude <= limit div ten and
                    (not (magnitude == limit div ten) or digit <= limit mod ten),
                    "128bit decimal input out of range"
            magnitude = rawAdd(rawMul(magnitude, ten), digit)
        (magnitude, negative)
    proc parseInt128*(s: string): Int128 =
        let negative = s.len > 0 and s[0] == '-'
        let limit = if negative: unsignedBits(low(Int128)) else: unsignedBits(high(Int128))
        let (magnitude, neg) = parseMagnitude(s, limit, true)
        if neg: signedBits(rawSub(unsigned128(0), magnitude)) else: signedBits(magnitude)
    proc parseUInt128*(s: string): UInt128 = parseMagnitude(s, high(UInt128), false)[0]
    proc initInt128*(s: string): Int128 = parseInt128(s)
    proc initUInt128*(s: string): UInt128 = parseUInt128(s)

    proc readToken(file: File): string =
        # Stream input; consumes the delimiter after a token.
        var ch = file.readChar()
        while ch <= ' ': ch = file.readChar()
        result.add(ch)
        while not file.endOfFile():
            ch = file.readChar()
            if ch <= ' ': break
            result.add(ch)
    proc readInt128*(file: File = stdin): Int128 = parseInt128(readToken(file))
    proc readUInt128*(file: File = stdin): UInt128 = parseUInt128(readToken(file))
    template input*(t: typedesc[Int128]): Int128 =
        mixin nxtStr
        when declared(nxtStr): parseInt128(nxtStr())
        else: readInt128()
    template input*(t: typedesc[UInt128]): UInt128 =
        mixin nxtStr
        when declared(nxtStr): parseUInt128(nxtStr())
        else: readUInt128()
    {.pop.}

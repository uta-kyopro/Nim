
include ../header


# 計算量: 1 bit の取得・更新は O(1)、clear・popCount・集合演算は O(N / 64)。
when not declared StaticBitSetModule:
    const StaticBitSetModule = true
    const StaticBitSetWordBits = 64
    const StaticBitSetWordBitsLog2 = 6
    type StaticBitSet[N: static[int]] = object
        data: array[(N+StaticBitSetWordBits-1) shr StaticBitSetWordBitsLog2, uint64]
    proc initStaticBitSet(N: static[int]): StaticBitSet[N]= discard
    proc initStaticBitSet0(N: static[int]): StaticBitSet[N]= discard
    proc initStaticBitSet1(N: static[int]): StaticBitSet[N]=
        result.data.fill(not(uint64(0)))
        when N > 0 and (N and (StaticBitSetWordBits-1)) != 0:
            result.data[^1] = (1'u64 shl (N and (StaticBitSetWordBits-1))) - 1
    proc clear(b:var StaticBitSet)= b.data.fill(uint64(0))
    proc popCount[N](b: StaticBitSet[N]): int =
        for word in b.data:
            result += word.popCount
    proc `[]`(b: StaticBitSet, n: SomeInteger): bool {.inline.}=
        let q = n shr StaticBitSetWordBitsLog2
        let r = n and (StaticBitSetWordBits-1)
        return b.data[q].testBit(r)
    proc `[]=`(b:var StaticBitSet, n: SomeInteger, t: int) {.inline.}=
        let q = n shr StaticBitSetWordBitsLog2
        let r = n and (StaticBitSetWordBits-1)
        if t==0: b.data[q].clearBit(r)
        elif t==1: b.data[q].setBit(r)
    proc `|=`[N](b1: var StaticBitSet[N], b2: StaticBitSet[N]) =
        for i in 0..<b1.data.len:
            b1.data[i] = b1.data[i] or b2.data[i]
    proc `&=`[N](b1: var StaticBitSet[N], b2: StaticBitSet[N]) =
        for i in 0..<b1.data.len:
            b1.data[i] = b1.data[i] and b2.data[i]
    proc `^=`[N](b1: var StaticBitSet[N], b2: StaticBitSet[N]) =
        for i in 0..<b1.data.len:
            b1.data[i] = b1.data[i] xor b2.data[i]

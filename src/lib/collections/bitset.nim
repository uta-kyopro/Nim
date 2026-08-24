
include ../header


# 計算量: 1 bit の取得・更新は O(1)、clear・popCount・集合演算は O(N / 64)。
when not declared BitSetModule:
    const BitSetModule = true
    const BitWidth = 64
    const BitWidthLog2 = 6
    type BitSet[N: static[int]] = object
        data: array[(N+BitWidth-1) shr BitWidthLog2, uint64]
    proc initBitSet(N: static[int]): BitSet[N]= discard
    proc initBitSet0(N: static[int]): BitSet[N]= discard
    proc initBitSet1(N: static[int]): BitSet[N]=
        result.data.fill(not(uint64(0)))
        when N > 0 and (N and (BitWidth-1)) != 0:
            result.data[^1] = (1'u64 shl (N and (BitWidth-1))) - 1
    proc clear(b:var BitSet)= b.data.fill(uint64(0))
    proc popCount[N](b: BitSet[N]): int =
        for word in b.data:
            result += word.popCount
    proc `[]`(b: BitSet, n: SomeInteger): bool {.inline.}=
        let q = n shr BitWidthLog2
        let r = n and (BitWidth-1)
        return b.data[q].testBit(r)
    proc `[]=`(b:var BitSet, n: SomeInteger, t: int) {.inline.}=
        let q = n shr BitWidthLog2
        let r = n and (BitWidth-1)
        if t==0: b.data[q].clearBit(r)
        elif t==1: b.data[q].setBit(r)
    proc `|=`[N](b1: var BitSet[N], b2: BitSet[N]) =
        for i in 0..<b1.data.len:
            b1.data[i] = b1.data[i] or b2.data[i]
    proc `&=`[N](b1: var BitSet[N], b2: BitSet[N]) =
        for i in 0..<b1.data.len:
            b1.data[i] = b1.data[i] and b2.data[i]
    proc `^=`[N](b1: var BitSet[N], b2: BitSet[N]) =
        for i in 0..<b1.data.len:
            b1.data[i] = b1.data[i] xor b2.data[i]


include ../header


when not declared BitSetModule:
    const BitWidth = 64
    const BitWidthLog2 = 6
    const MaxBitSetSize = 1800      # 前計算する最大値
    const bitDivMod = (0..MaxBitSetSize).toSeq().mapIt((it shr BitWidthLog2, it and (BitWidth-1)))
    type BitSet[N: static[int]] = object
        data: array[(N+BitWidth-1) shr BitWidthLog2, uint64]
    proc initBitSet(N: static[int]): BitSet[N]= discard
    proc initBitSet0(N: static[int]): BitSet[N]= discard
    proc initBitSet1(N: static[int]): BitSet[N]= result.data.fill(not(uint64(0)))
    proc clear(b:var BitSet)= b.data.fill(uint64(0))
    proc popCount(b:var BitSet): int = b.data.mapIt(it.popCount).sum
    proc `[]`(b:var BitSet, n: SomeInteger): bool {.inline.}=
        let (q, r) = bitDivMod[n]
        return b.data[q].testBit(r)
    proc `[]=`(b:var BitSet, n: SomeInteger, t: int) {.inline.}=
        let (q, r) = bitDivMod[n]
        if t==0: b.data[q].clearBit(r)
        elif t==1: b.data[q].setBit(r)
    proc `|=`(b1, b2:var BitSet) =
        for i in 0..<b1.data.len:
            b1.data[i] = b1.data[i] or b2.data[i]

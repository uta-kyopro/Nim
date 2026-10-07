import std/[algorithm, random, sequtils, unittest]
import ../src/lib/range_query/wavelet_matrix

proc verify[W](wm: W, a: seq[int], rng: var Rand) =
    check wm.len == a.len
    for i, x in a:
        check wm[i] == x
        check wm.access(i) == x
    for trial in 0..<300:
        let l = rng.rand(a.len)
        let r = rng.rand(l..a.len)
        let ordered = a[l..<r].sorted()
        let x = rng.rand(-40..40)
        let y = rng.rand(x..50)
        check wm.rank(x, r) == a[0..<r].count(x)
        check wm.range_freq(l..<r, x) == ordered.countIt(it < x)
        check wm.range_freq(l..<r, x, y) == ordered.countIt(x <= it and it < y)
        let less = ordered.filterIt(it < x)
        let greater = ordered.filterIt(it >= x)
        check wm.prev_value(l..<r, x) == (if less.len == 0: none(int) else: some(less[^1]))
        check wm.next_value(l..<r, x) == (if greater.len == 0: none(int) else: some(greater[0]))
        if ordered.len > 0:
            for k in [0, ordered.len div 2, ordered.len - 1]:
                check wm.kth_smallest(l..<r, k) == ordered[k]
                check wm.kth_largest(l..<r, k) == ordered[^(k + 1)]

suite "standalone wavelet matrix":
    test "random differential and word boundaries":
        var rng = initRand(2607)
        for n in [0, 1, 2, 7, 31, 32, 63, 64, 65, 127, 128, 129, 257]:
            for trial in 0..<5:
                let a = newSeqWith(n, rng.rand(0..31))
                verify(initStaticWaveletMatrix(a), a, rng)
                let b = newSeqWith(n, rng.rand(-31..31))
                verify(initCompressedStaticWaveletMatrix(b), b, rng)

    test "full domains, negative sentinel and extreme integers":
        let raw = initStaticWaveletMatrix(@[0, 1, 2, 3], 2)
        check raw.rangeFreq(0..<4, 4) == 4
        check raw.rangeFreq(0..<4, int.high) == 4
        check raw.rangeFreq(0..<4, int.low) == 0
        check raw.rank(4, 4) == 0
        check raw.rank(-1, 4) == 0
        let compressed = initCompressedStaticWaveletMatrix(@[-1, -5, 7, 100])
        check compressed.rangeFreq(0..<4, int.high) == 4
        check compressed.prevValue(0..<4, 0) == some(-1)
        check compressed.nextValue(0..<4, 101).isNone
        let extremes = initCompressedStaticWaveletMatrix(@[int.low, int.high, -1, 0])
        check extremes[0] == int.low
        check extremes.kthLargest(0..<4, 0) == int.high
        check extremes.rank(int.high, 4) == 1
        let large = initStaticWaveletMatrix(@[0'u64, uint64.high, 1'u64 shl 63])
        check large[1] == uint64.high
        check large.kthLargest(0..<3, 0) == uint64.high
        check large.rangeFreq(0..<3, uint64.high) == 2
        check large.nextValue(0..<3, uint64.high) == some(uint64.high)
        let small = initStaticWaveletMatrix(@[0'u8, 255'u8])
        check small[1] == 255'u8
        let signed = initStaticWaveletMatrix(@[0, int.high])
        check signed[1] == int.high

    test "all equal, generic compression and input independence":
        let emptyCompressed = initCompressedStaticWaveletMatrix(newSeq[int]())
        check emptyCompressed.rangeFreq(0..<0, int.high) == 0
        check emptyCompressed.rank(0, 0) == 0
        check emptyCompressed.prevValue(0..<0, 0).isNone
        expect IndexDefect: discard emptyCompressed[0]
        let zeros = initStaticWaveletMatrix(newSeq[int](128))
        check zeros.rank(0, 128) == 128
        check zeros.rangeFreq(0..<128, 1) == 128
        let equal = initCompressedStaticWaveletMatrix(@[-1, -1])
        check equal.rank(-1, 2) == 2
        check equal.rangeFreq(0..<2, 0) == 2
        let words = initCompressedStaticWaveletMatrix(@["z", "a", "a"])
        check words.kthSmallest(0..<3, 0) == "a"
        check words.nextValue(0..<3, "zz").isNone
        var a = @[3, 1, 2]
        let raw = initStaticWaveletMatrix(a)
        let comp = initCompressedStaticWaveletMatrix(a)
        check a == @[3, 1, 2]
        a[0] = 99
        check raw[0] == 3 and comp[0] == 3

    test "invalid arguments fail even in release":
        expect ValueError: discard initStaticWaveletMatrix(@[-1])
        expect ValueError: discard initStaticWaveletMatrix(@[4], 2)
        expect ValueError: discard initStaticWaveletMatrix(@[0], -1)
        expect ValueError: discard initStaticWaveletMatrix(@[0], 65)
        let raw = initStaticWaveletMatrix(@[0, 1])
        let comp = initCompressedStaticWaveletMatrix(@[-1, 1])
        expect IndexDefect: discard raw[-1]
        expect IndexDefect: discard raw[2]
        expect IndexDefect: discard raw.rank(0, 3)
        expect IndexDefect: discard comp.rank(999, 3)
        expect IndexDefect: discard raw.kthSmallest(0..<0, 0)
        expect IndexDefect: discard comp.kthLargest(0..<2, 2)
        expect IndexDefect: discard raw.kthLargest(0..<2, int.low)
        expect IndexDefect: discard raw.rangeFreq(-1..<1, 1)
        expect IndexDefect: discard raw.rangeFreq(2..<1, 1)
        expect IndexDefect: discard raw.rangeFreq(0..int.high, 1)
        expect ValueError: discard comp.rangeFreq(0..<2, 5, -5)
        let empty = initStaticWaveletMatrix(newSeq[int]())
        check empty.rangeFreq(0..<0, 1) == 0
        check empty.rank(0, 0) == 0
        check empty.nextValue(0..<0, 0).isNone

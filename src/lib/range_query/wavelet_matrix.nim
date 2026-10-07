# 静的な区間順位・個数検索。ACLに依存しない。
import std/[algorithm, bitops, options]
export options

type
    WmBits = object
        words: seq[uint64]
        prefix: seq[int]
    StaticWaveletMatrix*[T: SomeInteger] = object
        length, levels: int
        bits: seq[WmBits]
        middle: seq[int]
    CompressedStaticWaveletMatrix*[T] = object
        values: seq[T]
        matrix: StaticWaveletMatrix[int]

proc rankOne(bits: WmBits, stop: int): int {.inline.} =
    let word = stop shr 6
    let offset = stop and 63
    result = bits.prefix[word]
    if offset != 0:
        result += countSetBits(bits.words[word] and ((1'u64 shl offset) - 1))

proc len*[T](wm: StaticWaveletMatrix[T]): int {.inline.} = wm.length
proc len*[T](wm: CompressedStaticWaveletMatrix[T]): int {.inline.} = wm.matrix.len

proc endpoints(length: int, p: Slice[int]): (int, int) =
    if p.a < 0 or p.a > length or p.b < -1 or p.b >= length or p.b < p.a - 1:
        raise newException(IndexDefect, "invalid wavelet matrix range")
    (p.a, p.b + 1)

proc fits[T: SomeInteger](x: T, levels: int): bool {.inline.} =
    when T is SomeSignedInt:
        if x < 0: return false
    levels == 64 or (uint64(x) shr levels) == 0

proc initStaticWaveletMatrix*[T: SomeInteger](a: openArray[T],
    bitWidth = 0): StaticWaveletMatrix[T] =
    if bitWidth < 0 or bitWidth > sizeof(T) * 8:
        raise newException(ValueError, "invalid bit width")
    var maximum = 0'u64
    for x in a:
        when T is SomeSignedInt:
            if x < 0: raise newException(ValueError, "use compressed matrix for negative values")
        maximum = max(maximum, uint64(x))
    var required = 0
    while maximum != 0:
        inc required
        maximum = maximum shr 1
    result.levels = if bitWidth == 0: max(1, required) else: bitWidth
    if result.levels < required:
        raise newException(ValueError, "bit width cannot represent all values")
    result.length = a.len
    result.bits.setLen(result.levels)
    result.middle.setLen(result.levels)
    var current = @a
    var buffer = newSeq[T](a.len)
    for level in countdown(result.levels - 1, 0):
        let words = (a.len div 64) + ord(a.len mod 64 != 0)
        result.bits[level].words.setLen(words)
        result.bits[level].prefix.setLen(words + 1)
        var zeros = 0
        for i, x in current:
            if ((uint64(x) shr level) and 1) != 0:
                result.bits[level].words[i shr 6] =
                    result.bits[level].words[i shr 6] or (1'u64 shl (i and 63))
            else: inc zeros
        for i in 0..<words:
            result.bits[level].prefix[i + 1] = result.bits[level].prefix[i] +
                countSetBits(result.bits[level].words[i])
        result.middle[level] = zeros
        var left = 0
        var right = zeros
        for x in current:
            if ((uint64(x) shr level) and 1) == 0:
                buffer[left] = x
                inc left
            else:
                buffer[right] = x
                inc right
        swap(current, buffer)

proc access*[T](wm: StaticWaveletMatrix[T], index: int): T =
    if index < 0 or index >= wm.len:
        raise newException(IndexDefect, "invalid wavelet matrix index")
    var position = index
    var value = 0'u64
    for level in countdown(wm.levels - 1, 0):
        let one = ((wm.bits[level].words[position shr 6] shr (position and 63)) and 1) != 0
        let count = wm.bits[level].rankOne(position)
        if one:
            value = value or (1'u64 shl level)
            position = wm.middle[level] + count
        else: position -= count
    T(value)

proc `[]`*[T](wm: StaticWaveletMatrix[T], index: int): T = wm.access(index)

proc rank*[T](wm: StaticWaveletMatrix[T], x: T, stop: int): int =
    if stop < 0 or stop > wm.len:
        raise newException(IndexDefect, "invalid wavelet matrix prefix")
    if not fits(x, wm.levels): return 0
    var left = 0
    var right = stop
    for level in countdown(wm.levels - 1, 0):
        let l = wm.bits[level].rankOne(left)
        let r = wm.bits[level].rankOne(right)
        if ((uint64(x) shr level) and 1) != 0:
            left = wm.middle[level] + l
            right = wm.middle[level] + r
        else:
            left -= l
            right -= r
    right - left

proc kthSmallest*[T](wm: StaticWaveletMatrix[T], p: Slice[int], k: int): T =
    var (left, right) = endpoints(wm.len, p)
    if k < 0 or k >= right - left:
        raise newException(IndexDefect, "invalid wavelet matrix rank")
    var remaining = k
    var value = 0'u64
    for level in countdown(wm.levels - 1, 0):
        let l = wm.bits[level].rankOne(left)
        let r = wm.bits[level].rankOne(right)
        let zeros = (right - left) - (r - l)
        if remaining < zeros:
            left -= l
            right -= r
        else:
            remaining -= zeros
            value = value or (1'u64 shl level)
            left = wm.middle[level] + l
            right = wm.middle[level] + r
    T(value)

proc kthLargest*[T](wm: StaticWaveletMatrix[T], p: Slice[int], k: int): T =
    let (left, right) = endpoints(wm.len, p)
    if k < 0 or k >= right - left:
        raise newException(IndexDefect, "invalid wavelet matrix rank")
    wm.kthSmallest(p, right - left - 1 - k)

proc rangeFreq*[T](wm: StaticWaveletMatrix[T], p: Slice[int], upper: T): int =
    var (left, right) = endpoints(wm.len, p)
    when T is SomeSignedInt:
        if upper <= 0: return 0
    if not fits(upper, wm.levels): return right - left
    for level in countdown(wm.levels - 1, 0):
        let l = wm.bits[level].rankOne(left)
        let r = wm.bits[level].rankOne(right)
        if ((uint64(upper) shr level) and 1) != 0:
            result += (right - left) - (r - l)
            left = wm.middle[level] + l
            right = wm.middle[level] + r
        else:
            left -= l
            right -= r

proc rangeFreq*[T](wm: StaticWaveletMatrix[T], p: Slice[int], lower, upper: T): int =
    if upper < lower: raise newException(ValueError, "reversed value range")
    wm.rangeFreq(p, upper) - wm.rangeFreq(p, lower)

proc prevValue*[T](wm: StaticWaveletMatrix[T], p: Slice[int], upper: T): Option[T] =
    let count = wm.rangeFreq(p, upper)
    if count > 0: some(wm.kthSmallest(p, count - 1)) else: none(T)

proc nextValue*[T](wm: StaticWaveletMatrix[T], p: Slice[int], lower: T): Option[T] =
    let (left, right) = endpoints(wm.len, p)
    let count = wm.rangeFreq(p, lower)
    if count < right - left: some(wm.kthSmallest(p, count)) else: none(T)

proc initCompressedStaticWaveletMatrix*[T](a: openArray[T]): CompressedStaticWaveletMatrix[T] =
    var sorted = @a
    sorted.sort()
    for x in sorted:
        if result.values.len == 0 or result.values[^1] != x:
            result.values.add(x)
    var indices = newSeq[int](a.len)
    for i, x in a: indices[i] = result.values.lowerBound(x)
    result.matrix = initStaticWaveletMatrix(indices)

proc access*[T](wm: CompressedStaticWaveletMatrix[T], index: int): T =
    wm.values[wm.matrix.access(index)]
proc `[]`*[T](wm: CompressedStaticWaveletMatrix[T], index: int): T = wm.access(index)
proc rank*[T](wm: CompressedStaticWaveletMatrix[T], x: T, stop: int): int =
    if stop < 0 or stop > wm.len:
        raise newException(IndexDefect, "invalid wavelet matrix prefix")
    let index = wm.values.lowerBound(x)
    if index == wm.values.len or wm.values[index] != x: return 0
    wm.matrix.rank(index, stop)
proc kthSmallest*[T](wm: CompressedStaticWaveletMatrix[T], p: Slice[int], k: int): T =
    wm.values[wm.matrix.kthSmallest(p, k)]
proc kthLargest*[T](wm: CompressedStaticWaveletMatrix[T], p: Slice[int], k: int): T =
    wm.values[wm.matrix.kthLargest(p, k)]
proc rangeFreq*[T](wm: CompressedStaticWaveletMatrix[T], p: Slice[int], upper: T): int =
    wm.matrix.rangeFreq(p, wm.values.lowerBound(upper))
proc rangeFreq*[T](wm: CompressedStaticWaveletMatrix[T], p: Slice[int], lower, upper: T): int =
    if upper < lower: raise newException(ValueError, "reversed value range")
    wm.rangeFreq(p, upper) - wm.rangeFreq(p, lower)
proc prevValue*[T](wm: CompressedStaticWaveletMatrix[T], p: Slice[int], upper: T): Option[T] =
    let index = wm.matrix.prevValue(p, wm.values.lowerBound(upper))
    if index.isSome: some(wm.values[index.get]) else: none(T)
proc nextValue*[T](wm: CompressedStaticWaveletMatrix[T], p: Slice[int], lower: T): Option[T] =
    let index = wm.matrix.nextValue(p, wm.values.lowerBound(lower))
    if index.isSome: some(wm.values[index.get]) else: none(T)

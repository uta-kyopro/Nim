
include ../header
# import std/bitops

# bit区切りでuintに複数値を格納, 取り出し
when not declared BitPackingModule:
    const bitMask64: seq[uint64] = (0..32).toSeq().mapIt(toMask[uint64](0..<it))
    const bitMask32: seq[uint32] = (0..16).toSeq().mapIt(toMask[uint32](0..<it))
    const bitMask16: seq[uint16] = (0..8).toSeq().mapIt(toMask[uint16](0..<it))
    const bitMask8: seq[uint8] = (0..4).toSeq().mapIt(toMask[uint8](0..<it))
    proc `[]`(b: uint64, n, bit: int): int {.inline.}=
        return cast[int]((b shr (n*bit)).masked(bitMask64[bit]))
    proc `[]`(b: uint32, n, bit: int): int {.inline.}=
        return cast[int]((b shr (n*bit)).masked(bitMask32[bit]))
    proc `[]`(b: uint16, n, bit: int): int {.inline.}=
        return cast[int]((b shr (n*bit)).masked(bitMask16[bit]))
    proc `[]`(b: uint8, n, bit: int): int {.inline.}=
        return cast[int]((b shr (n*bit)).masked(bitMask8[bit]))
    proc `[]=`(b: var uint64, n, bit, v: int) {.inline.}=
        clearMask(b, bitMask64[bit] shl (n*bit))
        setMask(b, cast[uint64](v).masked(bitMask64[bit]) shl (n*bit))
    proc `[]=`(b: var uint32, n, bit, v: int) {.inline.}=
        clearMask(b, bitMask32[bit] shl (n*bit))
        setMask(b, cast[uint32](v).masked(bitMask32[bit]) shl (n*bit))
    proc `[]=`(b: var uint16, n, bit, v: int) {.inline.}=
        clearMask(b, bitMask16[bit] shl (n*bit))
        setMask(b, cast[uint16](v).masked(bitMask16[bit]) shl (n*bit))
    proc `[]=`(b: var uint8, n, bit, v: int) {.inline.}=
        clearMask(b, bitMask8[bit] shl (n*bit))
        setMask(b, cast[uint8](v).masked(bitMask8[bit]) shl (n*bit))

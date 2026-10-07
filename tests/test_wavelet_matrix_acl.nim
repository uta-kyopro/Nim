import std/[algorithm, sequtils, sets]
when defined(aclFirst):
    include atcoder/extra/structure/wavelet_matrix
import ../src/lib/range_query/wavelet_matrix
when not defined(aclFirst):
    include atcoder/extra/structure/wavelet_matrix

# ACLの型を隠さず共存できることを確認（既知不具合のあるACLの構築は呼ばない）。
var acl: WaveletMatrix[int, 3]
var aclCompressed: CompressedWaveletMatrix[int, 3]
let own: StaticWaveletMatrix[int] = initStaticWaveletMatrix(@[1, 0, 3])
let compressed: CompressedStaticWaveletMatrix[int] =
    initCompressedStaticWaveletMatrix(@[-1, 0, 3])
doAssert own[2] == 3
doAssert compressed.prevValue(0..<3, 0) == some(-1)

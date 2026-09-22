
include ../../src/lib/header
import atcoder/segtree


# 区間 xor
# ---------- xor ----------
proc xorOp(a, b: int): int =
    a xor b

proc xorE(): int = 0

type XorSeg = SegTreeType[int](xorOp, xorE)

# 使用例
var A = @[1, 2, 3, 4, 5]

var sgXor = initSegTree(A, xorOp, xorE)

echo sgXor.prod(0..<3)
# 1 xor 2 xor 3 = 0

echo sgXor.prod(1..<5)
# 2 xor 3 xor 4 xor 5 = 0



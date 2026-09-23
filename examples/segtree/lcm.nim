
include ../../src/lib/header
import atcoder/segtree


# 区間 lcm
# ---------- lcm ----------
proc lcmOp(a, b: int): int =
    lcm(a, b)
proc lcmE(): int =
    1
type LcmSeg = SegTreeType[int](lcmOp, lcmE)

# 使用例
var A = @[2, 3, 4, 6]

var sgLcm = initSegTree(A, lcmOp, lcmE)

echo sgLcm.prod(0..<3)
# lcm(2, 3, 4) = 12




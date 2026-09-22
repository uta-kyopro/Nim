
include ../../src/lib/header
import atcoder/segtree

# ---------- sum ----------
proc sumOp(a, b: int): int = a + b
proc sumE(): int = 0
type SumSeg = SegTreeType[int](sumOp, sumE)

# 使用例
var A = @[1, 5, 2, 4, 3]

var sgSum = initSegTree(A, sumOp, sumE)

# [l, r) の区間和
echo sgSum.prod(1..<4)   # 5 + 2 + 4 = 11

# 1点更新
sgSum.set(2, 10)

# 全区間の和
echo sgSum.allProd()


# 平均が計算可能 (値, 個数)
# ---------- sum + count ----------
proc sumOpCount(a, b: (int, int)): (int, int) =
    (a[0] + b[0], a[1] + b[1])

proc sumECount(): (int, int) =
    (0, 0)

type SumSegCount = SegTreeType[(int, int)](sumOpCount, sumECount)

# 使用例
var base = A.mapIt((it, 1))
var sgSumCount = initSegTree(base, sumOpCount, sumECount)

let res = sgSumCount.prod(1..<4)
echo res[0]   # sum
echo res[1]   # count

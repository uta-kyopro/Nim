
include ../../src/lib/header
import atcoder/segtree

# ---------- max ----------
proc maxOp(a, b: int): int= max(a, b)
proc maxE():int = -inf
type MaxSeg = SegTreeType[int](maxOp,maxE)

# 使用例
var A = @[1, 5, 2, 4, 3]

var sgMax = initSegTree(A, maxOp, maxE)


# ---------- max + index ----------
proc maxOpIndex(a, b: (int, int)): (int, int)= 
    if a[0] >= b[0]: return a
    else: return b
proc maxEIndex(): (int, int)= (-inf, -1)
type MaxSegIndex = SegTreeType[(int, int)](maxOpIndex, maxEIndex)

# 使用例
var base = (0..<10).toSeq.mapIt((A[it], it))

var sgMaxIdx = initSegTree(base, maxOpIndex, maxEIndex)


# 区間最大値 + 最大値の個数
# ---------- max + count ----------
proc maxCountOp(a, b: (int, int)): (int, int) =
    if a[0] > b[0]:
        return a
    elif a[0] < b[0]:
        return b
    else:
        return (a[0], a[1] + b[1])

proc maxCountE(): (int, int) = (-inf, 0)

type MaxCountSeg = SegTreeType[(int, int)](maxCountOp, maxCountE)

# 使用例
var base3 = A.mapIt((it, 1))

var sgMaxCount = initSegTree(base3, maxCountOp, maxCountE)

echo sgMaxCount.prod(0..<5)
# 例: A = @[3, 5, 4, 5, 1]
# (5, 2)



# ============================================================
# 最大値・第2最大値 + それぞれの個数
# ============================================================
type Max2CountNode = tuple
    max1: int
    count1: int
    max2: int
    count2: int

proc max2CountE(): Max2CountNode =
    (max1: -inf, count1: 0, max2: -inf, count2: 0)

proc max2CountOp(a, b: Max2CountNode): Max2CountNode =
    result = max2CountE()

    template add(v, cnt: int) =
        if cnt > 0:
            if v > result.max1:
                result.max2 = result.max1
                result.count2 = result.count1
                result.max1 = v
                result.count1 = cnt
            elif v == result.max1:
                result.count1 += cnt
            elif v > result.max2:
                result.max2 = v
                result.count2 = cnt
            elif v == result.max2:
                result.count2 += cnt

    add(a.max1, a.count1)
    add(a.max2, a.count2)
    add(b.max1, b.count1)
    add(b.max2, b.count2)

type Max2CountSeg =
    SegTreeType[Max2CountNode](max2CountOp, max2CountE)

# 使用例
var baseMax2 = A.mapIt(
    (max1: it, count1: 1, max2: -inf, count2: 0)
)

var sgMax2 =
    initSegTree(baseMax2, max2CountOp, max2CountE)

echo sgMax2.prod(0..<A.len)
# max1 = 5, count1 = 2
# max2 = 4, count2 = 2


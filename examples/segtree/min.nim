
include ../../src/lib/header
import atcoder/segtree

# ---------- min ----------
proc minOp(a, b: int): int= min(a, b)
proc minE():int = inf
type MinSeg = SegTreeType[int](minOp,minE)

# 使用例
var A = @[1, 5, 2, 4, 3]

var sgMin = initSegTree(A, minOp, minE)


# ---------- min + index ----------
proc minOpIndex(a, b: (int, int)): (int, int)= 
    if a[0] <= b[0]: return a
    else: return b
proc minEIndex(): (int, int)= (inf, -1)
type MinSegIndex = SegTreeType[(int, int)](minOpIndex, minEIndex)

# 使用例
var base = (0..<10).toSeq.mapIt((A[it], it))

var sgMinIdx = initSegTree(base, minOpIndex, minEIndex)


# 区間最小値 + 最小値の個数
# ---------- min + count ----------
proc minCountOp(a, b: (int, int)): (int, int) =
    if a[0] < b[0]:
        return a
    elif a[0] > b[0]:
        return b
    else:
        return (a[0], a[1] + b[1])

proc minCountE(): (int, int) = (inf, 0)

type MinCountSeg = SegTreeType[(int, int)](minCountOp, minCountE)

# 使用例
var base2 = A.mapIt((it, 1))

var sgMinCount = initSegTree(base2, minCountOp, minCountE)

echo sgMinCount.prod(0..<5)
# (1, 2)


# ============================================================
# 最小値・第2最小値 + それぞれの個数
# ============================================================
type Min2CountNode = tuple
    min1: int
    count1: int
    min2: int
    count2: int

proc min2CountE(): Min2CountNode =
    (min1: inf, count1: 0, min2: inf, count2: 0)
proc min2CountOp(a, b: Min2CountNode): Min2CountNode =
    result = min2CountE()

    template add(v, cnt: int) =
        if cnt > 0:
            if v < result.min1:
                result.min2 = result.min1
                result.count2 = result.count1
                result.min1 = v
                result.count1 = cnt
            elif v == result.min1:
                result.count1 += cnt
            elif v < result.min2:
                result.min2 = v
                result.count2 = cnt
            elif v == result.min2:
                result.count2 += cnt

    add(a.min1, a.count1)
    add(a.min2, a.count2)
    add(b.min1, b.count1)
    add(b.min2, b.count2)

type Min2CountSeg =
    SegTreeType[Min2CountNode](min2CountOp, min2CountE)

# 使用例
var baseMin2 = A.mapIt(
    (min1: it, count1: 1, min2: inf, count2: 0)
)

var sgMin2 =
    initSegTree(baseMin2, min2CountOp, min2CountE)

echo sgMin2.prod(0..<A.len)
# A = @[1,5,3,5,4,4]
# min1 = 1, count1 = 1
# min2 = 3, count2 = 1



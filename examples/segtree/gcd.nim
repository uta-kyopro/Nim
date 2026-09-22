
include ../../src/lib/header
import atcoder/segtree


# 区間 gcd
# ---------- gcd ----------
proc gcdOp(a, b: int): int =
    gcd(a, b)
proc gcdE(): int = 0
type GcdSeg = SegTreeType[int](gcdOp, gcdE)

# 使用例
var A = @[12, 18, 24, 30, 42]

var sgGcd = initSegTree(A, gcdOp, gcdE)

echo sgGcd.prod(0..<3)
# gcd(12, 18, 24) = 6

echo sgGcd.prod(1..<5)
# gcd(18, 24, 30, 42) = 6


# 区間GCD + GCDと等しい値の個数
# ---------- gcd + count ----------
type GcdCountNode = tuple
    g: int
    count: int

proc gcdCountE(): GcdCountNode =
    (g: 0, count: 0)
proc gcdCountOp(a, b: GcdCountNode): GcdCountNode =
    let g = gcd(a.g, b.g)

    var cnt = 0
    if a.g == g:
        cnt += a.count
    if b.g == g:
        cnt += b.count

    (g: g, count: cnt)

type GcdCountSeg =
    SegTreeType[GcdCountNode](gcdCountOp, gcdCountE)

# 使用例
var base = A.mapIt((g: it, count: 1))
var sgGcdCount = initSegTree(base, gcdCountOp, gcdCountE)

let res = sgGcdCount.prod(0..<A.len)

echo res.g
# 2

echo res.count
# 2


import std/sequtils
import atcoder/lazysegtree

# 区間加算・代入・乗算 + 区間最小値・最大値。各操作 O(log N)。
# 値・係数・途中の積がintに収まる場合に使う。
type S = tuple[mn, mx, len: int]
type F = tuple[a, b: int]

proc op(x, y: S): S =
    if x.len == 0: return y
    if y.len == 0: return x
    (min(x.mn, y.mn), max(x.mx, y.mx), x.len + y.len)
proc e(): S = (0, 0, 0)
proc leaf(x: int): S = (x, x, 1)
proc mapping(f: F, x: S): S =
    if x.len == 0: return x
    if f.a >= 0:
        (f.a * x.mn + f.b, f.a * x.mx + f.b, x.len)
    else: # 負の係数では最小値・最大値が入れ替わる
        (f.a * x.mx + f.b, f.a * x.mn + f.b, x.len)
# 古いgの後に新しいfを適用する。
proc composition(f, g: F): F = (f.a * g.a, f.a * g.b + f.b)
proc id(): F = (1, 0)
type AffineMinMaxSeg =
    LazySegTreeType[S, F](op, e, mapping, composition, id)

when isMainModule:
    let a = @[1, 2, 3, 4, 5]
    var sg = AffineMinMaxSeg.init(a.mapIt(leaf(it)))
    sg.apply(0..<5, (a: 1, b: 3))  # 加算: [4, 5, 6, 7, 8]
    sg.apply(1..<4, (a: 0, b: 2))  # 代入: [4, 2, 2, 2, 8]
    sg.apply(0..<5, (a: -2, b: 1)) # [-7, -3, -3, -3, -15]
    echo sg.allProd().mn           # -15
    echo sg.allProd().mx           # -3
    doAssert sg.prod(1..<4) == (mn: -3, mx: -3, len: 3)
    doAssert sg.get(4).mn == -15
    sg.apply(0..<5, (a: -1, b: 2)) # [9, 5, 5, 5, 17]
    doAssert sg.allProd() == (mn: 5, mx: 17, len: 5)
    sg.set(2, leaf(-10))
    doAssert sg.prod(1..<4).mn == -10
    doAssert sg.prod(2..<2) == e()
    doAssert mapping((a: -2, b: 3), e()) == e()

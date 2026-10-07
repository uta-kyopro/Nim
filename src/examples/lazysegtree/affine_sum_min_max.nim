import std/sequtils
import atcoder/lazysegtree

# 区間加算・代入・乗算 + 和・最小値・最大値。構築O(N)、各操作O(log N)。
# 値・和・係数・途中の積がintに収まる場合に使う（AOJでは64bit環境）。
type S = tuple[sum, mn, mx, len: int]
type F = tuple[a, b: int]

proc op(x, y: S): S =
    if x.len == 0: return y
    if y.len == 0: return x
    (x.sum + y.sum, min(x.mn, y.mn), max(x.mx, y.mx), x.len + y.len)
proc e(): S = (0, 0, 0, 0)
proc leaf(x: int): S = (x, x, x, 1)
proc mapping(f: F, x: S): S =
    if x.len == 0: return x
    let total = f.a * x.sum + f.b * x.len
    if f.a >= 0:
        (total, f.a * x.mn + f.b, f.a * x.mx + f.b, x.len)
    else:
        (total, f.a * x.mx + f.b, f.a * x.mn + f.b, x.len)
# 古いgの後に新しいf。
proc composition(f, g: F): F = (f.a * g.a, f.a * g.b + f.b)
proc id(): F = (1, 0)
type AffineSumMinMaxSeg =
    LazySegTreeType[S, F](op, e, mapping, composition, id)

when isMainModule:
    let a = @[1, 2, 3, 4, 5]
    var sg = AffineSumMinMaxSeg.init(a.mapIt(leaf(it)))
    sg.apply(1..<4, (a: 1, b: 3)) # 区間加算: [1, 5, 6, 7, 5]
    sg.apply(2..<5, (a: 0, b: 2)) # 区間代入: [1, 5, 2, 2, 2]
    sg.apply(0, (a: 1, b: 4))     # 1点加算: [5, 5, 2, 2, 2]
    sg.set(1, leaf(7))            # 1点代入: [5, 7, 2, 2, 2]
    echo sg.get(1).sum            # 7
    let res = sg.prod(0..<5)
    echo res.sum                 # 18
    echo res.mn                  # 2
    echo res.mx                  # 7
    doAssert res == (sum: 18, mn: 2, mx: 7, len: 5)
    sg.apply(0..<5, (a: -2, b: 1))
    doAssert sg.allProd() == (sum: -31, mn: -13, mx: -3, len: 5)

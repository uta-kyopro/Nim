import std/sequtils
import atcoder/lazysegtree

# 区間アフィン変換 x <- a*x+b + 区間和。
# int版。値・和・遅延タグの係数・途中の積がintに収まる場合に使う。
type S = tuple[sum, len: int]
type F = tuple[a, b: int]

proc op(x, y: S): S = (x.sum + y.sum, x.len + y.len)
proc e(): S = (0, 0)
proc mapping(f: F, x: S): S = (f.a * x.sum + f.b * x.len, x.len)
# f(g(x)) = f.a*g.a*x + f.a*g.b + f.b（gが先、fが後）。
proc composition(f, g: F): F = (f.a * g.a, f.a * g.b + f.b)
proc id(): F = (1, 0)
type AffineSumSeg = LazySegTreeType[S, F](op, e, mapping, composition, id)

when isMainModule:
  let a = @[1, 2, 3, 4, 5]
  var sg = AffineSumSeg.init(a.mapIt((sum: it, len: 1)))
  sg.apply(0..<5, (a: 2, b: 3)) # [5, 7, 9, 11, 13]
  sg.apply(0..<5, (a: 3, b: 1)) # [16, 22, 28, 34, 40]
  echo sg.prod(1..<4).sum        # 84（合成順を逆にすると異なる）
  doAssert sg.get(2).sum == 28
  sg.apply(1..<4, (a: 0, b: 5)) # 代入: [16, 5, 5, 5, 40]
  sg.apply(2..<5, (a: 1, b: 2)) # 加算: [16, 5, 7, 7, 42]
  sg.apply(0..<2, (a: 2, b: 0)) # 乗算: [32, 10, 7, 7, 42]
  doAssert sg.allProd().sum == 98
  doAssert sg.prod(2..<2) == e()

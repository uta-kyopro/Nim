import std/sequtils
import atcoder/lazysegtree

# 区間加算 + 区間最小値・最大値。len=0 で空ノードを区別する。
type S = tuple[mn, mx, len: int]
type F = int

proc op(a, b: S): S =
  if a.len == 0: return b
  if b.len == 0: return a
  (min(a.mn, b.mn), max(a.mx, b.mx), a.len + b.len)
proc e(): S = (0, 0, 0)
proc mapping(f: F, x: S): S =
  if x.len == 0: x else: (x.mn + f, x.mx + f, x.len)
proc composition(f, g: F): F = f + g
proc id(): F = 0
proc leaf(x: int): S = (x, x, 1)
type AddMinMaxSeg = LazySegTreeType[S, F](op, e, mapping, composition, id)

when isMainModule:
  let a = @[1, 2, 3, 4, 5]
  var sg = AddMinMaxSeg.init(a.mapIt(leaf(it)))
  sg.apply(1..<4, -5)  # [1, -3, -2, -1, 5]
  echo sg.allProd().mn # -3
  echo sg.allProd().mx # 5
  sg.apply(0..<5, 2)   # [3, -1, 0, 1, 7]
  doAssert sg.prod(1..<4).mn == -1
  doAssert sg.prod(1..<4).mx == 1
  sg.set(2, leaf(10))
  doAssert sg.get(2).mx == 10
  doAssert sg.allProd().mx == 10
  doAssert mapping(100, e()) == e()

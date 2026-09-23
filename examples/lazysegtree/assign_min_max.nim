import std/sequtils
import atcoder/lazysegtree

# 区間代入 + 区間最小値・最大値。番兵値を使わず任意のintを代入できる。
type S = tuple[mn, mx, len: int]
type F = tuple[active: bool, value: int]

proc op(a, b: S): S =
  if a.len == 0: return b
  if b.len == 0: return a
  (min(a.mn, b.mn), max(a.mx, b.mx), a.len + b.len)
proc e(): S = (0, 0, 0)
proc mapping(f: F, x: S): S =
  if not f.active or x.len == 0: x else: (f.value, f.value, x.len)
proc composition(f, g: F): F =
  if f.active: f else: g
proc id(): F = (false, 0)
proc leaf(x: int): S = (x, x, 1)
type AssignMinMaxSeg = LazySegTreeType[S, F](op, e, mapping, composition, id)

when isMainModule:
  let a = @[1, 2, 3, 4, 5]
  var sg = AssignMinMaxSeg.init(a.mapIt(leaf(it)))
  sg.apply(0..<5, (active: true, value: 7))
  sg.apply(1..<4, (active: true, value: -2)) # [7, -2, -2, -2, 7]
  echo sg.allProd().mn                     # -2
  echo sg.allProd().mx                     # 7
  sg.apply(2..<5, (active: true, value: 0))  # [7, -2, 0, 0, 0]
  sg.apply(0..<5, id())
  doAssert sg.prod(2..<5).mx == 0
  doAssert sg.get(1).mn == -2
  doAssert mapping((active: true, value: 3), e()) == e()

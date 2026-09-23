import std/sequtils
import atcoder/lazysegtree

# 区間代入 + 区間和。active=false が「何もしない」。
type S = tuple[sum, len: int]
type F = tuple[active: bool, value: int]

proc op(a, b: S): S = (a.sum + b.sum, a.len + b.len)
proc e(): S = (0, 0)
proc mapping(f: F, x: S): S =
  if f.active: (f.value * x.len, x.len) else: x
# f が新しい操作、g が古い操作。新しい代入が古い代入を上書きする。
proc composition(f, g: F): F =
  if f.active: f else: g
proc id(): F = (false, 0)
type AssignSumSeg = LazySegTreeType[S, F](op, e, mapping, composition, id)

when isMainModule:
  let a = @[1, 2, 3, 4, 5]
  var sg = AssignSumSeg.init(a.mapIt((sum: it, len: 1)))
  sg.apply(0..<5, (active: true, value: 7))
  sg.apply(1..<4, (active: true, value: 0))  # [7, 0, 0, 0, 7]
  echo sg.allProd().sum                    # 14
  doAssert sg.prod(1..<4).sum == 0
  sg.apply(2..<5, (active: true, value: -2)) # [7, 0, -2, -2, -2]
  sg.apply(0..<5, id())
  doAssert sg.allProd().sum == 1
  doAssert sg.get(2).sum == -2
  doAssert sg.prod(2..<2) == e()

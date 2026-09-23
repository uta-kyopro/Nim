import std/sequtils
import atcoder/lazysegtree

# 区間加算 + 区間和。各操作 O(log N)、構築 O(N)。
type S = tuple[sum, len: int]
type F = int

proc op(a, b: S): S = (a.sum + b.sum, a.len + b.len)
proc e(): S = (0, 0)
proc mapping(f: F, x: S): S = (x.sum + f * x.len, x.len)
proc composition(f, g: F): F = f + g
proc id(): F = 0
type AddSumSeg = LazySegTreeType[S, F](op, e, mapping, composition, id)

when isMainModule:
  let a = @[1, 2, 3, 4, 5]
  var sg = AddSumSeg.init(a.mapIt((sum: it, len: 1)))
  sg.apply(1..<4, 10)           # [1, 12, 13, 14, 5]
  echo sg.prod(1..<4).sum      # 39
  doAssert sg.allProd().sum == 45
  sg.apply(0..<5, -2)          # [-1, 10, 11, 12, 3]
  sg.set(2, (sum: 7, len: 1))  # 1点代入は長さ1のノード
  doAssert sg.prod(1..<4).sum == 29
  doAssert sg.get(2).sum == 7
  sg.apply(2..<2, 100)         # 空区間は何もしない
  doAssert sg.prod(2..<2) == e()

import ../../lib/collections/lazy_implicit_treap

type Affine = tuple[a, b: int64]
proc op(a, b: int64): int64 = a + b
proc mapping(f: Affine, x: int64, count: int): int64 =
    f.a * x + f.b * int64(count)
proc composition(f, g: Affine): Affine =
    (f.a * g.a, f.a * g.b + f.b)

var tree = initLazyImplicitTreap[int64, Affine](op, 0'i64, mapping, composition)
for x in [1'i64, 2, 3, 4]: tree.add(x)
tree.apply(1, 4, (2'i64, 1'i64)) # [1, 5, 7, 9]
echo tree.prod(0, 4)             # 22
tree.reverse(0, 4)              # [9, 7, 5, 1]
tree.insert(2, 100)              # [9, 7, 100, 5, 1]
tree[0] = 10
tree.rotate(0, tree.len, 1)      # [7, 100, 5, 1, 10]
echo tree.toSeq
echo tree.delete(1)             # 100
echo tree.allProd               # 23

# Lazy Segment Tree

Nim + `atcoder/lazysegtree` 用。区間更新と区間集約を扱う。

## 基本

区間加算・区間和の例。

```nim
import std/sequtils
import atcoder/lazysegtree

type S = tuple[sum, len: int]
type F = int

proc op(a, b: S): S = (a.sum + b.sum, a.len + b.len)
proc e(): S = (0, 0)
proc mapping(f: F, x: S): S = (x.sum + f * x.len, x.len)
proc composition(f, g: F): F = f + g
proc id(): F = 0

type AddSumSeg = LazySegTreeType[S, F](op, e, mapping, composition, id)

let a = @[1, 2, 3, 4, 5]
var sg = AddSumSeg.init(a.mapIt((sum: it, len: 1)))
sg.apply(1..<4, 10)      # [1, 12, 13, 14, 5]
echo sg.prod(1..<4).sum  # 39
```

| 定義 | 意味 |
| --- | --- |
| `op(a, b)` / `e()` | 区間の結合 / 空区間の値 |
| `mapping(f, x)` | ノード `x` に操作 `f` を適用 |
| `composition(f, g)` | **古い操作 `g` の後に、新しい操作 `f`** |
| `id()` | 何もしない操作 |

### 操作

```nim
sg.apply(l..<r, f) # [l, r) に操作 f
sg.apply(i, f)    # 1点に操作 f
sg.set(i, x)      # 1点のノードを置き換え
sg.get(i)         # 1点取得
sg.prod(l..<r)    # 区間集約
sg.allProd()      # 全区間
```

添字は0始まり、右端を含まない。空区間の `prod` は `e()`。

| 操作 | 計算量 |
| --- | --- |
| 配列から構築 | O(N) |
| `apply`・`set`・`get`・`prod` | O(log N) |
| `allProd` | O(1) |
| `max_right` / `min_left` | O(log N) |

空間 O(N)。各結合・操作・判定が O(1) の場合。通常のSegTreeと異なり `get` も O(log N)。

---

## 実装例一覧

よく使う基本形から掲載。各ファイルに型定義・操作・使用例をまとめている。

| ファイル | 区間更新 | 区間取得 | ノード `S` | 操作 `F` / 恒等操作 |
| --- | --- | --- | --- | --- |
| [add_sum.nim](../examples/lazysegtree/add_sum.nim) | 加算 | 和 | `(sum, len)` | 加算量 / `0` |
| [assign_sum.nim](../examples/lazysegtree/assign_sum.nim) | 代入 | 和 | `(sum, len)` | `(active, value)` / `(false, 0)` |
| [add_min_max.nim](../examples/lazysegtree/add_min_max.nim) | 加算 | 最小値・最大値 | `(mn, mx, len)` | 加算量 / `0` |
| [assign_min_max.nim](../examples/lazysegtree/assign_min_max.nim) | 代入 | 最小値・最大値 | `(mn, mx, len)` | `(active, value)` / `(false, 0)` |
| [affine_sum.nim](../examples/lazysegtree/affine_sum.nim) | `x ← a*x+b` | 和 | `(sum, len)` | `(a, b)` / `(1, 0)` |

### 注意点

- 葉は長さ1、空ノードは長さ0。`init(N)` は `e()` で埋めるため、ゼロ配列も `(sum: 0, len: 1)` の配列から作る。
- 代入は `(active: true, value: x)`。0代入も可能。
- 極値は `.mn` / `.mx`。空ノード（`len == 0`）の極値には意味がない。
- アフィン変換は加算 `(1, c)`・代入 `(0, c)`・乗算 `(c, 0)`。合成は `(f.a*g.a, f.a*g.b+f.b)`。
- 掲載例は `int` 版。和・積・遅延タグの係数のオーバーフローに注意。

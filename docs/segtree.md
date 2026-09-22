# Segment Tree

Nim + `atcoder/segtree` 用。1点更新と区間集約を扱う。

## 基本

```nim
import atcoder/segtree

proc op(a, b: int): int = max(a, b)
proc e(): int = int.low

var A = @[1, 5, 2, 4, 3]
var sg = initSegTree(A, op, e)

echo sg.prod(1..<4)  # 5
sg.set(2, 10)
echo sg.allProd()   # 10
```

`op(a, b)` は左区間と右区間を結合する関数、`e()` は空区間の値（単位元）。
`op` には結合則が必要で、`op(e(), x) = op(x, e()) = x` を満たすように定義する。
可換である必要はなく、最長連続長などでは左右の順序を保って結合する。

例の `inf` は `src/lib/header.nim` で定義した整数の番兵値。
`inf` / `-inf` を使う例では、実際の値を `-inf < x < inf` の範囲に収める。

### 操作

```nim
sg.set(i, x)       # A[i] = x
sg.get(i)          # A[i]
sg.prod(l..<r)     # [l,r)
sg.allProd()       # 全区間
```

添字は0始まり、`prod(l..<r)` は右端を含まない半開区間。空区間の結果は `e()`。
`set` は代入なので、加算更新なら `sg.set(i, sg.get(i) + delta)` とする。
木への更新は、初期化に使った配列 `A` には反映されない。

| 操作 | 内容 | 計算量 |
| --- | --- | --- |
| `initSegTree(A, op, e)` | 配列から構築 | O(N) |
| `set(i, x)` | 1点代入 | O(log N) |
| `get(i)` | 1点取得 | O(1) |
| `prod(l..<r)` | 区間の集約 | O(log N) |
| `allProd()` | 全区間の集約 | O(1) |
| `max_right` / `min_left` | 条件を満たす区間の境界探索 | O(log N) |

空間計算量は O(N)。上表は `op`・`e`・境界探索の判定が O(1) の場合。
GCD の結合には整数の大きさに応じた計算コストが加わる。
境界探索では `f(e()) = true` と、区間を伸ばすと判定が true から false へ単調に変化する条件を使う。

---

## 実装例一覧

各ファイルに結合関数・単位元・型定義・使用例をまとめている。
複合ノードを使う場合は、元の値を葉ノードへ変換してから初期化する。

| ファイル | 用途 | 保持する値 | 単位元 |
| --- | --- | --- | --- |
| [max.nim](../examples/segtree/max.nim) | 区間最大値 | 最大値 | `-inf` |
| 同上 | 最大値と位置 | `(値, index)` | `(-inf, -1)` |
| 同上 | 最大値とその個数 | `(値, 個数)` | `(-inf, 0)` |
| 同上 | 最大値・第2最大値と各個数 | `(max1, count1, max2, count2)` | `(-inf, 0, -inf, 0)` |
| [min.nim](../examples/segtree/min.nim) | 区間最小値 | 最小値 | `inf` |
| 同上 | 最小値と位置 | `(値, index)` | `(inf, -1)` |
| 同上 | 最小値とその個数 | `(値, 個数)` | `(inf, 0)` |
| 同上 | 最小値・第2最小値と各個数 | `(min1, count1, min2, count2)` | `(inf, 0, inf, 0)` |
| [sum.nim](../examples/segtree/sum.nim) | 区間和 | 合計 | `0` |
| 同上 | 区間和と要素数（平均用） | `(合計, 個数)` | `(0, 0)` |
| [gcd.nim](../examples/segtree/gcd.nim) | 区間GCD | GCD | `0` |
| 同上 | 区間GCDと、それに等しい要素の個数 | `(g, count)` | `(0, 0)` |
| [xor.nim](../examples/segtree/xor.nim) | 区間XOR | XOR | `0` |
| [longest_run.nim](../examples/segtree/longest_run.nim) | 同じ文字が連続する最長区間 | 区間長・両端文字・接頭/接尾連続長・最長連続長 | 長さ0のノード |

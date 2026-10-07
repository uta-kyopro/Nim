# Range Query（AOJ DSL_2）

1次元は [affine_sum_min_max.nim](../src/examples/lazysegtree/affine_sum_min_max.nim) に集約。
2次元領域検索は [range_search.nim](../src/examples/kd_tree/range_search.nim)（既存kD Tree）。

## 1次元の操作

```nim
# affine_sum_min_max.nim の定義を使用
var sg = AffineSumMinMaxSeg.init(A.mapIt(leaf(it)))
sg.set(i, leaf(x))              # 1点代入
sg.apply(i, (a: 1, b: x))       # 1点加算
sg.apply(l..<r, (a: 0, b: x))   # 区間代入
sg.apply(l..<r, (a: 1, b: x))   # 区間加算
echo sg.get(i).sum              # 1点取得
echo sg.prod(l..<r).sum         # 区間和
echo sg.prod(l..<r).mn          # 区間最小値
echo sg.prod(l..<r).mx          # 区間最大値
```

構築 O(N)、各操作 O(log N)、空間 O(N)。添字は0始まり、区間は半開。
同じ初期値なら `newSeqWith(N, leaf(initial))` から構築する。`init(N)` は使わない。

## AOJ対応表

| 問題 | 更新 | 取得 | 初期値 | AOJの添字 |
| --- | --- | --- | --- | --- |
| [2_A](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_A) | 1点代入 | 区間最小値 | `2147483647` | 0始まり |
| [2_B](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_B) | 1点加算 | 区間和 | `0` | 1始まり |
| [2_C](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_C) | なし | 長方形内の点番号 | 点集合 | 番号は0始まり |
| [2_D](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_D) | 区間代入 | 1点 | `2147483647` | 0始まり |
| [2_E](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_E) | 区間加算 | 1点 | `0` | 1始まり |
| [2_F](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_F) | 区間代入 | 区間最小値 | `2147483647` | 0始まり |
| [2_G](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_G) | 区間加算 | 区間和 | `0` | 1始まり |
| [2_H](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_H) | 区間加算 | 区間最小値 | `0` | 0始まり |
| [2_I](https://onlinejudge.u-aizu.ac.jp/problems/DSL_2_I) | 区間代入 | 区間和 | `0` | 0始まり |

AOJの閉区間 `[s,t]` は、0始まりなら `s..<(t+1)`、1始まりなら `(s-1)..<t` に変換。
1始まりの点 `i` は `i-1`。和は32bitを超えるため64bitの `int` で使う。

## 2次元領域検索

```nim
let tree = initKdTree(points) # seq[array[2, int]]
let ids = tree.rangeSearch([sx, sy], [tx, ty])
```

両端を含む閉長方形。結果は入力番号の昇順、重複座標も別の点として返す。
点の追加・削除は不可。各クエリの出力末尾に空行を入れる。

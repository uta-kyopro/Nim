# Wavelet Matrix

[自作実装](../src/lib/range_query/wavelet_matrix.nim)。**更新しない配列**の区間順位・個数・前後検索。
ACL・共通headerに依存せず、通常の `import` で使う。区間和・更新は非対応。

サンプル：[通常版](../src/examples/wavelet_matrix/basic.nim) / [座標圧縮版](../src/examples/wavelet_matrix/compressed.nim)

## 基本（座標圧縮あり）

負数・大きい整数を扱えるので、通常はこちら。ビット幅は自動決定。

```nim
import ../src/lib/range_query/wavelet_matrix # ファイル位置に合わせる

let a = @[5, -2, 5, 8, 1]
let wm = initCompressedStaticWaveletMatrix(a)
echo wm.kth_smallest(1..<5, 1)  # 1（小さい方から2番目）
echo wm.kth_largest(1..<5, 0)   # 8
echo wm.range_freq(0..<5, 5)    # 2（5未満）
echo wm.range_freq(0..<5, 1, 8) # 3（1以上8未満）
echo wm.rank(5, 5) - wm.rank(5, 1) # 1（[1,5)内の5の個数）
echo wm[0]                    # 5
```

位置・順位kは0始まり。区間は `l..<r`、値域は `[lo, hi)`。
重複も別々に数える。構築後に元配列を書き換えても反映されない。

## よく使う操作

| 呼び出し | 内容 |
| --- | --- |
| `wm.len` | 要素数 |
| `wm[i]` / `wm.access(i)` | 元配列のi番目 |
| `wm.kth_smallest(l..<r, k)` | 小さい方からk+1番目 |
| `wm.kth_largest(l..<r, k)` | 大きい方からk+1番目 |
| `wm.kth_smallest(l..<r, 0)` | 最小値 |
| `wm.kth_largest(l..<r, 0)` | 最大値 |
| `wm.kth_smallest(l..<r, (r-l-1) div 2)` | 中央値（偶数長は小さい側） |
| `wm.range_freq(l..<r, x)` | x未満の個数 |
| `wm.range_freq(l..<r, lo, hi)` | lo以上hi未満の個数 |
| `wm.rank(x, r) - wm.rank(x, l)` | xと等しい個数 |
| `wm.prev_value(l..<r, x)` | x未満の最大値（Option） |
| `wm.next_value(l..<r, x)` | x以上の最小値（Option） |

`rank(x, r)` 単体は先頭からr未満の個数。空区間の個数は0、前後検索は `none(T)`。
`kth_*` は非空区間で `0 <= k < r-l` が必要。

### 以下・より大きい・以上の個数

```nim
let less = wm.range_freq(l..<r, x)
let equal = wm.rank(x, r) - wm.rank(x, l)
let lessEqual = less + equal       # <= x
let greater = (r - l) - lessEqual  # > x
let greaterEqual = (r - l) - less  # >= x
```

`x+1` を使わないので最大整数でもオーバーフローしない。

### 前後の値

```nim
let previous = wm.prev_value(l..<r, x)
if previous.isSome:
    echo previous.get
```

該当なしは `none(T)`。実データの-1と区別できる。`options` はライブラリから再exportされる。

## 圧縮なし

```nim
let raw = initStaticWaveletMatrix(@[1, 5, 2, 4, 3])
echo raw.range_freq(0..<5, 100) # 5（表現範囲外の境界も処理）
let small = initStaticWaveletMatrix(@[0, 1, 2, 3], bitWidth = 2)
echo small.range_freq(0..<4, 4) # 4（2^bitWidthの境界も処理）
```

通常版は非負整数専用。`bitWidth = 0`（省略時）は自動、正の値なら明示指定。
圧縮版は幅指定不要。負数・整数の最小最大値・文字列など、比較と等値判定が整合する値を扱える（NaNは非対応）。

不正な位置・区間・順位は `IndexDefect`、負数での通常版構築・不足する幅・逆転した値域は `ValueError`。
これらの検証はreleaseでも行う。

## 計算量

N = 要素数、L = 内部ビット幅、D = 異なる値の個数。比較はO(1)とする。

| 操作 | 通常版 | 圧縮版 |
| --- | --- | --- |
| 構築 | O(NL) | O(N log(N+1) + NL) |
| `kth_*`・`access` | O(L) | O(L) |
| 個数・前後検索 | O(L) | O(L + log(D+1)) |
| `len` | O(1) | O(1) |

各レベルに64bit単位のビット列と累積個数を保持。構築時はO(N)要素の作業領域、圧縮版はさらにO(D)要素の対応表を使う。
ACL版で確認した累積配列の添字-1参照・accessの引数書き換えを避け、空配列・64bit境界・圧縮後の個数が2冪になる場合もテストしている。

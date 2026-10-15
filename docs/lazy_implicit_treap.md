# LazyImplicitTreap

`src/lib/collections/lazy_implicit_treap.nim` は、挿入・削除できる列に区間集約・遅延作用・反転を追加したライブラリです。既存の `implicit_treap.nim` / `ImplicitTreap` は従来の軽量実装のまま利用できます。

新しいライブラリは共通headerに依存せず、`import` / `include` のどちらでも使えます。両ライブラリを同時に利用できます。

## 演算の指定

```nim
var tree = initLazyImplicitTreap[S, F](op, e, mapping, composition)
```

- `S`: 1要素と区間集約の型。各要素も集約可能な値として渡します。
- `op(a, b)`: 左から右の順に結合する結合的な演算。
- `e`: `op` の単位元。空区間の結果です。
- `mapping(f, x, count)`: `count` 要素の集約値 `x` に作用 `f` を適用します。1要素には `count = 1` を渡します。
- `composition(f, g)`: `g` のあとに `f` を適用する作用。

作用は各要素に同じ方法で適用でき、区間結合と整合し、反転と可換である必要があります。加算・代入・アフィン変換などが対象です。区間内の位置に依存する作用や、失敗時に子へ降りるBeatsは対応しません。作用の有無をフラグで保持するため、`F` の単位元は不要です。

順方向・逆方向の集約を保持するので、文字列連結など非可換な演算でも反転できます。逆方向用の関数を利用者が指定する必要はありません。1要素の向きを変える作用は扱いません。

## API

添字は0始まり、区間は半開区間 `[first, last)`。`0 <= first <= last <= len` が前提です。境界チェックは `-d:debug` のときだけ実行します。利用前に必ず初期化関数を呼んでください。

| API | 動作 | 計算量（期待値） |
|---|---|---|
| `len` | 要素数 | O(1) |
| `insert(i, x)` / `add(x)` | 指定位置 / 末尾へ追加 | O(log n) |
| `delete(i)` | 1要素削除し、その値を返す | O(log n) |
| `tree[i]` / `tree[i] = x` | 点取得 / 点更新 | O(log n) |
| `prod(l, r)` | 区間集約。空区間は `e` | O(log n) |
| `allProd` | 全体の集約 | O(1) |
| `apply(l, r, f)` / `apply(i, f)` | 区間作用 / 点作用 | O(log n) |
| `reverse(l, r)` | 区間反転 | O(log n) |
| `rotate(l, r, k)` | 区間を左に `k` 個回転。負は右回転 | O(log n) |
| `items` / `toSeq` | 順に列挙 / 配列に変換 | O(n) |
| `clear()` | 空にする。演算の設定は保持 | O(n) |

計算量は演算・値のコピーがO(1)の場合です。文字列連結などではそのコストも加わります。初期化は空の木を作り、配列からは `add` を繰り返してO(n log n)で構築できます。メモリは最大同時要素数に比例し、削除したノードは再利用します。走査中は列を変更しないでください。

集約を維持するため、値を変更できる `var S` の参照は返しません。点更新には `tree[i] = x` を使います。木のコピーを永続データ構造として利用することは想定していません。

## 使用例と検証

[区間アフィン変換・区間和の例](../src/examples/lazy_implicit_treap/range_affine_sum.nim) は加算・乗算・代入を `(a, b)` による `x -> a*x+b` として扱います。代入は `a = 0`、加算は `a = 1` です。例は小さな整数を用いています。大きな値には適切な整数型やmod演算を指定してください。

```sh
nim cpp -r -d:debug --nimcache:build/nimcache_lazy --outdir:build/tests tests/test_lazy_implicit_treap.nim
nim cpp -r -d:release --nimcache:build/nimcache_lazy_release --outdir:build/tests tests/test_lazy_implicit_treap.nim
nim cpp -r --nimcache:build/nimcache_lazy_example --outdir:build/examples src/examples/lazy_implicit_treap/range_affine_sum.nim
```

テストでは配列とのランダム比較、作用の合成順、作用後の挿入・点更新、削除ノードの再利用、空区間、非可換な集約の反転、debug時の不正添字を確認します。

# FlatSeq2D

二次元配列を行優先の連続した `seq[T]` に保持します。添字は0始まりで、`len` は行数×列数です。

```nim
include ../src/lib/collections/flat_seq_2d

var a = initFlatSeq2D[int](2, 3, 100)
a[0, 1] += 7
discard chmin(a[1, 2], 5)

let b = @[@[1, 2, 3], @[4, 5, 6]].toFlatSeq2D()
assert b[1, 0] == 4
let c = [[1, 2], [3, 4]].toFlatSeq2D()
assert c[0, 1] == 2
```

`initFlatSeq2D[T](row, col)` は各要素を型のデフォルト値で初期化します。第3引数を渡すと、全要素をその値で初期化します。可変変数の `[]` は `var T` を返すため、複合代入や `var T` 引数への受け渡しができます。

`toFlatSeq2D` は二次元seqまたはarrayの各要素を新しい格納領域へコピーします。各行の長さは同じである必要があり、`-d:debug` では不揃いな行に対して `ValueError` を送出します。通常ビルドでは行長を検査しません。外側が空なら0行0列、空の行が複数ならその行数・0列になります。要素自体が参照型の場合、参照先の深いコピーは行いません。

`-d:debug` では、添字アクセス・代入・`getRow`・`getCol` の行／列境界を検査します。通常ビルドでは、呼び出し側が有効な添字を渡してください。

初期化・変換・`fill`・全走査は O(row × col)、添字アクセスは O(1)、行走査は O(col)、列走査は O(row) です。debug時の変換には別途 O(row) の行長検査があります。

専用テスト:

```sh
nim cpp -r -d:debug --outdir:build/tests tests/test_flat_seq_2d.nim
nim cpp -r -d:release --outdir:build/tests tests/test_flat_seq_2d.nim
```

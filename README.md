# Nim競技プログラミングライブラリ

競技プログラミングの提出コードへ、必要な部品をコピーまたは `include` して使うための個人用ライブラリです。

## 使い方

各ファイルは単体で利用できます。また、複数の部品を同じコードから `include` しても、共通の `header.nim` は一度だけ展開されます。

```nim
include src/lib/collections/interval_heap

var heap = initIntervalHeap[int]()
heap.push(3)
heap.push(1)
echo heap.pop_min()
```

`header.nim` は速度優先で、通常ビルドでは実行時チェックを無効にします。開発・テスト時は `-d:debug` を指定してください。

`simd_rand.nim` は AVX2 対応CPU、`miller_rabin.nim` は C++ バックエンドを前提とします。そのため全体テストも `nim cpp` でコンパイルします。

### Implicit Treap

`implicit_treap.nim` はGC参照を使わず、ノードを連続した `seq` に格納します。位置指定の挿入・削除・取得・更新と、半開区間の反転がそれぞれ期待 `O(log N)` です。

```nim
include src/lib/collections/implicit_treap

var treap = initImplicitTreap[int](capacity = 100_000)
treap.addLast(10)
treap.insert(0, 20)
treap.reverse(0, 2) # [0, 2)を反転
echo treap.delete(0)
```

範囲外アクセスは `-d:debug` ビルドで検出します。削除したノード領域は後続の挿入で再利用されます。

### Unrolled Linked List

`unrolled_linked_list.nim` は要素を複数の小さな連続ブロックに分割して保持します。位置アクセス・挿入・削除は概ね `O(√N)` です。半開区間の反転は対象要素数を `K` として `O(K + √N)` で処理し、分割で生じた小ブロックは反転後に再結合します。

```nim
include src/lib/collections/unrolled_linked_list

var list = initUnrolledLinkedList[int](blockSize = 256)
list.addLast(10)
list.insert(0, 20)
list.reverse(0, 2)
echo list.delete(0)
```

## テスト

Windowsではリポジトリ直下から次を実行します。

```bat
tests\run.cmd
```

テストは以下を含みます。

- 複数モジュールの同時 `include`
- itertoolsの通常ケースと空集合・ゼロ長などの境界条件
- Deque、BitSet、ビットパッキング、二次元配列
- Implicit Treapの挿入・削除・更新・区間反転とランダム差分テスト
- Unrolled Linked Listと`seq`のランダム差分テスト
- IntervalHeapとソート済み配列のランダム差分テスト
- 二次元累積和、Miller–Rabin、SIMD乱数
- `memoized` のキャッシュとリセット

動作確認環境は Nim 2.2.4、64-bit Windowsです。

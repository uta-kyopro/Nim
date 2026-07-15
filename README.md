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

### Object Pool

`object_pool.nim` は、[thun-c/thunder_libraryのObjectPool](https://github.com/thun-c/thunder_library/blob/main/thunder/lib/skip_beam.cpp)を参考にした整数index型プールです。削除したindexをLIFOで再利用し、要素を連続した `seq` に保持します。

### KD-tree

`tree/kd_tree.nim` は静的次元の点集合について、最近傍・k近傍・半径・直方体検索を提供します。検索結果は入力配列でのindexを保持します。

### Sorted containers

`sorted_containers.nim` は√分割による `SortedSet`、`SortedMultiSet`、`SortedDict` を提供します。ソート順の列挙、lower/upper bound、indexアクセスに対応します。

### Minimum-cost flow

`flow/`には共通APIの最小費用流を3方式収録しています。`V`を頂点数、`E`を辺数、`I`を増加路を流す回数とすると、Heap Primal-Dualは `O(I E log V)` で疎グラフ向け、Dense Primal-Dualは `O(I(V²+E))` で密グラフ向け、Bellman–Ford版は `O(I V E)` で負辺対応の参照実装向けです。Primal-Dualの初期残余グラフに負辺がある場合は、初期ポテンシャル計算として `O(VE)` が加わります。

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
- Object Poolのindex再利用とdebug検査
- SortedSet、SortedMultiSet、SortedDictのランダム差分テスト
- KD-treeと全点走査のランダム差分テスト
- 3方式の最小費用流について、既知ケース・境界条件・slope・辺状態・独立な全列挙とのランダム差分テスト
- IntervalHeapとソート済み配列のランダム差分テスト
- 二次元累積和、Miller–Rabin、SIMD乱数
- `memoized` のキャッシュとリセット

動作確認環境は Nim 2.2.4、64-bit Windowsです。

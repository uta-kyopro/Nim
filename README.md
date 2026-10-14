# Nim競技プログラミングライブラリ

競技プログラミング向けの個人用Nimライブラリです。生成物の `build/` と管理用ディレクトリは省略しています。

## 共通headerの利用

`src/lib/header.nim` を `include` して使います。標準ライブラリに加えて、ACLのNim実装の `atcoder/`（`extra/` を含む）がimportできる環境が必要です。共通headerには入出力・演算子・メモ化のほか、ACLのデータ構造、`mint`（mod 998244353）、ソート済み集合の補助操作、時間計測が含まれます。

通常の入力は、起動時に標準入力を固定バッファへ読み込みます。バッファ容量は64 MiBです。対話問題ではコンパイル時に `-d:interactive` を指定し、出力後に `flush()` を呼んでください。

各ライブラリの実行時の境界・引数・内部整合性チェックは `-d:debug` のときだけ行います。通常ビルドでは各APIの前提を満たす値を渡してください。コンパイル時の型・サイズ制約は常に検査します。

## ビームサーチ

編集用テンプレートは `src/lib/search/thunder_beam.nim`、探索エンジンは `src/lib/search/thunder_beam_core.nim` です。使い方と実問題の例は [Thunder Beam Search](docs/thunder_beam.md) を参照してください。

## フォルダ構成

二次元配列の初期化・直接更新・変換については [FlatSeq2D](docs/flat_seq_2d.md) を参照してください。
外部パッケージの使用例と不具合の検証記録は [外部ライブラリ](docs/external_libraries.md) を参照してください。
C++バックエンドの符号付き・符号なし128bit整数は [Int128 / UInt128](docs/int128.md) を参照してください。

```text
.
├── src/
│   ├── examples/                                 # ライブラリの使用例・実問題サンプル
│   └── lib/
│       ├── header.nim                              # 共通import、入出力、演算子、メモ化などの基本機能
│       ├── collections/
│       │   ├── array_deque.nim                    # 固定容量・2冪サイズの両端キュー
│       │   ├── bitpacking.nim                     # 整数内の固定幅ビットフィールドの取得・更新
│       │   ├── bitset.nim                         # uint64配列によるコンパイル時固定長StaticBitSet
│       │   ├── flat_seq_2d.nim                    # 二次元データを連続領域に保持する可変長配列
│       │   ├── implicit_treap.nim                 # 添字操作と区間反転に対応する暗黙Treap
│       │   ├── indexed_set.nim                    # O(1)の追加・削除・添字アクセスを持つ集合
│       │   ├── interval_heap.nim                  # 最小値と最大値を取得・削除できる両端優先度付きキュー
│       │   ├── object_pool.nim                    # 削除済みindexを再利用する整数index型オブジェクトプール
│       │   ├── persistent_stack.nim               # 過去バージョンを共有して保持する永続Stack
│       │   ├── sorted_containers.nim              # √分割によるSqrtSet・SqrtMultiSet・SqrtDict
│       │   ├── stack.nim                          # arrayを内部領域に使う固定容量Stack
│       │   ├── trie.nim                           # 文字列の完全一致・prefix検索に対応するTableTrie
│       │   └── unrolled_linked_list.nim           # 小さな連続ブロック列で保持する可変長リスト
│       ├── dp/
│       │   └── cumsum2d.nim                       # 長方形領域和を求める二次元累積和
│       ├── flow/
│       │   ├── min_cost_flow_common.nim           # 最小費用流3実装で共有する型と残余グラフ操作
│       │   ├── min_cost_flow_heap.nim             # Heap Primal-Dualによる疎グラフ向け最小費用流
│       │   ├── min_cost_flow_dense.nim            # 全頂点走査Primal-Dualによる密グラフ向け最小費用流
│       │   └── min_cost_flow_bellman_ford.nim     # 負辺に対応するBellman–Ford型最小費用流
│       ├── itertools/
│       │   ├── combinations.nim                   # 重複なし組合せの列挙
│       │   ├── combinations_with_replacement.nim  # 重複組合せの列挙
│       │   ├── permutations.nim                   # 順列・部分順列の列挙
│       │   └── product.nim                        # 直積の列挙
│       ├── math/
│       │   ├── int128.nim                         # C++の符号付き・符号なし128bit整数、入出力・型変換
│       │   ├── miller_rabin.nim                   # 64-bit整数向けMiller–Rabin素数判定
│       │   └── simd_rand.nim                      # AVX2で8個ずつ生成するSIMD乱数生成器
│       ├── range_query/
│       │   └── wavelet_matrix.nim                 # 静的な区間順位・個数・前後検索、座標圧縮対応
│       ├── tree/
│       │   └── kd_tree.nim                        # 最近傍・k近傍・半径・直方体検索を行うKD-tree
│       ├── search/
│       │   ├── thunder_beam.nim                   # 問題ごとの型・評価・遷移・展開を編集するテンプレート
│       │   └── thunder_beam_core.nim              # 差分更新・複数ターン遷移対応の探索エンジン
│       └── utils/
│           └── timer.nim                          # 単調時計による経過時間・期限判定Timer
└── tests/
    ├── test_all.nim                               # 各ライブラリの単体・境界・ランダム差分テスト
    ├── test_min_cost_flow.nim                     # 最小費用流の重点テスト
    ├── run.cmd                                    # Windows cmd向けテスト実行スクリプト
    └── run.ps1                                    # PowerShell向けテスト実行スクリプト
```
